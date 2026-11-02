{{/* vim: set filetype=mustache: */}}

{{/* Return the Git HTTP image. */}}
{{- define "git-http.image" -}}
{{ include "common.images.image" (dict "imageRoot" .Values.image "global" .Values.global) }}
{{- end -}}

{{/* Resolve the HTTP Basic Auth username, falling back to the global admin user. */}}
{{- define "git-http.auth.username" -}}
{{- $username := .Values.global.github.user -}}
{{- required "A Git HTTP username is required. Set auth.username or global.adminUser" $username -}}
{{- end -}}

{{/* Resolve the HTTP Basic Auth password, falling back to the global admin password. */}}
{{- define "git-http.auth.password" -}}
{{- $password := .Values.global.github.fg_token -}}
{{- required "A Git HTTP password is required. Set auth.password or global.adminPassword" $password -}}
{{- end -}}
