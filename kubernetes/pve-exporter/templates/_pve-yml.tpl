# pve-exporter config
{{- define "pve-exporter.pve.yml" -}}
{{- if .Values.config }}
{{- range $name, $setting := .Values.config }}
{{ $name }}:
  user: {{ $setting.user | default "" | quote }}
  password: {{ $setting.password | default "" | quote }}
  verify_ssl: {{ $setting.verify_ssl }}
{{- end }}
{{ end }}
{{- if .Values.extraConfig }}
{{- toYaml .Values.extraConfig }}
{{- end }}
{{- end }}