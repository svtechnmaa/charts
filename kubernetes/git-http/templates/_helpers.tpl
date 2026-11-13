{{/* vim: set filetype=mustache: */}}

{{/* Return the Git HTTP image. */}}
{{- define "git-http.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/* git-http owns the credential unless an external producer is selected. */}}
{{- define "git-http.auth.secretName" -}}
{{- default (printf "%s-auth" .Chart.Name) .Values.auth.existingSecret -}}
{{- end -}}

{{- define "git-http.auth.username" -}}
{{- $username := .Values.global.github.user -}}
{{- required "A Git HTTP username is required. Set global.github.user" $username -}}
{{- end -}}

{{- define "git-http.auth.password" -}}
{{- $password := .Values.global.github.fg_token -}}
{{- required "A Git HTTP password is required. Set global.github.fg_token" $password -}}
{{- end -}}
