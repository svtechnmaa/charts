# pve-exporter config
{{- define "pve-exporter.pve.yml" -}}
{{- if .Values.config }}
{{- range $name, $setting := .Values.config }}
{{ $name }}:
  user: {{ $setting.user }}
  password: {{ $setting.password | quote }}
  verify_ssl: {{ $setting.verify_ssl }}
{{- end }}
{{ end }}
{{- if .Values.extraConfig }}
{{- toYaml .Values.extraConfig }}
{{- end }}
{{- end }}