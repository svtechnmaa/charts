#!/usr/bin/env bash
# Render-assertion suite for the conductor subchart.
#
# There is no live cluster in dev, so "tests" mean: render the chart with helm and
# assert on the YAML that comes out. Run from anywhere:
#   bash charts/kubernetes/conductor/tests/render.sh
set -uo pipefail

CHART_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

# Render the chart. Extra args are passed through to helm template.
render() { helm template conductor-test "$CHART_DIR" "$@" 2>&1; }

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n      expected: %s\n' "$1" "$2"; FAILED=1; }

# assert_contains <description> <literal-needle> <haystack>
assert_contains() {
  if grep -qF -- "$2" <<<"$3"; then pass "$1"; else fail "$1" "to contain: $2"; fi
}

# assert_absent <description> <literal-needle> <haystack>
assert_absent() {
  if grep -qF -- "$2" <<<"$3"; then fail "$1" "NOT to contain: $2"; else pass "$1"; fi
}

# assert_env_value <description> <env-name> <expected-value> <haystack>
# An env var's name and value land on consecutive lines, which grep -F cannot match as a
# single needle, so pair them explicitly instead of asserting on the value alone.
assert_env_value() {
  if grep -A1 -F -- "name: $2" <<<"$4" | grep -qF -- "value: \"$3\""; then
    pass "$1"
  else
    fail "$1" "env $2 to be \"$3\""
  fi
}

# assert_render_fails <description> <literal-needle-in-the-error> <helm args...>
# Some value combinations must abort the render rather than produce YAML.
assert_render_fails() {
  local desc="$1" needle="$2"; shift 2
  local out
  if out="$(helm template conductor-test "$CHART_DIR" "$@" 2>&1)"; then
    fail "$desc" "helm template to exit non-zero"
  elif grep -qF -- "$needle" <<<"$out"; then
    pass "$desc"
  else
    fail "$desc" "the error to contain: $needle"
  fi
}

# assert_mount_read_only <description> <mount-path> <haystack>
# A volumeMount renders name, mountPath, then readOnly on consecutive lines.
assert_mount_read_only() {
  if grep -A1 -F -- "mountPath: $2" <<<"$3" | grep -qF -- "readOnly: true"; then
    pass "$1"
  else
    fail "$1" "mount $2 to be readOnly: true"
  fi
}

# repo_vol <index>
# helm args sharing the automation repo with the worker at sharedPersistenceVolume[<index>],
# the way the nmaa stack does. The worker runs its code from that mount, so every render
# that enables the worker needs it: mapfile -t ARR < <(repo_vol 0).
repo_vol() {
  printf '%s\n' --set global.sharedVolume.enabled=true \
    --set "global.sharedPersistenceVolume[$1].volumeName=automation-repo-volume" \
    --set "global.sharedPersistenceVolume[$1].pvcName=automation-repo-pvc" \
    --set "global.sharedPersistenceVolume[$1].path=/opt/SVTECH-Junos-Automation" \
    --set "global.sharedPersistenceVolume[$1].shareFor[0]=conductor-worker"
}
mapfile -t REPO0 < <(repo_vol 0)
mapfile -t REPO1 < <(repo_vol 1)

# doc_for <source-path> <haystack>
# Isolate one rendered document by its "# Source:" path, so an assertion cannot be
# satisfied by a different object elsewhere in the render.
doc_for() {
  awk -v p="$1" '$0=="# Source: "p{f=1;next} f&&/^# Source: /{exit} f' <<<"$2"
}

# A yaml-capable interpreter. `python3` on PATH may be a pyenv shim without PyYAML while
# the system python has it, so probe instead of assuming.
PY=""
for candidate in python3 /usr/bin/python3; do
  if "$candidate" -c 'import yaml' 2>/dev/null; then PY="$candidate"; break; fi
done
[ -n "$PY" ] || { echo "FAIL: no python3 with PyYAML found (tried python3, /usr/bin/python3)"; exit 2; }

echo "=== helm lint ==="
if helm lint "$CHART_DIR" >/dev/null 2>&1; then pass "helm lint clean"; else fail "helm lint clean" "exit 0"; helm lint "$CHART_DIR"; fi

echo "=== defaults: bundled postgresql cluster ==="
if DEFAULT="$(render)"; then pass "default render succeeds"; else fail "default render succeeds" "helm template to exit 0"; fi
assert_contains "pgpool service is named conductor-postgresql-pgpool" "name: conductor-postgresql-pgpool" "$DEFAULT"
assert_contains "postgresql statefulset is named conductor-postgresql-postgresql" "name: conductor-postgresql-postgresql" "$DEFAULT"
assert_env_value "the bundled cluster creates database conductor" "POSTGRES_DB" "conductor" "$DEFAULT"
assert_contains "storage class for the bundled cluster exists" "name: \"conductor-postgresql\"" "$DEFAULT"
assert_contains "one hostPath PV is rendered for replica 0" "name: conductor-postgresql-data-default-0" "$DEFAULT"
assert_contains "postgres image comes from the ghcr mirror" "ghcr.io/svtechnmaa/postgresql-repmgr:14.5.0-debian-11-r19" "$DEFAULT"

PGPOOL_SVC="$(doc_for conductor/charts/postgresql-ha/templates/pgpool/service.yaml "$DEFAULT")"
assert_contains "pgpool Service exposes postgres on 5432" "port: 5432" "$PGPOOL_SVC"
assert_contains "pgpool Service targets the named container port" "targetPort: postgresql" "$PGPOOL_SVC"

echo "=== postgresqlHa disabled: no cluster, no PVs ==="
if EXTERNAL="$(render --set postgresqlHa.enabled=false)"; then pass "external-database render succeeds"; else fail "external-database render succeeds" "helm template to exit 0"; fi
assert_absent "no statefulset when using an external database" "kind: StatefulSet" "$EXTERNAL"
assert_absent "no storage class when using an external database" "kind: StorageClass" "$EXTERNAL"

echo "=== conductor server ==="
# grep -F treats a multi-line needle as OR, so assert the Service name with a single-line
# needle plus a structural check done separately below.
assert_contains "a service named exactly conductor exists" "  name: conductor" "$DEFAULT"
# helm's own coalesce.go warning (see values.yaml note above the postgresql-ha block)
# is harmless but is not valid YAML, so stderr is dropped here rather than merged via
# render() - otherwise it would sit ahead of the "---" document markers and break the
# parser on every single render, not just in some environments.
if [ "$(helm template conductor-test "$CHART_DIR" 2>/dev/null | "$PY" -c "
import sys, yaml
docs = [d for d in yaml.safe_load_all(sys.stdin) if d]
print(sum(1 for d in docs if d.get('kind') == 'Service' and d['metadata']['name'] == 'conductor'))
")" = "1" ]; then
  pass "exactly one Service is named conductor (ingress TCP passthrough depends on it)"
else
  fail "exactly one Service is named conductor (ingress TCP passthrough depends on it)" "1 such Service"
fi
assert_contains "service exposes the UI port" "port: 5000" "$DEFAULT"
assert_contains "service exposes the API port" "port: 8080" "$DEFAULT"
assert_contains "server image is the ghcr mirror" "ghcr.io/svtechnmaa/svtech_conductor:3.31.0" "$DEFAULT"
assert_contains "CONFIG_PROP selects the mounted properties file" "value: config-nmaa.properties" "$DEFAULT"
assert_contains "properties file is mounted by subPath so /app/config is not shadowed" "subPath: config-nmaa.properties" "$DEFAULT"
assert_contains "execution store is postgres" "conductor.db.type=postgres" "$DEFAULT"
assert_contains "queues are postgres" "conductor.queue.type=postgres" "$DEFAULT"
assert_contains "indexing is postgres" "conductor.indexing.type=postgres" "$DEFAULT"
assert_contains "elasticsearch is explicitly disabled" "conductor.elasticsearch.version=0" "$DEFAULT"
assert_contains "jdbc url points at the bundled pgpool" "jdbc:postgresql://conductor-postgresql-pgpool:5432/conductor" "$DEFAULT"
assert_contains "demo workflow is not loaded" "loadSample=false" "$DEFAULT"
assert_contains "config changes roll the pods" "checksum/config:" "$DEFAULT"
# Scoped: the vendored postgresql-ha subchart emits the same pull-secret name, so an
# unscoped needle passes even when the conductor pod has no imagePullSecrets at all.
CONDUCTOR_DEPLOY="$(doc_for conductor/templates/deployment.yaml "$DEFAULT")"
assert_contains "ghcr pull secret is set on the conductor pod" "name: ghcr-pull-secret" "$CONDUCTOR_DEPLOY"
# The lock properties live in the properties Secret, so scope there - and assert the Secret
# actually rendered first, because "absent" is trivially true against an empty render.
CONDUCTOR_SECRET="$(doc_for conductor/templates/secret.yaml "$DEFAULT")"
assert_contains "the properties Secret rendered" "conductor.db.type=postgres" "$CONDUCTOR_SECRET"
assert_absent "no lock config at replicaCount 1" "conductor.workflow-execution-lock.type" "$CONDUCTOR_SECRET"
assert_contains "payload storage uses the datasource database" "conductor.external-payload-storage.postgres.url=jdbc:postgresql://conductor-postgresql-pgpool:5432/conductor" "$CONDUCTOR_SECRET"
assert_contains "payload storage user matches the datasource" "conductor.external-payload-storage.postgres.username=conductor" "$CONDUCTOR_SECRET"
assert_contains "payload URIs are absolute, on the conductor Service" "conductor.external-payload-storage.postgres.conductor-url=http://conductor:8080" "$CONDUCTOR_SECRET"

echo "=== a remapped API Service port is followed everywhere ==="
mapfile -t API9090 < <(printf '%s\n' --set service.ports[0].name=ui --set service.ports[0].port=5000 --set service.ports[0].targetPort=5000 \
  --set service.ports[1].name=api --set service.ports[1].port=9090 --set service.ports[1].targetPort=8080)
REMAPPED="$(render "${API9090[@]}" --set worker.enabled=true --set registerWorkflows.enabled=true "${REPO0[@]}")"
assert_contains "payload URIs use the Service port, not the container port" "conductor-url=http://conductor:9090" "$(doc_for conductor/templates/secret.yaml "$REMAPPED")"
assert_contains "the worker reaches the API on the Service port" "value: http://conductor:9090/api" "$(doc_for conductor/templates/worker-deployment.yaml "$REMAPPED")"
assert_contains "the registration job reaches the API on the Service port" "value: http://conductor:9090/api" "$(doc_for conductor/templates/register-workflows-job.yaml "$REMAPPED")"
assert_render_fails "a Service without an api port is refused" "service.ports must include a port named api" \
  --set service.ports[0].name=ui --set service.ports[0].port=5000 --set service.ports[0].targetPort=5000

echo "=== conductor server, scaled out with redis lock ==="
SCALED="$(render --set replicaCount=3 --set lock.enabled=true)"
assert_contains "replicas honoured" "replicas: 3" "$SCALED"
assert_contains "redis lock type set" "conductor.workflow-execution-lock.type=redis" "$SCALED"
assert_contains "lock enabled flag set" "conductor.app.workflowExecutionLockEnabled=true" "$SCALED"
assert_contains "redis lock address set" "conductor.redis-lock.serverAddress=redis://redis:6379" "$SCALED"

echo "=== external database mode ==="
assert_contains "jdbc url follows the external host" "jdbc:postgresql://pg.example.internal:5432/conductor" \
  "$(render --set postgresqlHa.enabled=false --set postgresql.host=pg.example.internal)"

echo "=== HA: unsafe value combinations abort the render ==="
assert_render_fails "scaling past one replica without the lock is refused" \
  "but lock.enabled is false" --set replicaCount=2
assert_render_fails "the lock with an empty redisUrl is refused" \
  "lock.redisUrl is empty" --set replicaCount=2 --set lock.enabled=true --set lock.redisUrl=""
assert_render_fails "more than one discovery worker is refused" \
  "must stay at 1" --set worker.enabled=true --set worker.replicaCount=2 "${REPO0[@]}"

echo "=== HA: no PodDisruptionBudget over a single replica ==="
assert_absent "no PDB in the default profile" "kind: PodDisruptionBudget" "$DEFAULT"
assert_absent "a PDB is not rendered at one replica even when asked for" \
  "kind: PodDisruptionBudget" "$(render --set podDisruptionBudget.create=true)"

echo "=== HA profile ==="
HA="$(render --set replicaCount=2 \
  --set lock.enabled=true \
  --set podDisruptionBudget.create=true \
  --set 'postgresql-ha.postgresql.replicaCount=3' \
  --set 'postgresql-ha.postgresql.pdb.create=true' \
  --set 'postgresql-ha.postgresql.pdb.minAvailable=2' \
  --set 'postgresql-ha.pgpool.replicaCount=2' \
  --set 'postgresql-ha.pgpool.pdb.create=true')"
# Scoped to the conductor Deployment. The vendored subchart's pgpool Deployment and
# postgresql StatefulSet also emit podAntiAffinity, and this profile sets pgpool's
# replicaCount to 2 as well, so unscoped needles pass even if conductor's own replica
# count or anti-affinity block regressed. helm template cannot verify that pods actually
# land on different nodes - that is a scheduler outcome - but it can pin that the soft
# rule exists and still selects conductor's own pods.
CONDUCTOR_HA_DOC="$(doc_for conductor/templates/deployment.yaml "$HA")"
assert_contains "two conductor replicas" "replicas: 2" "$CONDUCTOR_HA_DOC"
assert_contains "conductor's own anti-affinity is the soft preset" "preferredDuringSchedulingIgnoredDuringExecution" "$CONDUCTOR_HA_DOC"
assert_contains "the anti-affinity selects conductor's own pods" "app.kubernetes.io/instance: conductor-test" "$CONDUCTOR_HA_DOC"
assert_contains "the lock is configured" "conductor.app.workflowExecutionLockEnabled=true" "$HA"
assert_contains "PDBs use policy/v1, not the removed policy/v1beta1" "apiVersion: policy/v1" "$HA"
assert_absent "no policy/v1beta1 anywhere" "policy/v1beta1" "$HA"
assert_contains "three postgres nodes" "replicas: 3" "$HA"
assert_contains "a hostPath PV exists for postgres replica 2" \
  "name: conductor-postgresql-data-default-2" "$HA"
assert_contains "the postgres PDB keeps a quorum" "minAvailable: 2" "$HA"
if [ "$(grep -c "kind: PodDisruptionBudget" <<<"$HA")" = "3" ]; then
  pass "three PodDisruptionBudgets: conductor, postgresql, pgpool"
else
  fail "three PodDisruptionBudgets: conductor, postgresql, pgpool" \
       "3 PodDisruptionBudget documents, got $(grep -c "kind: PodDisruptionBudget" <<<"$HA")"
fi

echo "=== HA: an infeasible vendored PodDisruptionBudget is refused ==="
assert_render_fails "postgres PDB needing more pods than exist is refused" \
  "can never allow a voluntary eviction" --set 'postgresql-ha.postgresql.pdb.create=true'
assert_render_fails "a 1-of-1 pgpool PDB is refused" \
  "can never allow a voluntary eviction" --set 'postgresql-ha.pgpool.pdb.create=true'
assert_contains "the real HA profile is still accepted" "kind: PodDisruptionBudget" "$HA"
PCT="$(render --set 'postgresql-ha.postgresql.pdb.create=true' --set 'postgresql-ha.postgresql.pdb.minAvailable=50%')"
assert_contains "a percentage minAvailable is not compared to a replica count" "kind: PodDisruptionBudget" "$PCT"

echo "=== persistence: the two storage keys must agree ==="
assert_render_fails "a storageClass set on only one of the two keys is refused" \
  "They must match or no PVC ever binds" --set postgresqlHa.persistence.storageClass=fast-disk
assert_render_fails "a size set on only one of the two keys is refused" \
  "A claim larger than its PV never binds" --set postgresqlHa.persistence.size=20Gi
CONSISTENT="$(render --set postgresqlHa.persistence.storageClass=fast-disk --set 'postgresql-ha.persistence.storageClass=fast-disk')"
assert_contains "changing both keys together is accepted" "fast-disk" "$CONSISTENT"

echo "=== the chart's own PodDisruptionBudget is checked too ==="
assert_render_fails "a PDB with both minAvailable and maxUnavailable is refused" \
  "Kubernetes rejects a PodDisruptionBudget carrying both" \
  --set replicaCount=2 --set lock.enabled=true --set podDisruptionBudget.create=true \
  --set podDisruptionBudget.maxUnavailable=1
assert_render_fails "a PDB demanding every replica is refused" \
  "can never allow a voluntary eviction" \
  --set replicaCount=2 --set lock.enabled=true --set podDisruptionBudget.create=true \
  --set podDisruptionBudget.minAvailable=2

echo "=== workflow registration job ==="
assert_absent "no registration job by default" "kind: Job" "$DEFAULT"
REGISTER="$(render --set registerWorkflows.enabled=true --set global.sharedVolume.enabled=true \
  --set 'global.sharedPersistenceVolume[0].volumeName=automation-repo-volume' \
  --set 'global.sharedPersistenceVolume[0].pvcName=automation-repo-pvc' \
  --set 'global.sharedPersistenceVolume[0].path=/opt/SVTECH-Junos-Automation' \
  --set 'global.sharedPersistenceVolume[0].shareFor[0]=conductor-register')"
assert_contains "job is rendered when enabled" "kind: Job" "$REGISTER"
assert_contains "job is a post-install/post-upgrade hook" "helm.sh/hook: post-install,post-upgrade" "$REGISTER"
assert_contains "job targets the in-cluster api" "http://conductor:8080/api" "$REGISTER"
assert_contains "job runs register.py from the automation repo" "register.py" "$REGISTER"
assert_contains "job mounts the automation repo volume" "claimName: automation-repo-pvc" "$REGISTER"
assert_contains "job registers from the conductor_workflows package" \
  'DEFS="/opt/SVTECH-Junos-Automation/Python-Development/conductor_workflows"' "$REGISTER"
assert_contains "job runs on the worker runtime image" \
  "image: ghcr.io/svtechnmaa/svtech_conductor_worker:v1.0.0" "$REGISTER"
assert_absent "job no longer pulls the automation repo image" "svtech-junos-automation" "$REGISTER"
assert_mount_read_only "job mounts the automation repo read-only" "/opt/SVTECH-Junos-Automation" "$REGISTER"
REGISTER_TAG="$(render --set registerWorkflows.enabled=true --set worker.image.tag=v9.9.9)"
assert_contains "job follows worker.image.tag (the tag CI bumps)" \
  "image: ghcr.io/svtechnmaa/svtech_conductor_worker:v9.9.9" "$REGISTER_TAG"

echo "=== worker ==="
assert_absent "no worker deployment by default" "app.kubernetes.io/component: conductor-worker" "$DEFAULT"
WORKER="$(render --set worker.enabled=true --set global.sharedVolume.enabled=true \
  --set 'global.sharedPersistenceVolume[0].volumeName=icinga2-zones-volume' \
  --set 'global.sharedPersistenceVolume[0].pvcName=icinga2-zones-pvc' \
  --set 'global.sharedPersistenceVolume[0].path=/etc/icinga2/zones.d' \
  --set 'global.sharedPersistenceVolume[0].shareFor[0]=conductor-worker' "${REPO1[@]}")"
assert_contains "worker deployment is rendered when enabled" "app.kubernetes.io/component: conductor-worker" "$WORKER"

# The worker image is the runtime only; its CMD runs run_workers.py from the automation
# repo, which the stack shares with the worker like it does with rundeck. Read-only: the
# worker writes into zones.d and gitlist, never into its own code.
WORKER_DOC="$(doc_for conductor/templates/worker-deployment.yaml "$WORKER")"
assert_contains "worker mounts its own temp dir" "mountPath: /tmp/conductor_workflows" "$WORKER_DOC"
assert_contains "worker mounts the automation repo" "claimName: automation-repo-pvc" "$WORKER_DOC"
assert_mount_read_only "the automation repo is mounted read-only" "/opt/SVTECH-Junos-Automation" "$WORKER_DOC"
if grep -A1 -F -- "mountPath: /etc/icinga2/zones.d" <<<"$WORKER_DOC" | grep -qF "readOnly"; then
  fail "zones.d stays writable" "no readOnly on /etc/icinga2/zones.d"
else
  pass "zones.d stays writable"
fi
assert_render_fails "a worker without the automation repo is refused" \
  "no volume at /opt/SVTECH-Junos-Automation is shared with conductor-worker" --set worker.enabled=true

assert_contains "worker polls the in-cluster api" "http://conductor:8080/api" "$WORKER"
assert_contains "worker mounts the icinga2 zones volume" "claimName: icinga2-zones-pvc" "$WORKER"
assert_contains "worker uses Recreate so only one writer touches the git repo" "type: Recreate" "$WORKER"
assert_contains "worker receives the NMS config path the playbooks write into" "DISCOVERY_NMS_PATH" "$WORKER"
# The stack's shared volumes are hostPath PVs, where kubelet never applies fsGroup, and the
# folders on them are root-owned - the worker writes zones.d, gitlist and git commits as root.
assert_contains "worker runs as root" "runAsUser: 0" "$WORKER_DOC"
assert_absent "worker does not rely on fsGroup" "fsGroup:" "$WORKER_DOC"
assert_contains "worker mounts its own ansible-runner dir" "mountPath: /tmp/conductor_workflows_runner" "$WORKER_DOC"
assert_env_value "worker is told where the ansible-runner dir is" "DISCOVERY_RUNNER_DIR" "/tmp/conductor_workflows_runner" "$WORKER_DOC"

echo "=== worker: icinga2 reload targets ==="
# icinga2_reload posts to every master by pod name. Derived from the release that also
# installs icinga2 (the nmaa stack), so the default names master-0 only.
assert_env_value "one master by default" "ICINGA2_RELOAD_URLS" \
  "https://conductor-test-icinga2-master-0.icinga2-headless.default.svc.cluster.local:5665" "$WORKER_DOC"
TWO_MASTERS="$(doc_for conductor/templates/worker-deployment.yaml "$(render --set worker.enabled=true \
  --set worker.icinga2.masterReplicaCount=2 --namespace nmaa "${REPO0[@]}")")"
assert_env_value "one url per master, in the release namespace" "ICINGA2_RELOAD_URLS" \
  "https://conductor-test-icinga2-master-0.icinga2-headless.nmaa.svc.cluster.local:5665,https://conductor-test-icinga2-master-1.icinga2-headless.nmaa.svc.cluster.local:5665" "$TWO_MASTERS"
EXPLICIT="$(doc_for conductor/templates/worker-deployment.yaml "$(render --set worker.enabled=true \
  --set 'worker.icinga2.reloadUrls[0]=https://m0:5665' --set 'worker.icinga2.reloadUrls[1]=https://m1:5665' "${REPO0[@]}")")"
assert_env_value "explicit reloadUrls replace the derived list" "ICINGA2_RELOAD_URLS" "https://m0:5665,https://m1:5665" "$EXPLICIT"
assert_render_fails "a worker with no reload target is refused" \
  "no icinga2 master to reload" --set worker.enabled=true --set worker.icinga2.masterReplicaCount=0 "${REPO0[@]}"

echo "=== worker: icinga2 API password ==="
# The password lives in a Secret, so reading the Deployment does not reveal it.
PW="$(render --set worker.enabled=true --set worker.icinga2.apiPassword=s3cret-pw "${REPO0[@]}")"
PW_DEPLOY="$(doc_for conductor/templates/worker-deployment.yaml "$PW")"
PW_SECRET="$(doc_for conductor/templates/worker-secret.yaml "$PW")"
assert_contains "the worker Secret is rendered" "name: conductor-test-worker" "$PW_SECRET"
assert_contains "it holds the icinga2 API password" 'ICINGA2_API_PASSWORD: "s3cret-pw"' "$PW_SECRET"
assert_absent "the Deployment does not carry the password" "s3cret-pw" "$PW_DEPLOY"
assert_contains "the worker reads it from the Secret" "secretKeyRef:" "$PW_DEPLOY"
assert_contains "from the chart's worker Secret" "name: conductor-test-worker" \
  "$(grep -A1 -F 'secretKeyRef:' <<<"$PW_DEPLOY")"
assert_contains "a password change rolls the worker" "checksum/secret:" "$PW_DEPLOY"
EXISTING="$(render --set worker.enabled=true --set worker.icinga2.existingSecret=icinga2-api "${REPO0[@]}")"
assert_absent "existingSecret: the chart creates no worker Secret" \
  "# Source: conductor/templates/worker-secret.yaml" "$EXISTING"
assert_contains "existingSecret: the worker reads the named Secret" "name: icinga2-api" \
  "$(doc_for conductor/templates/worker-deployment.yaml "$EXISTING" | grep -A1 -F 'secretKeyRef:')"
assert_absent "no worker Secret without the worker" "# Source: conductor/templates/worker-secret.yaml" "$DEFAULT"

echo "=== worker: one ConfigMap per job ==="
# One template renders every job's ConfigMap, so doc_for would only isolate the first;
# the data keys below are unique to these ConfigMaps within the whole render.
assert_contains "the shared job ConfigMap is rendered" "name: conductor-test-worker-env-shared" "$WORKER"
assert_contains "the backup job ConfigMap is rendered" "name: conductor-test-worker-env-backup" "$WORKER"
assert_contains "git trusts the root-owned shared repos" 'GIT_CONFIG_VALUE_0: "*"' "$WORKER"
assert_contains "git has a committer identity" 'GIT_COMMITTER_NAME: "nmaa-conductor"' "$WORKER"
assert_contains "backup writes into the gitlist volume" 'BACKUP_PATH: "/opt/gitlist/backup_config"' "$WORKER"
assert_contains "backup forks are capped below ansible.cfg's 50" 'BACKUP_FORKS: "20"' "$WORKER"
assert_contains "the worker loads the shared ConfigMap" "name: conductor-test-worker-env-shared" "$WORKER_DOC"
assert_contains "the worker loads the backup ConfigMap" "name: conductor-test-worker-env-backup" "$WORKER_DOC"
assert_contains "job settings changes roll the worker" "checksum/job-env:" "$WORKER_DOC"
NEW_JOB="$(render --set worker.enabled=true --set worker.jobEnv.audit.AUDIT_DIR=/tmp/audit "${REPO0[@]}")"
assert_contains "a new job adds a ConfigMap from values alone" "name: conductor-test-worker-env-audit" "$NEW_JOB"
assert_contains "and the worker loads it" "name: conductor-test-worker-env-audit" \
  "$(doc_for conductor/templates/worker-deployment.yaml "$NEW_JOB")"
assert_render_fails "a key set by two jobs is refused" \
  "BACKUP_PATH is set by both" --set worker.enabled=true --set worker.jobEnv.audit.BACKUP_PATH=/x "${REPO0[@]}"
assert_render_fails "a job key the deployment already sets is refused" \
  "DISCOVERY_NMS_PATH is set by the worker deployment" \
  --set worker.enabled=true --set worker.jobEnv.audit.DISCOVERY_NMS_PATH=/x "${REPO0[@]}"
assert_absent "no job ConfigMaps without the worker" "worker-env-shared" "$DEFAULT"

echo "=== worker: gitlist volume for device_backup ==="
GITLIST="$(doc_for conductor/templates/worker-deployment.yaml "$(render --set worker.enabled=true \
  --set global.sharedVolume.enabled=true \
  --set 'global.sharedPersistenceVolume[0].volumeName=gitlist-data-volume' \
  --set 'global.sharedPersistenceVolume[0].pvcName=gitlist-data-pvc' \
  --set 'global.sharedPersistenceVolume[0].path=/opt/gitlist' \
  --set 'global.sharedPersistenceVolume[0].shareFor[0]=conductor-worker' "${REPO1[@]}")")"
assert_contains "worker mounts gitlist when the stack shares it" "mountPath: /opt/gitlist" "$GITLIST"
assert_contains "from the gitlist claim" "claimName: gitlist-data-pvc" "$GITLIST"

echo
if [ "$FAILED" -eq 0 ]; then echo "ALL ASSERTIONS PASSED"; else echo "SOME ASSERTIONS FAILED"; fi
exit "$FAILED"
