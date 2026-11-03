{{- define "grafana.adminUser" -}}
{{- $local := tpl .Values.grafanaConfig.auth.username . -}}
{{- $global := tpl (default "" .Values.global.authenUsers.grafana.user) . -}}
{{- $legacy := tpl (default "" .Values.global.adminUser | toString) . -}}
{{- default (default $local $legacy) $global | required "grafanaConfig.auth.username or global.authenUsers.grafana.user is required" -}}
{{- end -}}

{{- define "grafana.adminSecretName" -}}
{{- if .Values.grafanaConfig.auth.existingSecret -}}
{{- tpl .Values.grafanaConfig.auth.existingSecret . | required "grafanaConfig.auth.existingSecret resolved empty" -}}
{{- else -}}
{{- printf "%s-admin" (include "common.names.fullname" . | trunc 57 | trimSuffix "-") -}}
{{- end -}}
{{- end -}}

{{- define "grafana.adminSecretKey" -}}
{{- tpl .Values.grafanaConfig.auth.existingSecretPasswordKey . | required "grafanaConfig.auth.existingSecretPasswordKey is required" -}}
{{- end -}}

{{/* Chart-managed credentials, including Git/CD keys, always use this Secret. */}}
{{- define "grafana.managedAuthSecretName" -}}
{{- printf "%s-admin" (include "common.names.fullname" . | trunc 57 | trimSuffix "-") -}}
{{- end -}}

{{- define "grafana.databaseSecretName" -}}
{{- if .Values.grafanaConfig.database.auth.existingSecret -}}
{{- tpl .Values.grafanaConfig.database.auth.existingSecret . | required "grafanaConfig.database.auth.existingSecret resolved empty" -}}
{{- else -}}
{{- include "grafana.managedAuthSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "grafana.databaseSecretKey" -}}
{{- tpl .Values.grafanaConfig.database.auth.existingSecretPasswordKey . | required "grafanaConfig.database.auth.existingSecretPasswordKey is required" -}}
{{- end -}}

{{/*
Build a stable environment variable name for datasource secure fields.
*/}}
{{- define "grafana.datasourceEnvName" -}}
{{- $name := regexReplaceAll "[^A-Z0-9_]" ((index . 0) | upper) "_" -}}
{{- $field := regexReplaceAll "[^A-Z0-9_]" ((index . 1) | upper) "_" -}}
{{- printf "GF_DS_%s_%s" $name $field -}}
{{- end -}}
