{{/* Wait until the shared Netforge repository has been initialized. */}}
{{- define "netforge-be.repoWaitInitContainer" -}}
- name: wait-for-repo
  image: {{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
  imagePullPolicy: {{ .Values.image.pullPolicy | quote }}
  command:
    - /bin/sh
    - -ec
    - |
      until [ -d "$REPO_PATH/.git" ] && [ -f "$REPO_PATH/completed" ]; do
        echo "Waiting for the Netforge repository to be initialized at $REPO_PATH..."
        sleep 2
      done
      echo "Netforge repository is ready"
  env:
    - name: REPO_PATH
      value: /opt/netforge
  {{- if and .Values.global.sharedPersistenceVolume .Values.global.sharedVolume.enabled }}
  volumeMounts:
    {{- range .Values.global.sharedPersistenceVolume }}
    {{- if has $.Chart.Name .shareFor }}
    - name: {{ .volumeName }}
      mountPath: {{ .path }}
    {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
