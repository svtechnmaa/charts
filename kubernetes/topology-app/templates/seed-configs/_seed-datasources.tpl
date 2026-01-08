{{- define "seed-datasources" -}}
{
  "Datasource": [
{{- $enabledKeys := list -}}
{{- range $key, $ds := .Values.config.datasources -}}
  {{- if $ds.enabled -}}
    {{- $enabledKeys = append $enabledKeys $key -}}
  {{- end -}}
{{- end -}}

{{- $length := len $enabledKeys -}}

{{- range $i, $key := $enabledKeys -}}
{{- $ds := index $.Values.config.datasources $key }}
    {
      "ID": {{ $ds.id }},
      "ParentID": null,
      "ExternalID": null,
      "Title": "{{ $ds.title }}",
      "Type": "{{ $ds.type }}",
      "Url": "{{ $ds.url }}",
      "Storage": {{ $ds.storage }},
      "Username": "{{ $ds.username }}",
      "Password": "{{ $ds.password }}",
      "Details": null,
      "Schema": "{{ $ds.schema }}",
      "Query": ""
    }{{ if lt (add $i 1) $length }},{{ end }}
{{- end }}
  ]
}
{{- end }}
