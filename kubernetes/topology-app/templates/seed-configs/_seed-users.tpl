{{- define "seed-users" -}}
User:
{{- range $index, $user := .Values.config.users }}
  - ID: {{ $user.id }}
    Name: {{ $user.username }}
    Email: {{ $user.email }}
    Password: {{ $user.password }}
    Groups:
    {{- range $groupIndex, $groupID := $user.groups }}
      - ID: {{ $groupID.ID }}
    {{- end }}
{{- end }}
{{- end -}}