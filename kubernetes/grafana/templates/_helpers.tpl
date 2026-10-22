{{- define "grafana.adminUser" -}}
{{- $local := tpl .Values.grafanaConfig.auth.username . -}}
{{- $global := tpl (default "" .Values.global.authenUsers.grafana.user) . -}}
{{- default $local $global | required "grafanaConfig.auth.username or global.authenUsers.grafana.user is required" -}}
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

{{- define "grafana.adminEnv" -}}
- name: GF_SECURITY_ADMIN_USER
  value: {{ include "grafana.adminUser" . | quote }}
- name: GF_SECURITY_ADMIN_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "grafana.adminSecretName" . | quote }}
      key: {{ include "grafana.adminSecretKey" . | quote }}
{{- end -}}

{{/* Local auth Secret remains chart-owned even when admin uses an external Secret. */}}
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
