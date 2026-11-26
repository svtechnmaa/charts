{{/*
ServiceAccount used by every pod of the chart. The ServiceAccount template and the
pod specs share this helper so the created name and the referenced name cannot drift.
*/}}
{{- define "alert-history-writer.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- .Values.serviceAccount.name | default (include "common.names.fullname" .) -}}
{{- else -}}
{{- .Values.serviceAccount.name | default "default" -}}
{{- end -}}
{{- end -}}

{{/*
Fail early on a fullname that breaks Kubernetes name limits. The longest derived
name is the CronJob <fullname>-maintenance (CronJob names are limited to 52 characters,
because the controller appends an 11 character suffix to Job names).
*/}}
{{- define "alert-history-writer.validateName" -}}
{{- if gt (len (include "common.names.fullname" .)) 40 -}}
{{- fail "fullname must be <= 40 characters (CronJob <fullname>-maintenance is limited to 52); set fullnameOverride" -}}
{{- end -}}
{{- end -}}

{{/*
Init container that blocks until the database is at the Alembic head revision.
Rendered as one list item (without indentation) for the consumer Deployment.
envFrom and volumeMounts come from the top-level values directly, so overrides reach it.
*/}}
{{- define "alert-history-writer.waitForMigrations" -}}
- name: wait-for-migrations
  image: {{ include "common.images.image" ( dict "imageRoot" .Values.image "global" .Values.global ) }}
  imagePullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" | quote }}
  command:
    - sh
    - -c
    - |
      deadline="${WAIT_FOR_MIGRATIONS_TIMEOUT_SECONDS:-900}"
      heads="$(alembic heads 2>/dev/null | awk '/^[A-Za-z0-9_.-]+( \(|$)/{print $1}' | sort)" || exit 1
      [ -n "$heads" ] || { echo 'cannot resolve alembic head revision' >&2; exit 1; }
      start=$(date +%s)
      while :; do
        out="$(alembic current 2>&1)"; rc=$?
        cur="$(printf '%s\n' "$out" | awk '/^[A-Za-z0-9_.-]+( \(|$)/{print $1}' | sort)"
        [ "$cur" = "$heads" ] && exit 0
        case "$out" in
          *"Can't locate revision"*) echo "database revision is newer than this image: $out" >&2; exit 1;;
        esac
        if [ $(( $(date +%s) - start )) -ge "$deadline" ]; then
          echo "timed out after ${deadline}s; last output: $out" >&2
          exit 1
        fi
        echo "waiting for alembic head [$heads], current [$cur] (rc=$rc)"
        [ "$rc" -ne 0 ] && printf '%s\n' "$out" | tail -n 3
        sleep 5
      done
  env:
    - name: WAIT_FOR_MIGRATIONS_TIMEOUT_SECONDS
      value: {{ .Values.waitForMigrations.timeoutSeconds | quote }}
  {{- with .Values.envFrom }}
  envFrom:
    {{- include "common.tplvalues.render" (dict "value" . "context" $) | nindent 4 }}
  {{- end }}
  {{- with .Values.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  resources:
    {{- toYaml .Values.waitForMigrations.resources | nindent 4 }}
  {{- with .Values.volumeMounts }}
  volumeMounts:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
