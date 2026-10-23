# vmware-exporter config
{{- define "vmware-exporter.esx.yml" -}}
{{- if .Values.config }}
{{- /* Defaults can be overridden per section; mergeOverwrite keeps an explicit false. */}}
{{- $defaults := dict "ignore_ssl" true "specs_size" 5000 "fetch_custom_attributes" true "fetch_tags" true "fetch_alarms" true "collect_only" (dict "vms" true "vmguests" true "datastores" true "hosts" true "snapshots" true) "vsphere_user" "" "vsphere_password" "" }}
{{- range $name, $setting := .Values.config }}
{{- /* A null section (e.g. --set config.default=null) is skipped. */}}
{{- if not (kindIs "invalid" $setting) }}
{{ $name }}:
  {{- toYaml (mergeOverwrite (deepCopy $defaults) ($setting | default dict)) | nindent 2 }}
{{- end }}
{{- end }}
{{ end }}
{{- if .Values.extraConfig }}
{{- toYaml .Values.extraConfig }}
{{- end }}
{{- end }}
