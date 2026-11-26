{{- define "emqx.mqttSecretName" -}}
{{- $ref := .Values.mqtt.auth.existingSecret -}}
{{- if kindIs "map" $ref -}}
{{- $_ := required "mqtt.existingSecret.name is required" $ref.name -}}
{{- end -}}
{{- include "common.tplvalues.render" (dict "value" (include "common.secrets.name" (dict "existingSecret" $ref "defaultNameSuffix" "mqtt" "context" .)) "context" .) -}}
{{- end -}}

{{- define "emqx.mqttSecretKey" -}}
{{- $key := required "mqtt.existingSecretPasswordKey is required" .Values.mqtt.auth.existingSecretPasswordKey -}}
{{- if kindIs "map" .Values.mqtt.auth.existingSecret -}}
{{- $key = default $key (index (default dict .Values.mqtt.auth.existingSecret.keyMapping) $key) -}}
{{- end -}}
{{- tpl $key . -}}
{{- end -}}

{{/* This block is merged into both core and replicant Pod specs. */}}
{{- define "emqx.mqttBootstrapSpec" -}}
extraVolumes:
  - name: mqtt-bootstrap
    emptyDir:
      medium: Memory
extraVolumeMounts:
  - name: mqtt-bootstrap
    mountPath: /opt/emqx/mqtt-bootstrap
    readOnly: true
initContainers:
  - name: mqtt-bootstrap
    image: {{ include "common.images.image" (dict "imageRoot" .Values.mqtt.bootstrapImage "global" .Values.global) }}
    imagePullPolicy: {{ .Values.mqtt.bootstrapImage.pullPolicy }}
    command: ["/bin/sh", "-ec"]
    args:
      - |
        umask 077
        awk '
        function json_escape(value, result, i, char) {
          result = "";
          for (i = 1; i <= length(value); i++) {
            char = substr(value, i, 1);
            if (char == "\\") result = result "\\\\";
            else if (char == "\"") result = result "\\\"";
            else if (char in controls) result = result controls[char];
            else result = result char;
          }
          return result;
        }
        BEGIN {
          for (i = 1; i < 32; i++) controls[sprintf("%c", i)] = sprintf("\\u%04x", i);
          user = ENVIRON["MQTT_USERNAME"]; password = ENVIRON["MQTT_PASSWORD"];
          if (user == "" || password == "") { print "MQTT username/password must not be empty" > "/dev/stderr"; exit 1 }
          printf "[{\"user_id\":\"%s\",\"password\":\"%s\",\"is_superuser\":false}]\n", json_escape(user), json_escape(password);
        }' > /bootstrap/users.json
    env:
      - name: MQTT_USERNAME
        value: {{ tpl .Values.mqtt.auth.username . | required "mqtt.auth.username is required" | quote }}
      - name: MQTT_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{ include "emqx.mqttSecretName" . | quote }}
            key: {{ include "emqx.mqttSecretKey" . | quote }}
    volumeMounts:
      - name: mqtt-bootstrap
        mountPath: /bootstrap
{{- end -}}

{{- define "emqx.replicantTemplate" -}}
{{- $template := include "common.tplvalues.render" (dict "value" .Values.replicantTemplate "context" .) | fromYaml -}}
{{- if .Values.mqtt.enabled -}}
{{- $spec := default dict $template.spec -}}
{{- $bootstrap := include "emqx.mqttBootstrapSpec" . | fromYaml -}}
{{- range $key := list "extraVolumes" "extraVolumeMounts" "initContainers" -}}
{{- $_ := set $spec $key (concat (index $bootstrap $key) (default list (index $spec $key))) -}}
{{- end -}}
{{- $_ := set $template "spec" $spec -}}
{{- end -}}
{{- toYaml $template -}}
{{- end -}}
