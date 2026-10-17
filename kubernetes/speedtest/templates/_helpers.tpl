{{/* Return the chart-managed or externally supplied shared authentication Secret. */}}
{{- define "speedtest.authSecretName" -}}
{{- include "common.secrets.name" (dict "existingSecret" .Values.auth.existingSecret "defaultNameSuffix" "auth" "context" .) -}}
{{- end -}}

{{/* Database variables use explicit refs so auth.existingSecret.keyMapping is honored. */}}
{{- define "speedtest.databaseEnv" -}}
- name: DB_NAME
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DB_NAME") }}
- name: DB_USER
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DB_USER") }}
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DB_PASSWORD") }}
- name: DB_HOST
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DB_HOST") }}
- name: DB_PORT
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DB_PORT") }}
{{- end -}}

{{- define "speedtest.mqttAuthEnv" -}}
- name: MQTT_BROKER_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "MQTT_BROKER_USERNAME") }}
- name: MQTT_BROKER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "MQTT_BROKER_PASSWORD") }}
{{- end -}}

{{- define "speedtest.djangoAuthEnv" -}}
- name: DJANGO_SUPERUSER_USERNAME
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DJANGO_SUPERUSER_USERNAME") }}
- name: DJANGO_SUPERUSER_EMAIL
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DJANGO_SUPERUSER_EMAIL") }}
- name: DJANGO_SUPERUSER_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.authSecretName" . }}
      key: {{ include "common.secrets.key" (dict "existingSecret" .Values.auth.existingSecret "key" "DJANGO_SUPERUSER_PASSWORD") }}
{{- end -}}
