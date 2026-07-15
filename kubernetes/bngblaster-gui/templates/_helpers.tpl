{{- define "bngblaster-gui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "bngblaster-gui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "bngblaster-gui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bngblaster-gui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
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

{{- define "bngblaster-gui.postgresName" -}}
{{- printf "%s-postgres" (include "bngblaster-gui.fullname" .) | trunc 63 | trimSuffix "-" -}}
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
{{- $basePath := default "/opt/shared" .Values.global.basePath | trimSuffix "/" -}}
{{- printf "%s/%s/%s" $basePath $namespace $hostPath -}}
{{- end -}}
{{- end -}}
