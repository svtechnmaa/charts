{{- define "seed-states" -}}
{
  "State": [
    {
      "ID": 1,
      "Name": "Ok",
      "Order": 0,
      "Payload": '{{ include "payload-ok" . | nindent 8 }}',
      "IsAbnormal": false
    },
    {
      "ID": 2,
      "Name": "Warning",
      "Order": 0,
      "Payload": '{{ include "payload-warning" . | nindent 8 }}',
      "IsAbnormal": false
    },
    {
      "ID": 3,
      "Name": "Critical",
      "Order": 0,
      "Payload": '{{ include "payload-critical" . | nindent 8 }}',
      "IsAbnormal": false
    },
    {
      "ID": 4,
      "Name": "Down",
      "Order": 0,
      "Payload": '{{ include "payload-down" . | nindent 8 }}',
      "IsAbnormal": false
    },
    {
      "ID": 5,
      "Name": "Unknown",
      "Order": 0,
      "Payload": '{{ include "payload-unknown" . | nindent 8 }}',
      "IsAbnormal": false
    }
  ]
}
{{- end -}}