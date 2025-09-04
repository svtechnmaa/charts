{{/*
Return http_proxy
{{ include "http_proxy" ( dict "proxy" .Values.global.http_proxy ) }}
*/}}
{{- define "http_proxy" -}}
{{- $proxy := default "" .proxy -}}
{{- if not (empty $proxy) -}}
{{- printf "%s" $proxy -}}
{{- end -}}
{{- end -}}