# network-exporter config
{{- define "network-exporter.network-exporter.yml" -}}
{{- if .Values.config.conf }}
conf:
{{- toYaml .Values.config.conf | nindent 2 }}
{{- end }}

{{- if .Values.config.protocols }}
{{ range $protocol, $settings := .Values.config.protocols }}
{{ $protocol }}:
{{ $settings | toYaml | indent 2 }}
{{ end -}}
{{- end }}

{{- if .Values.config.targets }}
targets:
{{ .Values.config.targets | toYaml | indent 2 }}
{{- end }}

{{- end }}