# vmware-exporter config
{{- define "vmware-exporter.esx.yml" -}}
{{- if .Values.config }}
{{- range $name, $setting := .Values.config }}
{{ $name }}:
  vsphere_user: {{ $setting.vsphere_user }}
  vsphere_password: {{ $setting.vsphere_password }}
  ignore_ssl: true
  specs_size: 5000
  fetch_custom_attributes: true
  fetch_tags: true
  fetch_alarms: true
  collect_only:
      vms: true
      vmguests: true
      datastores: true
      hosts: true
      snapshots: true
{{- end }}
{{ end }}
{{- if .Values.extraConfig }}
{{- toYaml .Values.extraConfig }}
{{- end }}
{{- end }}