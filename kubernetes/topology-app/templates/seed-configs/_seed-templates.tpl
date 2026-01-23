{{- define "seed-templates" -}}
    {
      "Template": [
        {
          "ID": 1,
          "Name": "Default",
          "Order": 0,
          "Payload": '{{ include "payload-templates" . | nindent 8 }}',
          "IsGlobal": false,
          "Default": false
        }
      ]
    }
{{- end -}}