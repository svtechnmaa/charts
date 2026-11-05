{{- define "app-adapters.name" -}}
{{- include "common.names.fullname" . -}}
{{- end -}}

{{- define "app-adapters.labels" -}}
{{ include "common.labels.standard" . }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "app-adapters.secretName" -}}
{{- if .auth.existingSecret -}}
{{- tpl .auth.existingSecret .context | required "auth.existingSecret resolved empty" -}}
{{- else -}}
{{- printf "%s-%s-auth" (include "app-adapters.name" .context | trunc 45 | trimSuffix "-") .component -}}
{{- end -}}
{{- end -}}

{{- define "app-adapters.secretKey" -}}
{{- tpl (index .auth.secretKeys .field) .context | required (printf "auth.secretKeys.%s is required" .field) -}}
{{- end -}}

{{- define "app-adapters.containerImage" -}}
{{- $registry := default .image.registry .context.Values.global.imageRegistry -}}
{{- if .image.digest -}}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" .image.digest) -}}
{{- fail "image.digest must be sha256 followed by 64 lowercase hexadecimal characters" -}}
{{- end -}}
{{- printf "%s@%s" (ternary (printf "%s/%s" $registry .image.repository) .image.repository (not (empty $registry))) .image.digest -}}
{{- else -}}
{{- $_ := required "image.tag or image.digest is required; use a published immutable image" .image.tag -}}
{{- include "common.images.image" (dict "imageRoot" .image "global" .context.Values.global) -}}
{{- end -}}
{{- end -}}

{{- define "app-adapters.componentName" -}}
{{- printf "%s-%s" (include "app-adapters.name" .context | trunc 38 | trimSuffix "-") .component -}}
{{- end -}}

{{- define "app-adapters.scheduling" -}}
{{- with .Values.nodeSelector }}
nodeSelector: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}
