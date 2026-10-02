{{/* vim: set filetype=mustache: */}}

{{/*
Conductor server image.
*/}}
{{- define "conductor.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Init container image used to wait for PostgreSQL.
*/}}
{{- define "conductor.waitForPostgres.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.initContainer.waitForPostgres.image "global" .Values.global) }}
{{- end -}}

{{/*
NMAA worker image (every converted job). The registration Job runs on it too.
*/}}
{{- define "conductor.worker.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.worker.image "global" .Values.global) }}
{{- end -}}

{{/*
The Secret holding the worker's ICINGA2_API_PASSWORD: worker.icinga2.existingSecret when set,
otherwise the one worker-secret.yaml renders.
*/}}
{{- define "conductor.worker.secretName" -}}
{{- .Values.worker.icinga2.existingSecret | default (printf "%s-worker" (include "common.names.fullname" .)) -}}
{{- end -}}

{{/*
Comma-separated icinga2 master API URLs for the worker's icinga2_reload task
(ICINGA2_RELOAD_URLS). worker.icinga2.reloadUrls wins when set; otherwise one URL per master
pod of the icinga2 chart installed by the same release. That chart names its masters
<release>-icinga2-master-<i> behind the icinga2-headless Service (common.names.fullname,
which drops the "-icinga2" suffix when the release name already contains it - hence the
check below).
*/}}
{{- define "conductor.worker.reloadUrls" -}}
{{- if .Values.worker.icinga2.reloadUrls -}}
{{- join "," .Values.worker.icinga2.reloadUrls -}}
{{- else -}}
{{- $master := ternary .Release.Name (printf "%s-icinga2" .Release.Name) (contains "icinga2" .Release.Name) -}}
{{- $urls := list -}}
{{- range $i := until (int .Values.worker.icinga2.masterReplicaCount) -}}
{{- $urls = append $urls (printf "https://%s-master-%d.icinga2-headless.%s.svc.cluster.local:5665" $master $i $.Release.Namespace) -}}
{{- end -}}
{{- join "," $urls -}}
{{- end -}}
{{- end -}}

{{/*
Where the worker's code is: the automation repo mount. The worker image's CMD runs
Python-Development/conductor_workflows/workers/run_workers.py from here, so this path is
fixed by the image, not a value.
*/}}
{{- define "conductor.worker.repoPath" -}}
/opt/SVTECH-Junos-Automation
{{- end -}}

{{/*
Env var names the worker Deployment sets itself. A worker.jobEnv key must not repeat one:
a container's env entry silently overrides the same key from envFrom.
*/}}
{{- define "conductor.worker.envNames" -}}
TZ CONDUCTOR_SERVER_URL DISCOVERY_NMS_PATH DISCOVERY_TEMP_DIR DISCOVERY_RUNNER_DIR ICINGA2_CONTAINER ICINGA2_API_HOST ICINGA2_API_USER ICINGA2_API_PASSWORD ICINGA2_RELOAD_URLS
{{- end -}}

{{/*
PostgreSQL host. When the cluster is bundled, this is the pgpool service, whose name
is derived from the dependency's fullnameOverride so it never depends on the release
name. Otherwise the operator-supplied host is used verbatim.
*/}}
{{- define "conductor.postgresql.host" -}}
{{- if .Values.postgresqlHa.enabled -}}
{{- printf "%s-pgpool" (index .Values "postgresql-ha").fullnameOverride -}}
{{- else -}}
{{- .Values.postgresql.host -}}
{{- end -}}
{{- end -}}

{{/*
JDBC URL for the Conductor datasource.
*/}}
{{- define "conductor.jdbcUrl" -}}
{{- printf "jdbc:postgresql://%s:%v/%s" (include "conductor.postgresql.host" .) .Values.postgresql.port .Values.postgresql.database -}}
{{- end -}}

{{/*
Name of the conductor Service. Fixed to the chart name, not the fullname: ingress TCP
passthrough and the workers address the server as plain "conductor".
*/}}
{{- define "conductor.serviceName" -}}
{{- .Chart.Name -}}
{{- end -}}

{{/*
In-cluster base URL of the Conductor API, e.g. http://conductor:8080. Uses the exposed port of
the service.ports entry named "api", not the container port, so a remapped Service port is
followed everywhere. Same approach as netforge-be's conductorUrl helper.
*/}}
{{- define "conductor.apiUrl" -}}
{{- $apiPort := dict -}}
{{- range .Values.service.ports -}}
{{- if eq .name "api" -}}
{{- $_ := set $apiPort "port" .port -}}
{{- end -}}
{{- end -}}
{{- printf "http://%s:%v" (include "conductor.serviceName" .) (required "service.ports must include a port named api" $apiPort.port) -}}
{{- end -}}

{{/*
Basename of the properties file mounted into /app/config and named by CONFIG_PROP.
*/}}
{{- define "conductor.configFileName" -}}
config-nmaa.properties
{{- end -}}

{{/*
Kubernetes API version for PodDisruptionBudget.

This is normally supplied by the `common` library chart, but neither common-1.4.3.tgz nor the
`common` bundled inside postgresql-ha-9.4.6-svtech defines it, so the dependency's own
templates/postgresql/pdb.yaml and templates/pgpool/pdb.yaml fail with
  no template "common.capabilities.policy.apiVersion" associated with template "gotpl"
the moment pdb.create is set. Helm merges template definitions across the whole chart tree, so
defining it here fixes the dependency's templates as well as ours. Implementation copied from
common 2.x so a future common upgrade is a no-op. (charts/kubernetes/freeradius has the same
latent bug and needs the same fix in a separate change.)
*/}}
{{- define "common.capabilities.policy.apiVersion" -}}
{{- if semverCompare "<1.21-0" (include "common.capabilities.kubeVersion" .) -}}
{{- print "policy/v1beta1" -}}
{{- else -}}
{{- print "policy/v1" -}}
{{- end -}}
{{- end -}}

{{/*
Refuse to render value combinations that produce a broken deployment.

1. Conductor's Decider and Sweeper are not safe to run concurrently. Two servers without the
   distributed workflow-execution lock evaluate the same workflow and double-schedule its tasks,
   so this is corruption, not degradation - hence fail, not a warning.
2. The worker generates config and commits to shared git repos (see
   worker-deployment.yaml, strategy: Recreate). More than one replica is always wrong.

Include it from deployment.yaml; it renders nothing.
*/}}
{{- define "conductor.validateValues" -}}
{{- $errors := list }}
{{- $replicas := int (include "common.replicas" (dict "replicaCount" .Values.replicaCount "global" .Values.global)) }}
{{- if and (gt $replicas 1) (not .Values.lock.enabled) }}
{{- $errors = append $errors (printf "replicaCount is %d but lock.enabled is false: set lock.enabled=true and lock.redisUrl=<redis url>, or keep replicaCount at 1" $replicas) }}
{{- end }}
{{- if and .Values.lock.enabled (empty .Values.lock.redisUrl) }}
{{- $errors = append $errors "lock.enabled is true but lock.redisUrl is empty: point it at the stack's redis service, e.g. redis://redis:6379" }}
{{- end }}
{{- if and .Values.worker.enabled (gt (int .Values.worker.replicaCount) 1) }}
{{- $errors = append $errors (printf "worker.replicaCount is %d: the worker is the single writer to the shared git repos and must stay at 1" (int .Values.worker.replicaCount)) }}
{{- end }}
{{/*
3. The worker runs its code from the automation repo mount, needs at least one icinga2
   master for icinga2_reload to post to, and its per-job ConfigMaps must not fight over a
   key: envFrom resolves a clash silently, in list order.
*/}}
{{- if .Values.worker.enabled }}
{{- $repoPath := include "conductor.worker.repoPath" . }}
{{- $repoShared := false }}
{{- if .Values.global.sharedVolume.enabled }}
{{- range .Values.global.sharedPersistenceVolume }}
{{- if and (has "conductor-worker" .shareFor) (eq .path $repoPath) }}
{{- $repoShared = true }}
{{- end }}
{{- end }}
{{- end }}
{{- if not $repoShared }}
{{- $errors = append $errors (printf "worker.enabled is true but no volume at %s is shared with conductor-worker: the worker image carries no code and runs run_workers.py from that mount, so the pod could not start. Add conductor-worker to the shareFor of the automation-repo volume in global.sharedPersistenceVolume (and set global.sharedVolume.enabled=true)" $repoPath) }}
{{- end }}
{{- if empty (include "conductor.worker.reloadUrls" .) }}
{{- $errors = append $errors "worker.icinga2.masterReplicaCount is 0 and worker.icinga2.reloadUrls is empty: there is no icinga2 master to reload after a job writes config. Set masterReplicaCount to icinga2.master.replicaCount, or list the URLs" }}
{{- end }}
{{- $reserved := splitList " " (include "conductor.worker.envNames" .) }}
{{- $owner := dict }}
{{- range $job, $vars := .Values.worker.jobEnv }}
{{- range $key, $_ := $vars }}
{{- if has $key $reserved }}
{{- $errors = append $errors (printf "worker.jobEnv.%s.%s: %s is set by the worker deployment itself, which silently overrides a ConfigMap value. Use the matching worker.* value instead" $job $key $key) }}
{{- else if hasKey $owner $key }}
{{- $errors = append $errors (printf "worker.jobEnv: %s is set by both %s and %s. Keep each key in one job" $key (get $owner $key) $job) }}
{{- else }}
{{- $_ := set $owner $key $job }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{/*
The vendored postgresql-ha chart's PDBs are not guarded the way templates/pdb.yaml guards
conductor's own. Its shipped defaults pair minAvailable 2 (postgresql) and 1 (pgpool) with
replicaCount 1, so flipping only pdb.create=true yields a budget that can never permit a
voluntary eviction - kubectl drain then blocks forever. minAvailable may also be a
percentage string, which is not comparable to a replica count, so those are skipped.
*/}}
{{- $ha := index .Values "postgresql-ha" }}
{{- range $component := list "postgresql" "pgpool" }}
{{- $cfg := index $ha $component }}
{{- if and $cfg.pdb $cfg.pdb.create }}
{{- $minAvail := $cfg.pdb.minAvailable | toString }}
{{- if not (contains "%" $minAvail) }}
{{- $replicas := int $cfg.replicaCount }}
{{- if ge (int $minAvail) $replicas }}
{{- $errors = append $errors (printf "postgresql-ha.%s.pdb.minAvailable is %s but only %d replica(s) are deployed: that PodDisruptionBudget can never allow a voluntary eviction, so it blocks every node drain. Raise postgresql-ha.%s.replicaCount above %s, lower minAvailable, or set pdb.create=false" $component $minAvail $replicas $component $minAvail) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{/*
Two independent keys must agree or the bundled Postgres never gets storage:
postgresqlHa.persistence.* drives the StorageClass and PVs this chart creates
(templates/postgresql-pv.yaml), while postgresql-ha.persistence.* is what the vendored
chart's volumeClaimTemplates request. A mismatch leaves every PVC Pending with no error
pointing at the cause.
*/}}
{{- $mine := .Values.postgresqlHa.persistence }}
{{- $theirs := (index .Values "postgresql-ha").persistence }}
{{- if ne ($mine.storageClass | toString) ($theirs.storageClass | toString) }}
{{- $errors = append $errors (printf "postgresqlHa.persistence.storageClass is %q but postgresql-ha.persistence.storageClass is %q: the first names the StorageClass and PVs this chart creates, the second is what the bundled StatefulSet's claims ask for. They must match or no PVC ever binds" $mine.storageClass $theirs.storageClass) }}
{{- end }}
{{- if ne ($mine.size | toString) ($theirs.size | toString) }}
{{- $errors = append $errors (printf "postgresqlHa.persistence.size is %q but postgresql-ha.persistence.size is %q: the first sizes the PVs this chart creates, the second is what the bundled claims request. A claim larger than its PV never binds" $mine.size $theirs.size) }}
{{- end }}
{{/*
The chart's own PDB deserves the same scrutiny as the vendored ones. Kubernetes rejects a
PodDisruptionBudget with both minAvailable and maxUnavailable, and a minAvailable equal to
the replica count can never permit a voluntary eviction. templates/pdb.yaml suppresses the
budget below two effective replicas, so only the >= case needs catching here.
*/}}
{{- if .Values.podDisruptionBudget.create }}
{{- if and .Values.podDisruptionBudget.minAvailable .Values.podDisruptionBudget.maxUnavailable }}
{{- $errors = append $errors "podDisruptionBudget.minAvailable and .maxUnavailable are both set: Kubernetes rejects a PodDisruptionBudget carrying both. Set exactly one" }}
{{- end }}
{{- $pdbMin := .Values.podDisruptionBudget.minAvailable | toString }}
{{- if and .Values.podDisruptionBudget.minAvailable (not (contains "%" $pdbMin)) }}
{{- $effective := int (include "common.replicas" (dict "replicaCount" .Values.replicaCount "global" .Values.global)) }}
{{- if and (gt $effective 1) (ge (int $pdbMin) $effective) }}
{{- $errors = append $errors (printf "podDisruptionBudget.minAvailable is %s but only %d replica(s) are deployed: that budget can never allow a voluntary eviction, so it blocks every node drain" $pdbMin $effective) }}
{{- end }}
{{- end }}
{{- end }}
{{- if $errors }}
{{- fail (printf "\nCONDUCTOR VALUES ERROR:\n  - %s\n" (join "\n  - " $errors)) }}
{{- end }}
{{- end -}}
