#!/usr/bin/env python3
"""
Icinga2 config-master leader election + reconcile loop.

Changes compared with the previous version:
  1. The leader election callbacks only record the "desired role". When renewing the lease
     fails, demote ONLY if another pod is seen holding the lease (a short API server error
     no longer causes an empty reload); on demote the symlink is removed at once (fencing).
     Symlink / validate / reload are done by one reconcile thread, with retry + backoff,
     so transient errors are no longer swallowed.
  2. Stricter check of /opt/zones.d content: there must be real .conf files (Syncthing's
     .stfolder/.stignore/.stversions do not count), no Syncthing temp / conflict files,
     and the content hash must stay stable for CONTENT_STABLE_SECONDS.
  3. The election reloads ONLY on a role change: promote (to leader: create the symlink,
     validate, reload) and demote (to follower: remove the symlink, reload). Once leader,
     zones.d content changes are NOT loaded by the election: the post-commit hook (Rundeck,
     rebalance) and reload-master still restart icinga2 as before. A missing symlink is only
     recreated, without a reload.
  4. Every election reload is verified: program_start must change and the running process
     must have >= the number of Hosts reported by `icinga2 daemon --validate`.
  5. Leader running with 0 Hosts (the symptom of the 11/11 incident) -> periodic ERROR log,
     no reload.
  6. On becoming follower: remove the .authoritative markers (and .timestamp on a role
     change) in /var/lib/icinga2/api/zones so that the node loads them and accepts the
     config sync from the leader.
  7. Write READY_FILE once the role is decided and the filesystem is prepared; the
     entrypoint waits for this file before starting icinga2.
  8. Write HEARTBEAT_FILE on every reconcile pass, for the livenessProbe.
  9. Split-brain bound: when renewing fails, keep the role only for
     LEASE_DURATION + FENCE_GRACE seconds after the last confirmation of holding the lease.
     Past that point without confirmation (API server gone) -> fencing, because another pod
     may have legitimately taken the lease since second LEASE_DURATION.
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
# Lease lock (unchanged from the previous version)
# ---------------------------------------------------------------------------
def _parse_time(value):
    """Parse the str(datetime) timestamps the leaderelection lib hands us
    back into an aware UTC datetime (API server rejects naive isoformat)."""
    if value is None or value == "None":
        return None
    if isinstance(value, datetime.datetime):
        dt = value
    else:
        dt = None
        for fmt in ("%Y-%m-%d %H:%M:%S.%f%z", "%Y-%m-%d %H:%M:%S%z",
                    "%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S"):
            try:
                dt = datetime.datetime.strptime(value, fmt)
                break
            except ValueError:
                continue
        if dt is None:
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
            lease = self.api_instance.read_namespaced_lease(name, namespace)
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

    def create(self, name, namespace, election_record):
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
            self.lease_reference = self.api_instance.create_namespaced_lease(namespace, lease)
            self._confirm(election_record)
            return True
        except ApiException as e:
            log.info(f"Failed to create lock as {e}")
            return False

    def update(self, name, namespace, updated_record):
        try:
            self.lease_reference.spec.holder_identity = updated_record.holder_identity
            self.lease_reference.spec.lease_duration_seconds = int(float(updated_record.lease_duration))
            self.lease_reference.spec.acquire_time = _parse_time(updated_record.acquire_time)
            self.lease_reference.spec.renew_time = _parse_time(updated_record.renew_time)
            self.lease_reference = self.api_instance.replace_namespaced_lease(
                name=name, namespace=namespace, body=self.lease_reference)
            self._confirm(updated_record)
            return True
        except ApiException as e:
            log.info(f"Failed to update lock as {e}")
            return False

    def _confirm(self, record):
        """Record when the API server confirmed that this pod holds the lease."""
        if record.holder_identity == self.identity:
            STATE.lease_confirmed_at = time.monotonic()


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
# After LEASE_DURATION another pod may take the lease; FENCE_GRACE tolerates a flaky API server
# (11/11 incident: lease re-acquired after 30.8 s) before fencing ourselves.
FENCE_GRACE    = _env_int("FENCE_GRACE", 30)

RECONCILE_INTERVAL       = _env_int("RECONCILE_INTERVAL", 10)
CONTENT_STABLE_SECONDS   = _env_int("CONTENT_STABLE_SECONDS", 15)
INITIAL_DECISION_TIMEOUT = _env_int("INITIAL_DECISION_TIMEOUT", LEASE_DURATION + 3 * RETRY_PERIOD)
STARTUP_MAX_WAIT         = _env_int("STARTUP_MAX_WAIT", 300)
DRIFT_CHECK_INTERVAL     = _env_int("DRIFT_CHECK_INTERVAL", 60)
RELOAD_VERIFY_TIMEOUT    = _env_int("RELOAD_VERIFY_TIMEOUT", 180)
FOLLOWER_SYNC_TIMEOUT    = _env_int("FOLLOWER_SYNC_TIMEOUT", 180)
VALIDATE_TIMEOUT         = _env_int("VALIDATE_TIMEOUT", 300)


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
        self.applied_hash = None        # zones.d content hash loaded by the process (leader)
        self.expected_hosts = None      # number of Hosts from the last validate
        self.ready_written = False
        self.follower_since = 0.0
        self.last_drift_check = 0.0
        self.content_hash = None
        self.content_hash_since = 0.0
        self.failures = 0
        self.next_attempt = 0.0
        self.lease_confirmed_at = 0.0   # last time the API server confirmed we hold the lease (monotonic)


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
    write_small_file(READY_FILE, f"{role} {datetime.datetime.now(datetime.timezone.utc).isoformat()}\n")
    STATE.ready_written = True
    log.info(f"READY_FILE written (role={role}) -> entrypoint may start icinga2")


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
        return False, None, "; ".join(problems[:3])
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


# ---------------------------------------------------------------------------
# Icinga2: validate / API / reload
# ---------------------------------------------------------------------------
HOSTS_RE = re.compile(r"Instantiated (\d+) Hosts?\.")


def validate_config():
    """Return (ok, expected_hosts, output_tail)."""
    r = subprocess.run(["icinga2", "daemon", "--validate"],
                       capture_output=True, text=True, timeout=VALIDATE_TIMEOUT)
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
    # "Keeping the role" after a failed renew: if another pod has taken the lease, step down.
    if lease_held_by_other():
        demote_and_fence("another pod holds the lease (detected by reconcile)")
        return
    if lease_unconfirmed_too_long():
        return

    if STATE.applied_role == "leader":
        maintain_leader(now)   # promote done: no reload
        return

    # Promote: start as leader, follower -> leader, or completing leader-no-content.
    ready, h, reason = check_content()
    if not ready:
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
        if created:
            with FS_LOCK:
                remove_symlink()
        note_failure(f"Config validation FAILED (running process keeps old config):\n{out}")
        return
    log.info(f"Config validation OK (expected hosts={expected})")

    if STATE.desired_role != "leader":
        return  # lease lost during validate; on_stopped_leading already fenced

    if not STATE.ready_written:
        # icinga2 not started yet (entrypoint waits for READY_FILE) -> it will load exactly this config
        STATE.applied_role, STATE.applied_hash, STATE.expected_hosts = "leader", h, expected
        note_success()
        write_ready("leader")
        return

    ok, msg = reload_and_verify(expected)
    if ok:
        STATE.applied_role, STATE.applied_hash, STATE.expected_hosts = "leader", h, expected
        STATE.last_drift_check = time.monotonic()
        note_success()
        log.info(f"Leader reload verified: {msg}")
    else:
        note_failure(f"Leader reload NOT verified: {msg}")


def maintain_leader(now):
    """Leader role already loaded. No reload: config changes restart icinga2 through the
    post-commit hook / reload-master (Rundeck, rebalance). Only keep the symlink and warn."""
    if not symlink_ok():
        try:
            with FS_LOCK:
                if STATE.desired_role != "leader":
                    return
                ensure_symlink()
            log.warning("zones.d symlink was missing or wrong on the leader: recreated, "
                        "icinga2 NOT reloaded (the next post-commit / reload-master loads it)")
        except Exception as e:
            log_throttled("symlink", logging.ERROR, f"Cannot recreate symlink: {e}")
    if now - STATE.last_drift_check < DRIFT_CHECK_INTERVAL:
        return
    STATE.last_drift_check = now
    if program_start() is None:
        return  # icinga2 is restarting (e.g. post-commit hook)
    try:
        count = running_host_count()
    except Exception as e:
        log_throttled("hosts-err", logging.WARNING, f"Cannot count running hosts: {e}")
        return
    if count == 0:
        log_throttled("leader-empty", logging.ERROR,
                      "Leader icinga2 runs with 0 hosts; election does not reload outside "
                      "promote/demote - check zones.d and run reload-master", every=300)


def reconcile_follower(now):
    transitioning = STATE.applied_role != "follower"
    with FS_LOCK:
        if STATE.desired_role != "follower":
            return
        link_removed = remove_symlink()
        markers = clear_authority_markers(include_timestamp=transitioning)

    if not STATE.ready_written:
        STATE.applied_role, STATE.applied_hash, STATE.expected_hosts = "follower", None, None
        STATE.follower_since = now
        write_ready("follower")
        return

    if transitioning or link_removed:
        if now < STATE.next_attempt or program_start() is None:
            return
        ok, msg = reload_and_verify(None)
        if ok:
            STATE.applied_role, STATE.applied_hash, STATE.expected_hosts = "follower", None, None
            STATE.follower_since = STATE.last_drift_check = time.monotonic()
            note_success()
            log.info(f"Follower reload verified ({msg}); waiting for config sync from leader")
        else:
            note_failure(f"Follower reload NOT verified: {msg}")
        return

    if markers:
        # No reload here to avoid a loop; usually Director / a config package deployed to the follower.
        log_throttled("markers", logging.ERROR,
                      "Follower got .authoritative markers again - is something deploying "
                      "config packages (e.g. Director) to this node?")

    if (now - STATE.follower_since > FOLLOWER_SYNC_TIMEOUT
            and now - STATE.last_drift_check >= DRIFT_CHECK_INTERVAL):
        STATE.last_drift_check = now
        try:
            count = running_host_count()
        except Exception:
            return
        if count == 0:
            log_throttled("follower-empty", logging.ERROR,
                          f"Follower still has 0 hosts after {FOLLOWER_SYNC_TIMEOUT}s - check the "
                          "cluster connection to the leader and 'Ignoring config update' in icinga2 log",
                          every=300)


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
    log.info(f"=== Acquired lease: {POD_NAME} is leader ===")
    set_desired("leader")


def lease_held_by_other():
    """True ONLY IF the Lease can be read and its holder is another pod with a valid lease.
    Lease unreadable (flaky API server) -> False: do not demote on a transient error."""
    try:
        # Short timeout: when etcd hangs (a GET lease took up to 25 s), do not wait; treat it as
        # "no other holder seen" -> keep the role, no reload.
        lease = client.CoordinationV1Api().read_namespaced_lease(
            LEASE_NAME, NAMESPACE, _request_timeout=5)
    except Exception as e:
        log_throttled("lease-read", logging.WARNING, f"Cannot read lease: {e}", every=30)
        return False
    spec = lease.spec
    if spec is None or not spec.holder_identity or spec.holder_identity == POD_NAME:
        return False
    renew = _parse_time(spec.renew_time)
    if renew is None:
        return True
    duration = spec.lease_duration_seconds or LEASE_DURATION
    age = (datetime.datetime.now(datetime.timezone.utc) - renew).total_seconds()
    return age < duration


def lease_unconfirmed_too_long():
    """Fence when the lease has not been confirmed for LEASE_DURATION + FENCE_GRACE.
    Return True if we just demoted."""
    if STATE.lease_confirmed_at <= 0:
        return False
    age = time.monotonic() - STATE.lease_confirmed_at
    if age <= LEASE_DURATION + FENCE_GRACE:
        return False
    demote_and_fence(f"lease not confirmed for {age:.0f}s (> {LEASE_DURATION}+{FENCE_GRACE}s); "
                     "another pod may legitimately hold it")
    return True


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
    # A failed renew (usually a flaky API server) does NOT mean another pod became leader.
    # Demote only when another pod clearly holds the lease; otherwise keep the config-master role
    # and let the election loop re-acquire the lease. Reconcile keeps checking the holder every pass.
    if lease_held_by_other():
        demote_and_fence("lease is now held by another pod")
    elif not lease_unconfirmed_too_long():
        log.warning("Lease renew failed but no other holder observed -> keep config-master role, "
                    f"re-acquiring (no reload); fencing after {LEASE_DURATION + FENCE_GRACE}s "
                    "without confirmation")


def main():
    config.load_incluster_config()
    log.info(f"Election client starting on {POD_NAME}")
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
                on_stopped_leading()
            time.sleep(RETRY_PERIOD)


if __name__ == "__main__":
    main()
