{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Icinga2 image name
*/}}
{{- define "icinga2.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{- define "icinga2.init.image" -}}
{{- if .Values.init -}}
{{ include "common.images.image" (dict "imageRoot" .Values.init.image "global" .Values.global) }}
{{- end -}}
{{- end -}}

{{- define "icinga2.sidecar.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.sidecar.image "global" .Values.global) }}
{{- end -}}

{{/*
Liveness check of election.py (bash), shared by the master liveness probes: its reconcile loop
hung (heartbeat too old) -> fail. A dead election.py is handled by the entrypoint watcher.
Skipped until READY_FILE exists: the entrypoint has its own timeout.
*/}}
{{- define "icinga2.master.electionLivenessCheck" -}}
if [[ -f "$ELECTION_READY_FILE" ]]; then
  hb=$(cat "$ELECTION_HEARTBEAT_FILE" 2>/dev/null || echo 0)
  age=$(( $(date +%s) - ${hb%.*} ))
  if (( age > {{ .Values.master.election.livenessProbe.maxHeartbeatAgeSeconds }} )); then
    echo "election heartbeat is ${age}s old"
    exit 1
  fi
fi
{{- end -}}

