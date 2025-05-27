{{/* vim: set filetype=mustache: */}}

{{/*
Return the proper Debuger image name
*/}}
{{- define "initRepo.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.initRepo.image "global" .Values.global) }}
{{- end -}}