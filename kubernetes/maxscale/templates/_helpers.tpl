{{- define "maxscale.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image) }}
{{- end -}}

{{- define "generate_mariadb_string" -}}
{{- $replicaCount := .replicaCount | int -}}
{{- $result := "" -}}
{{- $releaseName := .releaseName -}}

{{- range $i, $ := until $replicaCount }}
  {{- $dbIndex := add $i 1 -}}
  {{- if eq $dbIndex $replicaCount -}}
    {{- printf "db0%d://%s-mariadb-galera-%d.%s-mariadb-galera-headless:3306" $dbIndex $releaseName $i $releaseName -}}
  {{- else -}}
    {{- printf "db0%d://%s-mariadb-galera-%d.%s-mariadb-galera-headless:3306," $dbIndex $releaseName $i $releaseName -}}
  {{- end -}}
{{- end }}

{{- end -}}


{{- define "generate_external_mariadb_string" -}}
{{- $server := .server -}}
{{- join "," $server }}
{{- end -}}

{{/*
Sanitize a router id into a k8s IANA port name:
- lowercase
- any char outside [a-z0-9-] replaced with a hyphen
- truncated to 15 characters
- leading and trailing hyphens trimmed (after truncation, so trunc can't
  leave a dangling '-')
Fails template rendering if the sanitized result is empty (e.g. an id
made only of separators like "___").
*/}}
{{- define "maxscale.portName" -}}
{{- $name := regexReplaceAll "[^a-z0-9-]" (lower .) "-" | trunc 15 | trimAll "-" -}}
{{- if not $name -}}
{{- fail (printf "maxscale: router id %q sanitizes to an empty port name — use characters in [a-z0-9]" .) -}}
{{- end -}}
{{- $name -}}
{{- end -}}

{{/*
Validate .Values.routers:
- router ids must be unique
- sanitized port names (see maxscale.portName) must be unique
Fails template rendering with a clear message when either check fails.
Call once from each resource that ranges over .Values.routers.
*/}}
{{- define "maxscale.assertUniqueRouters" -}}
{{- $ids := dict -}}
{{- $ports := dict -}}
{{- range .Values.routers -}}
  {{- if hasKey $ids .id -}}
    {{- fail (printf "maxscale: duplicate router id %q in .Values.routers" .id) -}}
  {{- end -}}
  {{- $_ := set $ids .id true -}}
  {{- $portName := include "maxscale.portName" .id -}}
  {{- if hasKey $ports $portName -}}
    {{- fail (printf "maxscale: routers %q and %q sanitize to the same port name %q — rename one" (index $ports $portName) .id $portName) -}}
  {{- end -}}
  {{- $_ := set $ports $portName .id -}}
{{- end -}}
{{- end -}}
