{{/*
Expand the name of the chart.
*/}}
{{- define "new_FE.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "new_FE.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "new_FE.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "new_FE.labels" -}}
helm.sh/chart: {{ include "new_FE.chart" . }}
{{ include "new_FE.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "new_FE.selectorLabels" -}}
app.kubernetes.io/name: {{ include "new_FE.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "new_FE.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "new_FE.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}



{{ define "go_backend_image" -}}
{{ printf "%s:%s" .Values.go_backend.deployment.image.repository .Values.go_backend.deployment.image.tag }}
{{- end }}


{{ define "topology_frontend_image" -}}
{{ printf "%s:%s" .Values.topology_frontend.deployment.image.repository .Values.topology_frontend.deployment.image.tag }}
{{- end }}


{{ define "traefik_image" -}}
{{ printf "%s:%s" .Values.traefik.deployment.image.repository .Values.traefik.deployment.image.tag }}
{{- end }}


{{ define "redis_image" -}}
{{ printf "%s:%s" .Values.redis.deployment.image.repository .Values.redis.deployment.image.tag }}
{{- end }}


{{ define "mysql_image" -}}
{{ printf "%s:%s" .Values.mysql.deployment.image.repository .Values.mysql.deployment.image.tag }}
{{- end }}