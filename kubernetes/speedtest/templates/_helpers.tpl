{{/* Credential references are independent: a Pod can consume several Secrets. */}}
{{- define "speedtest.credentialSecretName" -}}
{{- $config := (index .context.Values .group).auth -}}
{{- if and $config.existingSecret (not (kindIs "string" $config.existingSecret)) -}}
{{- if not (kindIs "map" $config.existingSecret) -}}
{{- fail (printf "%s.auth.existingSecret must be a name or an object with name/keyMapping" .group) -}}
{{- end -}}
{{- $_ := required (printf "%s.auth.existingSecret.name is required" .group) $config.existingSecret.name -}}
{{- end -}}
{{- if $config.existingSecret -}}
{{- include "common.tplvalues.render" (dict "value" (include "common.secrets.name" (dict "existingSecret" $config.existingSecret "context" .context)) "context" .context) | required (printf "%s.auth.existingSecret resolved to an empty name" .group) -}}
{{- else -}}
{{- include "speedtest.resourceName" (dict "suffix" .group "context" .context) -}}
{{- end -}}
{{- end -}}

{{- define "speedtest.credentialSecretKey" -}}
{{- $config := (index .context.Values .group).auth -}}
{{- $key := required (printf "%s.auth.existingSecretPasswordKey must not be empty" .group) $config.existingSecretPasswordKey -}}
{{- if kindIs "map" $config.existingSecret -}}
{{- $key = default $key (index (default dict $config.existingSecret.keyMapping) $key) -}}
{{- end -}}
{{- tpl $key .context -}}
{{- end -}}

{{- define "speedtest.passwordEnv" -}}
- name: {{ .env }}
  valueFrom:
    secretKeyRef:
      name: {{ include "speedtest.credentialSecretName" . | quote }}
      key: {{ include "speedtest.credentialSecretKey" . | quote }}
{{- end -}}

{{- define "speedtest.databaseEnv" -}}
- name: DB_NAME
  value: {{ tpl .Values.db.name . | required "db.name is required" | quote }}
- name: DB_USER
  value: {{ tpl .Values.db.auth.username . | required "db.auth.username is required" | quote }}
- name: DB_HOST
  value: {{ tpl .Values.db.host . | required "db.host is required" | quote }}
- name: DB_PORT
  value: {{ .Values.db.port | quote }}
{{ include "speedtest.passwordEnv" (dict "group" "db" "env" "DB_PASSWORD" "context" .) }}
{{- end -}}

{{- define "speedtest.mqttAuthEnv" -}}
- name: MQTT_BROKER_USERNAME
  value: {{ tpl .Values.mqtt.auth.username . | required "mqtt.auth.username is required" | quote }}
{{ include "speedtest.passwordEnv" (dict "group" "mqtt" "env" "MQTT_BROKER_PASSWORD" "context" .) }}
{{- end -}}

{{- define "speedtest.djangoAuthEnv" -}}
- name: DJANGO_SUPERUSER_USERNAME
  value: {{ tpl .Values.django.auth.username . | required "django.auth.username is required when runInitDataJob is enabled" | quote }}
- name: DJANGO_SUPERUSER_EMAIL
  value: {{ tpl .Values.django.superUserEmail . | required "django.superUserEmail is required when runInitDataJob is enabled" | quote }}
{{ include "speedtest.passwordEnv" (dict "group" "django" "env" "DJANGO_SUPERUSER_PASSWORD" "context" .) }}
{{- end -}}

{{/* Reserve suffix space and avoid collisions when long release names are truncated. */}}
{{- define "speedtest.resourceName" -}}
{{- $fullname := include "common.names.fullname" .context -}}
{{- $limit := int (sub 51 (len .suffix)) -}}
{{- $prefix := $fullname -}}
{{- if gt (len $fullname) $limit -}}
{{- $prefix = printf "%s-%s" ($fullname | trunc (int (sub $limit 7)) | trimSuffix "-") ($fullname | sha256sum | trunc 6) -}}
{{- end -}}
{{- printf "%s-%s" $prefix .suffix -}}
{{- end -}}

{{- define "speedtest.pvcName" -}}
{{- $config := index .context.Values.pvc .group -}}
{{- default (include "speedtest.resourceName" (dict "suffix" (printf "%s-pvc" (.group | kebabcase)) "context" .context)) $config.claimName -}}
{{- end -}}

{{- define "speedtest.migrationMarker" -}}
{{- printf "/migration-state/.speedtest/%s/r%d/ready" .Release.Name .Release.Revision -}}
{{- end -}}

{{- define "speedtest.migrationWait" -}}
- name: wait-for-migration
  image: {{ include "common.images.image" (dict "imageRoot" .Values.image.initWaitDb "global" .Values.global) }}
  imagePullPolicy: {{ .Values.imagePullPolicy | quote }}
  command: ["/bin/sh", "-ec"]
  args:
    - |
      remaining={{ .Values.migration.waitTimeoutSeconds }}
      until [ -f {{ include "speedtest.migrationMarker" . | quote }} ]; do
        if [ "$remaining" -le 0 ]; then echo "Migration Job did not complete before timeout" >&2; exit 1; fi
        echo "Waiting for release migration Job..."
        sleep 2
        remaining=$((remaining - 2))
      done
  volumeMounts:
    - name: {{ default "migration-state" .migrationVolumeName }}
      mountPath: /migration-state
      readOnly: true
{{- end -}}

{{- define "speedtest.migrationVolume" -}}
- name: migration-state
  persistentVolumeClaim:
    claimName: {{ include "speedtest.pvcName" (dict "group" "static" "context" .) }}
{{- end -}}
