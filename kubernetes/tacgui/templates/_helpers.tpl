{{/* Return the proper Tacgui image name */}}
{{- define "tacgui.image" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/* Return the proper image name (for the init container volume-permissions image) */}}
{{- define "tacgui.volumePermissions.image" -}}
  {{ include "common.images.image" (dict "imageRoot" .Values.volumePermissions.image "global" .Values.global) }}
{{- end -}}

{{/* Return the proper Docker Image Registry Secret Names */}}
{{- define "tacgui.imagePullSecrets" -}}
  {{- include "common.images.pullSecrets" (dict "images" (list .Values.image .Values.volumePermissions.image .Values.metrics.image) "global" .Values.global) -}}
{{- end -}}

{{/* Get the configuration ConfigMap name. */}}
{{- define "tacgui.configurationCM" -}}
{{- if .Values.configurationConfigMap -}}
  {{- printf "%s" (tpl .Values.configurationConfigMap $) -}}
{{- else -}}
  {{- printf "%s-configuration" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Get the initialization scripts ConfigMap name. */}}
{{- define "tacgui.initdbScriptsCM" -}}
{{- if .Values.initdbScriptsConfigMap -}}
  {{- printf "%s" .Values.initdbScriptsConfigMap -}}
{{- else -}}
  {{- printf "%s-init-scripts" (include "common.names.fullname" .) -}}
{{- end -}}
{{- end -}}

{{/* Return the Tacgui PVC name. */}}
{{- define "tacgui.claimName" -}}
{{- if .Values.persistence.existingClaim }}
  {{- printf "%s" (tpl .Values.persistence.existingClaim $) -}}
{{- else }}
  {{- printf "%s" (include "common.names.fullname" .) -}}
{{- end }}
{{- end -}}

{{- define "tacgui.dockercfgjson" }}
{{- with .Values.image }}
{{- printf "{\"auths\":{\"https://ghcr.io\":{\"auth\":\"%s\"}}}" (printf "%s:%s" .pullAccount .pullPassword | b64enc) | b64enc }}
{{- end }}
{{- end }}
