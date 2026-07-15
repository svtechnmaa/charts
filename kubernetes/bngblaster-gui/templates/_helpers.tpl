{{- define "bngblaster-gui.fullname" -}}
{{- include "common.names.fullname" . -}}
{{- end -}}

{{- define "bngblaster-gui.labels" -}}
{{ include "common.labels.standard" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
{{- end -}}

{{- define "bngblaster-gui.selectorLabels" -}}
{{ include "common.labels.matchLabels" . }}
{{- end -}}

{{- define "bngblaster-gui.image" -}}
{{- $repository := required (printf "%s.image.repository is required" .component) .image.repository -}}
{{- $tag := required (printf "%s.image.tag is required" .component) .image.tag -}}
{{- $global := default dict .root.Values.global -}}
{{- if $global.imageRegistry -}}
{{- printf "%s/%s:%s" ($global.imageRegistry | trimSuffix "/") $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.backendName" -}}
{{- printf "%s-backend" (include "bngblaster-gui.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.frontendName" -}}
{{- printf "%s-frontend" (include "bngblaster-gui.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.databaseHost" -}}
{{- $externalPostgresql := default dict (index .Values "externalPostgresql") -}}
{{- $host := index $externalPostgresql "host" -}}
{{- required "externalPostgresql.host is required" $host -}}
{{- end -}}

{{- define "bngblaster-gui.namespace" -}}
{{- $namespace := index .Values "namespace" -}}
{{- if and $namespace (index $namespace "name") -}}
{{- index $namespace "name" -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.ingressPath" -}}
{{- $path := default "/" .Values.ingress.path -}}
{{- $normalized := trimSuffix "/" (printf "/%s" (trimPrefix "/" $path)) -}}
{{- if eq $normalized "" -}}
/
{{- else -}}
{{- $normalized -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.backendDataHostPath" -}}
{{- $namespace := include "bngblaster-gui.namespace" . -}}
{{- $hostPath := .Values.backend.dataPersistence.hostPath -}}
{{- if hasPrefix "/" $hostPath -}}
{{- $hostPath -}}
{{- else -}}
{{- $global := default dict .Values.global -}}
{{- $basePath := default "/opt/shared" $global.basePath | trimSuffix "/" -}}
{{- printf "%s/%s/%s" $basePath $namespace $hostPath -}}
{{- end -}}
{{- end -}}
