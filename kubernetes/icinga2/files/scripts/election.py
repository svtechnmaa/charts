#!/usr/bin/env python3
"""
Icinga2 config master leader election client.
Runs in each master pod. Uses K8s Lease for leader election.
On promote: create symlink, reload Icinga2.
On demote: remove symlink, reload Icinga2.
"""
import datetime, os, shutil, sys, subprocess, logging
from kubernetes import client, config
from kubernetes.client.rest import ApiException
from kubernetes.leaderelection import leaderelection, electionconfig
from kubernetes.leaderelection.leaderelectionrecord import LeaderElectionRecord

logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s %(levelname)s [election] %(message)s')
log = logging.getLogger(__name__)


def _parse_time(value):
    """Parse the str(datetime) timestamps the leaderelection lib hands us
    back into an aware UTC datetime. The kubernetes client serializes
    datetimes via .isoformat(), and the API server's Go RFC3339 parser
    rejects a naive isoformat() string (no Z/offset suffix) with
    'cannot parse "" as "Z07:00"' — so tzinfo must always be set."""
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
        # leaderelection.py builds these from time.time()/fromtimestamp(),
        # i.e. naive local time - anchor to local tz before converting.
        dt = dt.astimezone()
    return dt.astimezone(datetime.timezone.utc)


class LeaseLock:
    """Resourcelock backed by a real coordination.k8s.io/v1 Lease object.

    The pip 'kubernetes' package only ships ConfigMapLock; it never
    bundled a LeaseLock class. This implements the same interface
    (name/namespace/identity + get/create/update) that
    kubernetes.leaderelection.leaderelection.LeaderElection expects.
    """

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
            return True
        except ApiException as e:
            log.info(f"Failed to update lock as {e}")
            return False

POD_NAME       = os.environ["POD_NAME"]
NAMESPACE      = os.environ["NAMESPACE"]
LEASE_NAME     = os.environ["LEASE_NAME"]
OPT_ZONES      = os.environ["OPT_ZONES_DIR"]
ETC_ZONES      = os.environ["ETC_ZONES_DIR"]
API_URL        = "https://localhost:5665"
API_USER       = os.environ.get("ICINGA2_API_USER", "icingaAdmin")
API_PASS       = os.environ.get("ICINGA2_API_PASSWORD", "icingaAdmin")


def run_promote():
    """Called when this pod acquires the Lease and becomes leader.

    Idempotent: safe to call multiple times. Verifies content availability
    before symlink creation to avoid promoting with empty config.
    """
    log.info(f"=== PROMOTE: {POD_NAME} becoming leader ===")

    # -------- Safeguard 1: Verify /opt/zones.d/ có content hợp lệ --------
    if not os.path.isdir(OPT_ZONES):
        log.error(f"{OPT_ZONES} does not exist, cannot promote safely")
        raise RuntimeError(f"Missing content directory: {OPT_ZONES}")
    if not os.listdir(OPT_ZONES):
        log.error(f"{OPT_ZONES} is empty, cannot promote safely")
        log.error("Wait for Syncthing to populate content, then retry")
        raise RuntimeError(f"Empty content directory: {OPT_ZONES}")
    log.info(f"Content verification OK: {OPT_ZONES} populated")

    # -------- Safeguard 2: Idempotent symlink creation --------
    symlink_action = None

    if os.path.islink(ETC_ZONES):
        current_target = os.readlink(ETC_ZONES)
        if current_target == OPT_ZONES:
            log.info(f"Symlink already correct: {ETC_ZONES} -> {OPT_ZONES}")
            symlink_action = "no-op"
        else:
            log.warning(f"Wrong symlink target: {current_target}, fixing")
            os.remove(ETC_ZONES)
            os.symlink(OPT_ZONES, ETC_ZONES)
            symlink_action = "recreated"
    elif os.path.isdir(ETC_ZONES):
        # Icinga2's default package ships a README file in zones.d/ -
        # ignore it, it's not real content that would block promotion.
        stray_entries = [e for e in os.listdir(ETC_ZONES) if e != "README"]
        if stray_entries:
            log.error(f"{ETC_ZONES} is non-empty directory, unexpected state")
            raise RuntimeError(f"Unexpected content in {ETC_ZONES}")
        shutil.rmtree(ETC_ZONES)
        os.symlink(OPT_ZONES, ETC_ZONES)
        log.info(f"Created symlink {ETC_ZONES} -> {OPT_ZONES}")
        symlink_action = "created"
    else:
        raise RuntimeError(f"{ETC_ZONES} in unexpected state")

    # -------- Validate + reload --------
    if symlink_action == "no-op":
        log.info("Symlink unchanged, skip validate+reload")
    else:
        result = subprocess.run(
            ["icinga2", "daemon", "--validate"],
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode != 0:
            log.error(f"Config validation FAILED, rolling back:\n{result.stderr}")
            os.remove(ETC_ZONES)
            os.makedirs(ETC_ZONES, exist_ok=True)
            raise RuntimeError("Config validation failed on promote")
        log.info("Config validation OK")

        trigger_reload()


def run_demote():
    """Called when this pod loses the Lease and becomes follower."""
    log.info(f"=== DEMOTE: {POD_NAME} stepping down to follower ===")

    # 1. Remove symlink
    if os.path.islink(ETC_ZONES):
        os.remove(ETC_ZONES)
        log.info(f"Removed symlink {ETC_ZONES}")
    os.makedirs(ETC_ZONES, exist_ok=True)

    # 2. Reload Icinga2 to pick up empty zones.d
    trigger_reload()

    # 3. Exit — new election attempt will happen when process/loop restarts
    #    (kubernetes leader election library exits after OnStoppedLeading callback)
    log.info("Demote complete, exiting election client")
    sys.exit(0)


def trigger_reload():
    """POST /v1/actions/restart-process on local Icinga2."""
    import requests
    try:
        resp = requests.post(
            f"{API_URL}/v1/actions/restart-process",
            auth=(API_USER, API_PASS), verify=False,
            headers={"Accept": "application/json"}, timeout=60,
        )
        resp.raise_for_status()
        log.info(f"Reload triggered: HTTP {resp.status_code}")
    except Exception as e:
        log.error(f"Reload failed: {e}")


def main():
    config.load_incluster_config()
    log.info(f"Election client starting on {POD_NAME}")

    lock = LeaseLock(LEASE_NAME, NAMESPACE, POD_NAME)

    election_config = electionconfig.Config(
        lock=lock,
        lease_duration=30,
        renew_deadline=20,
        retry_period=5,
        onstarted_leading=run_promote,
        onstopped_leading=run_demote,
    )

    leaderelection.LeaderElection(election_config).run()


if __name__ == "__main__":
    main()