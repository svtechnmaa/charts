{{- define "seed-menu-items" -}}
{
  "MenuItem": [
    {
      "ID": 1,
      "Title": "Dashboard",
      "Permalink": "",
      "Href": "/app",
      "Order": 0,
      "Username": null,
      "Password": null,
      "ExternalTab": false,
      "Hidden": false,
      "Override": null
    },
    {
      "ID": 2,
      "Title": "Visualizer",
      "Permalink": "",
      "Href": "/app/visualizer",
      "Order": 1,
      "Username": null,
      "Password": null,
      "ExternalTab": false,
      "Hidden": false,
      "Override": null
    },
    {{- $enabledKeys := list -}}
    {{- range $key, $ds := .Values.config.menuItems -}}
      {{- if $ds.enabled -}}
        {{- $enabledKeys = append $enabledKeys $key -}}
      {{- end -}}
    {{- end -}}

    {{- $length := len $enabledKeys -}}

    {{- range $i, $key := $enabledKeys -}}
    {{- $ds := index $.Values.config.menuItems $key }}
    {
      "ID": {{ $ds.id }},
      "Title": "{{ $ds.title }}",
      "Permalink": "{{ $ds.permalink }}",
      "Href": "{{ $ds.href }}",
      "Order": {{ $ds.order }},
      "Username": "{{ $ds.username }}",
      "Password": "{{ $ds.password }}",
      "ExternalTab": false,
      "Hidden": false,
      "Override": null
    }{{ if lt (add $i 1) $length }},{{ end }}
    {{- end }}
  ]
}
{{- end -}}