#!/usr/bin/env python3
"""
Icinga2 config-master election: only the pod holding the Kubernetes Lease has the
/etc/icinga2/zones.d -> /opt/zones.d symlink (the shared config); the other master runs the config
synced from it.

- Election thread (kubernetes leaderelection lib): holding the lease -> desired role "leader";
  lib gave up renewing -> "follower" and the symlink is removed at once.
- Fence watchdog: a leader whose lease has not been confirmed for FENCE_AFTER seconds (< LEASE_DURATION,
  i.e. before the other pod may take the lease) removes the symlink, whatever the other threads do.
- Reconcile thread: applies the desired role. Promote = symlink + validate + reload, demote = remove
  symlink + reload; both reloads verified.
- Reload on request (leader only): the post-commit hook (Rundeck, rebalance) only writes
  RELOAD_REQUEST_FILE ("<epoch> <commit> <host>") into the shared /opt/zones.d. The leader reloads
  once that commit and its files reached this node (Syncthing), the content is stable and valid,
  and writes RELOAD_RESULT_FILE. The follower and the satellites are never restarted from outside
  for a config change: they get it through the Icinga2 config sync and restart themselves once the
  copy is complete (an external restart during that copy leaves api/zones half-copied).
- READY_FILE: the entrypoint starts icinga2 once it exists; it holds the role (leader / follower, or
  *-no-content while zones.d is blocked, read by redis-check.sh). HEARTBEAT_FILE: liveness.
"""
import datetime
import glob
import hashlib
import logging
import os
import re
import shutil
import subprocess
import threading
import time

import requests
import urllib3
from kubernetes import client, config
from kubernetes.client.rest import ApiException
from kubernetes.leaderelection import leaderelection, electionconfig
from kubernetes.leaderelection.leaderelectionrecord import LeaderElectionRecord

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s %(levelname)s [election] [%(threadName)s] %(message)s')
log = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lease lock
# ---------------------------------------------------------------------------
def _parse_time(value):
    """Parse the str(datetime) timestamps the leaderelection lib hands us
    back into an aware UTC datetime (API server rejects naive isoformat)."""
    if value is None or value == "None":
        return None
    try:
        dt = value if isinstance(value, datetime.datetime) else datetime.datetime.fromisoformat(value)
    except ValueError:
        return None
    if dt.tzinfo is None:
        dt = dt.astimezone()
    return dt.astimezone(datetime.timezone.utc)


class LeaseLock:
    """Resourcelock backed by a coordination.k8s.io/v1 Lease object."""

    def __init__(self, name, namespace, identity):
        self.api_instance = client.CoordinationV1Api()
        self.name = name
        self.namespace = namespace
        self.identity = str(identity)
        self.lease_reference = None

    def get(self, name, namespace):
        try:
            lease = self.api_instance.read_namespaced_lease(
                name, namespace, _request_timeout=LEASE_API_TIMEOUT)
            self.lease_reference = lease
            spec = lease.spec
            if spec is None or spec.holder_identity is None:
                return True, None
            record = LeaderElectionRecord(
                spec.holder_identity,
                str(spec.lease_duration_seconds),
                str(spec.acquire_time),
                str(spec.renew_time),
            )
            return True, record
        except ApiException as e:
            return False, e
        except Exception as e:
            # Timeout / connection error (urllib3): the leaderelection lib only handles an
            # ApiException with a JSON body here, anything else would crash its loop.
            return False, _lock_error(e)

    def create(self, name, namespace, election_record):
        started = time.monotonic()
        lease = client.V1Lease(
            metadata=client.V1ObjectMeta(name=name, namespace=namespace),
            spec=client.V1LeaseSpec(
                holder_identity=election_record.holder_identity,
                lease_duration_seconds=int(float(election_record.lease_duration)),
                acquire_time=_parse_time(election_record.acquire_time),
                renew_time=_parse_time(election_record.renew_time),
            ),
        )
        try:
            self.lease_reference = self.api_instance.create_namespaced_lease(
                namespace, lease, _request_timeout=LEASE_API_TIMEOUT)
            self._confirm(election_record, started)
            return True
        except Exception as e:
            log.info(f"Failed to create lock as {e}")
            return False

    def update(self, name, namespace, updated_record):
        started = time.monotonic()
        try:
            self.lease_reference.spec.holder_identity = updated_record.holder_identity
            self.lease_reference.spec.lease_duration_seconds = int(float(updated_record.lease_duration))
            self.lease_reference.spec.acquire_time = _parse_time(updated_record.acquire_time)
            self.lease_reference.spec.renew_time = _parse_time(updated_record.renew_time)
            self.lease_reference = self.api_instance.replace_namespaced_lease(
                name=name, namespace=namespace, body=self.lease_reference,
                _request_timeout=LEASE_API_TIMEOUT)
            self._confirm(updated_record, started)
            return True
        except Exception as e:
            log.info(f"Failed to update lock as {e}")
            return False

    def _confirm(self, record, started):
        """The API server stored our record: we hold the lease. `started` (taken before the call)
        is a safe lower bound of the renew time the other pod counts LEASE_DURATION from.

        Also takes the leader role back after fencing: when a renew hung past FENCE_AFTER and then
        succeeded, the lib keeps renewing without calling onstarted_leading again."""
        if record.holder_identity != self.identity:
            return
        STATE.lease_confirmed_at = started   # before set_desired: the watchdog must not fence again
        set_desired("leader")


def _lock_error(e):
    """ApiException shaped like an API server error (try_acquire_or_renew does json.loads(body))."""
    err = ApiException(status=0, reason=f"{type(e).__name__}: {e}")
    err.body = '{"code": 0}'
    return err


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
def _env_int(name, default):
    return int(os.environ.get(name, default))


POD_NAME   = os.environ["POD_NAME"]
NAMESPACE  = os.environ["NAMESPACE"]
LEASE_NAME = os.environ["LEASE_NAME"]
OPT_ZONES  = os.environ["OPT_ZONES_DIR"]
ETC_ZONES  = os.environ["ETC_ZONES_DIR"]
API_URL    = os.environ.get("ICINGA2_API_URL", "https://localhost:5665")
API_USER   = os.environ.get("ICINGA2_API_USER", "icingaAdmin")
API_PASS   = os.environ.get("ICINGA2_API_PASSWORD", "icingaAdmin")

API_ZONES_DIR  = os.environ.get("ICINGA2_API_ZONES_DIR", "/var/lib/icinga2/api/zones")
READY_FILE     = os.environ.get("ELECTION_READY_FILE", "/tmp/icinga2-election/ready")
HEARTBEAT_FILE = os.environ.get("ELECTION_HEARTBEAT_FILE", "/tmp/icinga2-election/heartbeat")
# Optional: file written by the config pipeline once a complete config set has been pushed.
CONTENT_READY_MARKER = os.environ.get("CONTENT_READY_MARKER", "")

LEASE_DURATION = _env_int("LEASE_DURATION", 30)
RENEW_DEADLINE = _env_int("RENEW_DEADLINE", 20)
RETRY_PERIOD   = _env_int("RETRY_PERIOD", 5)
# The other pod may take the lease LEASE_DURATION after our last renew: drop zones.d before that.
# A flaky API server then costs a demote + promote reload; that is the price of one config master.
FENCE_AFTER    = _env_int("FENCE_AFTER", LEASE_DURATION - RETRY_PERIOD)
# Client timeout of every Lease call made by the election lib. The lib checks RENEW_DEADLINE only
# between calls, so without it one hung call (etcd: a GET lease took up to 25 s) has no bound.
# main() disables the urllib3 retries, otherwise one call may take (1 + 3 retries) x timeout.
LEASE_API_TIMEOUT = _env_int("LEASE_API_TIMEOUT", 10)

RECONCILE_INTERVAL       = _env_int("RECONCILE_INTERVAL", 10)
CONTENT_STABLE_SECONDS   = _env_int("CONTENT_STABLE_SECONDS", 15)
INITIAL_DECISION_TIMEOUT = _env_int("INITIAL_DECISION_TIMEOUT", LEASE_DURATION + 3 * RETRY_PERIOD)
STARTUP_MAX_WAIT         = _env_int("STARTUP_MAX_WAIT", 300)
RELOAD_VERIFY_TIMEOUT    = _env_int("RELOAD_VERIFY_TIMEOUT", 180)
VALIDATE_TIMEOUT         = _env_int("VALIDATE_TIMEOUT", 300)

# Reload on request (written by the post-commit hook, see the module docstring)
RELOAD_REQUEST_FILE = os.environ.get("RELOAD_REQUEST_FILE", os.path.join(OPT_ZONES, ".reload-request"))
RELOAD_RESULT_FILE  = os.environ.get("RELOAD_RESULT_FILE", os.path.join(OPT_ZONES, ".reload-result"))
# How long to wait for the requested commit and its files to reach this node before reloading
# whatever is on disk (logged as ERROR).
RELOAD_SYNC_TIMEOUT = _env_int("RELOAD_SYNC_TIMEOUT", 300)
# Unverified reloads of one request before giving up on it (result "reload-failed").
RELOAD_MAX_FAILURES = _env_int("RELOAD_MAX_FAILURES", 3)
GIT_TIMEOUT         = _env_int("GIT_TIMEOUT", 60)


# ---------------------------------------------------------------------------
# Shared state
# ---------------------------------------------------------------------------
class State:
    def __init__(self):
        self.lock = threading.Lock()
        self.started_at = time.monotonic()
        self.desired_role = None        # None | "leader" | "follower"
        self.desired_since = time.monotonic()
        self.applied_role = None        # role loaded by the running icinga2 process
        self.ready_written = False
        self.ready_role = None          # role last written to READY_FILE
        self.content_hash = None
        self.content_hash_since = 0.0
        self.failures = 0
        self.next_attempt = 0.0
        self.lease_confirmed_at = 0.0   # start of the last call that confirmed our lease (monotonic)
        self.handled_request = None     # content of RELOAD_REQUEST_FILE already loaded by icinga2
        self.pending_request = None     # request being processed
        self.pending_since = 0.0
        self.request_failures = 0


STATE = State()
FS_LOCK = threading.Lock()   # every operation on the symlink / api/zones
WAKE = threading.Event()     # wakes the reconcile loop when the role changes
_last_log = {}


def log_throttled(key, level, msg, every=60):
    now = time.monotonic()
    if now - _last_log.get(key, -1e9) >= every:
        _last_log[key] = now
        log.log(level, msg)


def set_desired(role):
    with STATE.lock:
        if STATE.desired_role != role:
            log.info(f"Desired role: {STATE.desired_role} -> {role}")
            STATE.desired_role = role
            STATE.desired_since = time.monotonic()
            STATE.failures = 0
            STATE.next_attempt = 0.0
    WAKE.set()


def note_failure(msg):
    with STATE.lock:
        STATE.failures += 1
        delay = min(300, RECONCILE_INTERVAL * (2 ** min(STATE.failures, 5)))
        STATE.next_attempt = time.monotonic() + delay
        n = STATE.failures
    log.error(f"{msg} (failure #{n}, retry in {delay}s)")


def note_success():
    with STATE.lock:
        STATE.failures = 0
        STATE.next_attempt = 0.0


def write_small_file(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.replace(tmp, path)


def write_ready(role):
    """First call: the entrypoint may start icinga2. Later calls (verified role change, follower
    seeing zones.d blocked / unblocked) keep the role current for redis-check.sh, which accepts
    0 Hosts only while it says leader-no-content or follower-no-content."""
    first = not STATE.ready_written
    write_small_file(READY_FILE, f"{role} {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n")
    STATE.ready_written = True
    STATE.ready_role = role
    log.info(f"READY_FILE written (role={role})"
             + (" -> entrypoint may start icinga2" if first else ""))


# ---------------------------------------------------------------------------
# /opt/zones.d content
# ---------------------------------------------------------------------------
SYNCTHING_TMP = re.compile(r"^(\.syncthing\..*\.tmp|~syncthing~.*\.tmp)$")
SYNC_CONFLICT = re.compile(r"\.sync-conflict-")


def scan_content():
    """Return (list of .conf files, list of problems)."""
    files, problems = [], []
    if not os.path.isdir(OPT_ZONES):
        return files, [f"{OPT_ZONES} does not exist"]
    for root, dirs, names in os.walk(OPT_ZONES):
        # Skip hidden directories: .stfolder, .stversions, ...
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for n in sorted(names):
            p = os.path.join(root, n)
            if SYNCTHING_TMP.match(n):
                problems.append(f"Syncthing temp file present: {p}")
            elif SYNC_CONFLICT.search(n):
                problems.append(f"Syncthing conflict file present: {p}")
            elif n.endswith(".conf") and not n.startswith("."):
                files.append(p)
    return files, problems


def resolve_link(p):
    """Real target of a symlink inside OPT_ZONES.

    icinga2-rebalance creates links like zone-satellite-N/x.conf -> /etc/icinga2/zones.d/all_config/x.conf,
    i.e. THROUGH the zones.d symlink managed by the election. Before that symlink exists (at startup,
    or on a follower) these links dangle, so map the ETC_ZONES prefix to OPT_ZONES."""
    target = os.readlink(p)
    if not os.path.isabs(target):
        target = os.path.join(os.path.dirname(p), target)
    etc = ETC_ZONES.rstrip("/")
    if target == etc or target.startswith(etc + "/"):
        target = OPT_ZONES.rstrip("/") + target[len(etc):]
    return target


def hash_files(files):
    h = hashlib.sha256()
    for p in files:
        h.update(os.path.relpath(p, OPT_ZONES).encode())
        h.update(b"\0")
        path = p
        if os.path.islink(p):
            path = resolve_link(p)
            h.update(b"-> " + os.readlink(p).encode() + b"\0")
            if not os.path.exists(path):
                # Really dangling link: hash only the target name; daemon --validate fails if Icinga needs the file.
                h.update(b"<dangling>\0")
                continue
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        h.update(b"\0")
    return h.hexdigest()


def check_content():
    """Return (ready, hash, reason). Called from the reconcile thread only."""
    if CONTENT_READY_MARKER and not os.path.exists(CONTENT_READY_MARKER):
        return False, None, f"marker {CONTENT_READY_MARKER} not present"
    files, problems = scan_content()
    if problems:
        # Conflict files first: they never go away by themselves (the caller logs them as ERROR),
        # temp files do.
        problems.sort(key=lambda p: "conflict" not in p)
        more = f" (+{len(problems) - 3} more)" if len(problems) > 3 else ""
        return False, None, "; ".join(problems[:3]) + more
    if not files:
        return False, None, f"no *.conf files in {OPT_ZONES} (only Syncthing metadata / README?)"
    try:
        h = hash_files(files)
    except OSError as e:  # file renamed/removed while Syncthing is writing
        return False, None, f"read error while hashing: {e}"
    now = time.monotonic()
    if h != STATE.content_hash:
        STATE.content_hash, STATE.content_hash_since = h, now
        return False, h, "content changed, waiting for it to settle"
    if now - STATE.content_hash_since < CONTENT_STABLE_SECONDS:
        return False, h, "waiting for content to settle"
    return True, h, f"{len(files)} .conf files"


def content_blocked():
    """True when the shared /opt/zones.d cannot be promoted for a long time: Syncthing conflict
    files, no .conf file, or the CONTENT_READY_MARKER missing (temp files are transient and not
    counted). The leader then ends up as leader-no-content and syncs no config, so a follower
    that has none (new pod) stays at 0 Hosts as well: restarting it would not help."""
    if CONTENT_READY_MARKER and not os.path.exists(CONTENT_READY_MARKER):
        return True
    files, problems = scan_content()
    return not files or any(SYNC_CONFLICT.search(p) for p in problems)


def follower_ready_role():
    """follower-no-content while zones.d is blocked: the leader may then run without it and sync
    nothing, so 0 Hosts on this follower is expected and restarting icinga2 would not help."""
    return "follower-no-content" if content_blocked() else "follower"


# ---------------------------------------------------------------------------
# Icinga2: validate / API / reload
# ---------------------------------------------------------------------------
HOSTS_RE = re.compile(r"Instantiated (\d+) Hosts?\.")


def validate_config():
    """Return (ok, expected_hosts, output_tail)."""
    try:
        r = subprocess.run(["icinga2", "daemon", "--validate"],
                           capture_output=True, text=True, timeout=VALIDATE_TIMEOUT)
    except subprocess.TimeoutExpired:
        return False, None, f"validate timed out after {VALIDATE_TIMEOUT}s"
    except OSError as e:
        return False, None, f"cannot run icinga2 daemon --validate: {e}"
    out = (r.stdout or "") + (r.stderr or "")
    if r.returncode != 0:
        return False, None, out[-4000:]
    m = HOSTS_RE.findall(out)
    return True, (int(m[-1]) if m else 0), ""


def _api(method, path, timeout=10):
    r = requests.request(method, f"{API_URL}{path}", auth=(API_USER, API_PASS), verify=False,
                         headers={"Accept": "application/json"}, timeout=timeout)
    r.raise_for_status()
    return r.json()


def program_start():
    """program_start of the running process, or None if the API is not ready."""
    try:
        d = _api("GET", "/v1/status/IcingaApplication")
        return d["results"][0]["status"]["icingaapplication"]["app"]["program_start"]
    except Exception:
        return None


def running_host_count():
    d = _api("GET", "/v1/objects/hosts?attrs=name", timeout=60)
    return len(d.get("results", []))


def reload_and_verify(expected_hosts):
    before = program_start()
    if before is None:
        return False, "Icinga2 API not reachable"
    try:
        _api("POST", "/v1/actions/restart-process", timeout=60)
        log.info("restart-process accepted, waiting for the new process...")
    except Exception as e:
        # The connection may be cut by the process restart; program_start is still checked below.
        log.warning(f"restart-process call returned error ({e}); verifying anyway")

    deadline = time.monotonic() + RELOAD_VERIFY_TIMEOUT
    while time.monotonic() < deadline:
        time.sleep(3)
        now_start = program_start()
        if now_start is not None and now_start != before:
            break
    else:
        return False, "process did not restart in time (new config rejected? check icinga2 log)"

    try:
        count = running_host_count()
    except Exception as e:
        return False, f"cannot count hosts after reload: {e}"
    if expected_hosts and count < expected_hosts:
        return False, f"running hosts {count} < expected {expected_hosts}"
    return True, f"running hosts={count}"


# ---------------------------------------------------------------------------
# Filesystem
# ---------------------------------------------------------------------------
def symlink_ok():
    return os.path.islink(ETC_ZONES) and os.readlink(ETC_ZONES) == OPT_ZONES


def ensure_symlink():
    """Return True if the symlink was just created or fixed."""
    if os.path.islink(ETC_ZONES):
        current = os.readlink(ETC_ZONES)
        if current == OPT_ZONES:
            return False
        log.warning(f"Wrong symlink target {current}, fixing")
        os.remove(ETC_ZONES)
    elif os.path.isdir(ETC_ZONES):
        stray = [e for e in os.listdir(ETC_ZONES) if e != "README"]
        if stray:
            raise RuntimeError(f"{ETC_ZONES} is a non-empty directory: {stray[:5]}")
        shutil.rmtree(ETC_ZONES)
    elif os.path.exists(ETC_ZONES):
        raise RuntimeError(f"{ETC_ZONES} in unexpected state")
    os.symlink(OPT_ZONES, ETC_ZONES)
    log.info(f"Created symlink {ETC_ZONES} -> {OPT_ZONES}")
    return True


def remove_symlink():
    changed = False
    if os.path.islink(ETC_ZONES):
        os.remove(ETC_ZONES)
        changed = True
        log.info(f"Removed symlink {ETC_ZONES}")
    os.makedirs(ETC_ZONES, exist_ok=True)
    return changed


def clear_authority_markers(include_timestamp):
    """Remove the markers so that Icinga2 loads api/zones/* and accepts the config sync from the leader."""
    names = [".authoritative"] + ([".timestamp"] if include_timestamp else [])
    removed = []
    for name in names:
        for p in glob.glob(os.path.join(API_ZONES_DIR, "*", name)):
            try:
                os.remove(p)
                removed.append(p)
            except FileNotFoundError:
                pass
    if removed:
        log.info(f"Removed authority markers: {removed}")
    return removed


# ---------------------------------------------------------------------------
# Reconcile
# ---------------------------------------------------------------------------
def reconcile_leader(now):
    if STATE.applied_role == "leader" and symlink_ok():
        handle_reload_request(now)   # promote done: reload only when the post-commit hook asks
        return

    # Promote: start as leader, follower -> leader, completing leader-no-content, or a leader whose
    # symlink went missing (fenced then re-confirmed: icinga2 may have restarted without zones.d).
    ready, _, reason = check_content()
    if not ready:
        if "Syncthing conflict file" in reason:
            # Never goes away by itself (unlike Syncthing temp files) and blocks every promote.
            # /opt/zones.d is shared: the other master sees the same files.
            log_throttled("conflict", logging.ERROR,
                          f"Leader, but promote BLOCKED by Syncthing conflict files: {reason}. "
                          f"Compare each *.sync-conflict-* file with its original, merge if needed, "
                          f"then delete it by hand from {OPT_ZONES}", every=300)
        else:
            log_throttled("content", logging.WARNING, f"Leader, but content not ready: {reason}")
        if not STATE.ready_written and now - STATE.desired_since > STARTUP_MAX_WAIT:
            log.error("Content still not ready after STARTUP_MAX_WAIT; starting icinga2 "
                      "without zones.d, will reload once content is ready")
            write_ready("leader-no-content")
        return
    if now < STATE.next_attempt:
        return

    log.info("Leader reconcile needed: role change -> leader")
    try:
        with FS_LOCK:
            if STATE.desired_role != "leader":
                return
            created = ensure_symlink()
    except Exception as e:
        note_failure(f"Cannot prepare symlink: {e}")
        return

    ok, expected, out = validate_config()
    if not ok:
        # Drop the symlink only if no icinga2 process can have loaded it: icinga2 not started yet
        # (entrypoint waits for READY_FILE), or created in this pass on a non-leader. After a reload
        # that ran but was not verified, or on a leader that had zones.d, the running process may use
        # zones.d: removing the link would make the next external restart load an empty zones.d.
        if not STATE.ready_written or (created and STATE.applied_role != "leader"):
            with FS_LOCK:
                remove_symlink()
        note_failure(f"Config validation FAILED (running process keeps old config):\n{out}")
        return
    log.info(f"Config validation OK (expected hosts={expected})")

    with FS_LOCK:
        if STATE.desired_role != "leader" or not symlink_ok():
            # Fenced during validate (symlink removed), maybe re-confirmed since: never reload or
            # start icinga2 without zones.d as leader. The next pass demotes or promotes again.
            log.warning("Lease lost during validate: promote dropped")
            return
        if not STATE.ready_written:
            # icinga2 not started yet (entrypoint waits for READY_FILE): it loads exactly this
            # config. Under FS_LOCK so that a fence cannot remove the symlink before READY.
            STATE.applied_role = "leader"
            note_success()
            write_ready("leader")
            mark_requests_loaded()
            return

    ok, msg = reload_and_verify(expected)
    if ok:
        STATE.applied_role = "leader"
        note_success()
        write_ready("leader")   # replaces leader-no-content / follower
        mark_requests_loaded()
        log.info(f"Leader reload verified: {msg}")
    else:
        note_failure(f"Leader reload NOT verified: {msg}")


# ---------------------------------------------------------------------------
# Reload on request (leader only)
# ---------------------------------------------------------------------------
def read_request():
    """Content of RELOAD_REQUEST_FILE ("<epoch> <commit> <host>"), or None."""
    try:
        with open(RELOAD_REQUEST_FILE) as f:
            return f.read().strip() or None
    except OSError:
        return None


def mark_requests_loaded():
    """A promote loads the whole zones.d: every request written so far is done."""
    STATE.handled_request = read_request()
    STATE.pending_request = None
    STATE.request_failures = 0


def write_result(req, status, detail):
    commit = (req.split() + ["", ""])[1]
    line = (f"{commit} {status} {datetime.datetime.now(datetime.timezone.utc).isoformat()} "
            f"{POD_NAME} {' '.join(str(detail).split())[:500]}\n")
    try:
        write_small_file(RELOAD_RESULT_FILE, line)
    except OSError as e:
        log.warning(f"Cannot write {RELOAD_RESULT_FILE}: {e}")


def _git(*args):
    """Read-only git in OPT_ZONES. GIT_OPTIONAL_LOCKS=0: never rewrite .git/index, which Syncthing
    shares between the nodes (a write would race with the other nodes: sync-conflict files).
    safe.directory: the repo belongs to another uid and ~/.gitconfig does not survive a restart."""
    try:
        r = subprocess.run(["git", "-c", "safe.directory=*", "-C", OPT_ZONES, *args],
                           capture_output=True, text=True, timeout=GIT_TIMEOUT,
                           env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"})
    except (OSError, subprocess.TimeoutExpired) as e:
        return 1, str(e)
    return r.returncode, (r.stdout if r.returncode == 0 else r.stderr).strip()


def zones_synced(commit):
    """(True, why) once the requested commit and the .conf files it changed are on this node:
    Syncthing may deliver the request file, .git and the config files in any order.

    Only the files of that commit are compared, not the whole tree: master_zones.conf is rewritten
    by the master pods themselves (start / preStop, the lines come back in another order) and
    config-ui commits single paths, so other tracked files may differ from HEAD for a long time
    and must not hold the reload for RELOAD_SYNC_TIMEOUT."""
    if not commit or commit == "unknown":
        return True, "no commit in the request"
    rc, head = _git("rev-parse", "HEAD")
    if rc != 0:
        return False, f"git rev-parse failed: {head}"
    if head != commit:
        return False, f"HEAD {head[:12]} is not the requested commit {commit[:12]} yet"
    rc, files = _git("diff-tree", "--no-commit-id", "--name-only", "-r", "--root", commit)
    if rc != 0:
        return False, f"git diff-tree failed: {files}"
    paths = [p for p in files.splitlines() if p.endswith(".conf")]
    if not paths:
        return True, "commit changes no .conf file"
    rc, out = _git("status", "--porcelain", "--untracked-files=no", "--", *paths)
    if rc != 0:
        return False, f"git status failed: {out}"
    if out:
        return False, f"files of the commit not on this node yet: {out.splitlines()[:3]}"
    return True, f"commit and its {len(paths)} .conf file(s) present"


def handle_reload_request(now):
    req = read_request()
    if req is None or req == STATE.handled_request:
        return
    if req != STATE.pending_request:
        log.info(f"Reload requested: {req}")
        STATE.pending_request, STATE.pending_since, STATE.request_failures = req, now, 0
    if now < STATE.next_attempt:
        return

    commit = (req.split() + ["", ""])[1]
    synced, why = zones_synced(commit)
    if not synced:
        if now - STATE.pending_since < RELOAD_SYNC_TIMEOUT:
            log_throttled("request-sync", logging.INFO, f"Reload request waits for Syncthing: {why}", every=30)
            return
        log_throttled("request-sync-timeout", logging.ERROR,
                      f"Requested config not on this node after {RELOAD_SYNC_TIMEOUT}s ({why}); "
                      "reloading what is on disk", every=300)

    ready, _, reason = check_content()
    if not ready:
        level = logging.ERROR if "Syncthing conflict file" in reason else logging.INFO
        log_throttled("request-content", level, f"Reload request waits for zones.d content: {reason}", every=60)
        return

    ok, expected, out = validate_config()
    if not ok:
        # The running process keeps the last valid config; a new commit (new request) retries.
        log.error(f"Requested reload: config validation FAILED, icinga2 NOT reloaded:\n{out}")
        STATE.handled_request, STATE.pending_request = req, None
        write_result(req, "validate-failed", out.strip().splitlines()[-1] if out.strip() else "")
        return

    with FS_LOCK:
        if STATE.desired_role != "leader" or not symlink_ok():
            log.warning("Lease lost during validate: requested reload dropped")
            return
    ok, msg = reload_and_verify(expected)
    if ok:
        note_success()
        STATE.handled_request, STATE.pending_request = req, None
        write_result(req, "ok", msg)
        log.info(f"Requested reload verified: {msg}")
        return
    STATE.request_failures += 1
    note_failure(f"Requested reload NOT verified: {msg}")
    if STATE.request_failures >= RELOAD_MAX_FAILURES:
        log.error(f"Giving up on reload request {req} after {STATE.request_failures} attempts")
        STATE.handled_request, STATE.pending_request = req, None
        write_result(req, "reload-failed", msg)


def reconcile_follower(now):
    transitioning = STATE.applied_role != "follower"
    with FS_LOCK:
        if STATE.desired_role != "follower":
            return
        link_removed = remove_symlink()
        markers = clear_authority_markers(include_timestamp=transitioning)

    if not STATE.ready_written:
        STATE.applied_role = "follower"
        write_ready(follower_ready_role())
        return

    if transitioning or link_removed:
        if now < STATE.next_attempt or program_start() is None:
            return
        ok, msg = reload_and_verify(None)
        if ok:
            STATE.applied_role = "follower"
            note_success()
            write_ready(follower_ready_role())
            log.info(f"Follower reload verified ({msg}); waiting for config sync from leader")
        else:
            note_failure(f"Follower reload NOT verified: {msg}")
        return

    role = follower_ready_role()
    if role != STATE.ready_role:
        if role == "follower-no-content":
            log.warning(f"{OPT_ZONES} is blocked for every master (Syncthing conflict files / no "
                        "content): the leader may be unable to load zones.d, 0 hosts are accepted "
                        "by the redis probe until it is fixed")
        write_ready(role)

    if markers:
        # No reload here to avoid a loop; usually Director / a config package deployed to the follower.
        log_throttled("markers", logging.ERROR,
                      "Follower got .authoritative markers again - is something deploying "
                      "config packages (e.g. Director) to this node?")


def reconcile_once():
    now = time.monotonic()
    with STATE.lock:
        role = STATE.desired_role
    if role is None:
        if now - STATE.started_at < INITIAL_DECISION_TIMEOUT:
            log_throttled("deciding", logging.INFO, "Waiting for initial election result...", every=10)
            return
        log.info(f"Not leader after {INITIAL_DECISION_TIMEOUT}s -> follower")
        set_desired("follower")
        role = "follower"
    if role == "leader":
        reconcile_leader(now)
    else:
        reconcile_follower(now)


def reconcile_loop():
    while True:
        try:
            write_small_file(HEARTBEAT_FILE, f"{time.time():.0f}\n")
            reconcile_once()
        except Exception:
            log.exception("Reconcile iteration failed")
        WAKE.wait(RECONCILE_INTERVAL)
        WAKE.clear()


# ---------------------------------------------------------------------------
# Election callbacks
# ---------------------------------------------------------------------------
def on_started_leading():
    # Log only: _confirm already set the role, and the lib runs this on a thread that could start
    # after a quick on_stopped_leading (it must not make us leader without the lease).
    log.info(f"=== Acquired lease: {POD_NAME} is leader ===")


def demote_and_fence(reason):
    log.warning(f"=== {POD_NAME} stepping down: {reason} ===")
    set_desired("follower")
    # Fence at once, do not wait for the reconcile loop: never two nodes with zones.d.
    try:
        with FS_LOCK:
            remove_symlink()
    except Exception:
        log.exception("Failed to remove symlink during fencing")


def on_stopped_leading():
    demote_and_fence("lease renew failed (another pod may take it)")


def fence_due():
    """Leader whose lease has not been confirmed for FENCE_AFTER seconds -> fence. True if fenced."""
    if STATE.desired_role != "leader" or STATE.lease_confirmed_at <= 0:
        return False
    age = time.monotonic() - STATE.lease_confirmed_at
    if age <= FENCE_AFTER:
        return False
    demote_and_fence(f"lease not confirmed for {age:.0f}s (> FENCE_AFTER {FENCE_AFTER}s)")
    return True


def fence_watchdog():
    """Own thread: the election lib may block for RENEW_DEADLINE + 2 x LEASE_API_TIMEOUT before it
    gives up, the reconcile thread for minutes (validate / reload)."""
    while True:
        try:
            fence_due()
        except Exception:
            log.exception("Fence check failed")
        time.sleep(1)


def main():
    config.load_incluster_config()
    # No urllib3 retries (default 3): one Lease call must be bounded by its timeout
    # (lab: 4 x 10 s read timeouts on one renew). The election loops retry every RETRY_PERIOD.
    cfg = client.Configuration.get_default_copy()
    cfg.retries = 0
    client.Configuration.set_default(cfg)
    log.info(f"Election client starting on {POD_NAME}")
    if FENCE_AFTER >= LEASE_DURATION:
        log.warning(f"FENCE_AFTER {FENCE_AFTER}s >= LEASE_DURATION {LEASE_DURATION}s: both masters "
                    "may have zones.d while the leader cannot reach the API server")
    threading.Thread(target=fence_watchdog, name="fence", daemon=True).start()
    threading.Thread(target=reconcile_loop, name="reconcile", daemon=True).start()

    lock = LeaseLock(LEASE_NAME, NAMESPACE, POD_NAME)
    election_config = electionconfig.Config(
        lock=lock,
        lease_duration=LEASE_DURATION,
        renew_deadline=RENEW_DEADLINE,
        retry_period=RETRY_PERIOD,
        onstarted_leading=on_started_leading,
        onstopped_leading=on_stopped_leading,
    )
    while True:
        try:
            leaderelection.LeaderElection(election_config).run()
        except Exception:
            log.exception("Leader election loop crashed")
            if STATE.desired_role == "leader":
                demote_and_fence("election loop crashed")
            time.sleep(RETRY_PERIOD)


if __name__ == "__main__":
    main()
