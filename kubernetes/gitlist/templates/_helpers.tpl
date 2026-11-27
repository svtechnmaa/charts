{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Gitlist image name
*/}}
{{- define "gitlist.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}


