# pve-exporter config
{{- define "pve-exporter.pve.yml" -}}
{{- if .Values.config }}
{{- range $name, $setting := .Values.config }}
{{- /* A null section (e.g. --set config.default=null) is skipped. */}}
{{- if not (kindIs "invalid" $setting) }}
{{ $name }}:
  user: {{ $setting.user | default "" | quote }}
  password: {{ $setting.password | default "" | quote }}
  {{- /* Unset verify_ssl falls back to the exporter's own default (true); explicit false is kept. */}}
  {{- if hasKey $setting "verify_ssl" }}
  verify_ssl: {{ $setting.verify_ssl }}
  {{- end }}
{{- end }}
{{- end }}
{{ end }}
{{- if .Values.extraConfig }}
{{- toYaml .Values.extraConfig }}
{{- end }}
{{- end }}
