{{/* vim: set filetype=mustache: */}}
{{/*
Define admin user credentials with global value fallback
@return quoted string of admin username
*/}}
{{- define "admin.user" -}}
{{- $user := default .Values.grafanaConfig.adminUser .Values.global.adminUser -}}
{{- if not $user -}}
{{- fail "A valid admin username is required. Set either .Values.global.adminUser or .Values.grafanaConfig.adminUser" -}}
{{- end -}}
{{- $user | quote -}}
{{- end -}}

{{- define "admin.password" -}}
{{- $password := default .Values.grafanaConfig.adminPassword .Values.global.adminPassword -}}
{{- if not $password -}}
{{- fail "A valid admin password is required. Set either .Values.global.adminPassword or .Values.grafanaConfig.adminPassword" -}}
{{- end -}}
{{- $password | quote -}}
{{- end -}}
