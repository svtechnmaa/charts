{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Debuger image name
*/}}
{{- define "initRepo.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/*
Return http_proxy
{{ include "http_proxy" ( dict "proxy" .Values.global.http_proxy ) }}
*/}}
{{- define "http_proxy" -}}
{{- $proxy := default "" .proxy -}}
{{- if not (empty $proxy) -}}
{{- printf "http://%s:3128" $proxy -}}
{{- end -}}
{{- end -}}