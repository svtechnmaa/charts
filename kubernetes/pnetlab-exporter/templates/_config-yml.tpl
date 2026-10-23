{{- /* Key of one database entry: explicit "name", else <host>-<dbname>. Used both as the
databases map key and in each query's "databases" list so the two always match. */}}
{{- define "pnetlab-exporter.dbKey" -}}
{{- .name | default (printf "%s-%s" .host (.dbname | default "pnetlab_db")) -}}
{{- end }}

{{- /* Comma-separated, quoted keys of all entries; fails on duplicate keys. */}}
{{- define "pnetlab-exporter.joinList" }}
  {{- $list := list }}
  {{- $seen := dict }}
  {{- range .arr }}
    {{- $key := include "pnetlab-exporter.dbKey" . }}
    {{- if hasKey $seen $key }}
      {{- fail (printf "extraConfig.databases: duplicate database key %q; set a unique 'name' on one of the entries" $key) }}
    {{- end }}
    {{- $_ := set $seen $key true }}
    {{- $list = append $list ($key | quote) }}
  {{- end }}
  {{- join "," $list }}
{{- end }}

# pnetlab-exporter config
{{- define "pnetlab-exporter.config.yaml" -}}
databases:
{{- if .Values.extraConfig.databases }}
{{- range .Values.extraConfig.databases }}
  {{ include "pnetlab-exporter.dbKey" . | quote }}:
    dsn:
      dialect: mysql
      user: {{ .user | default "" | quote }}
      password: {{ .password | default "" | quote }}
      host: {{ .host }}
      port: {{ .port | default 3306 }}
      database: {{ .dbname | default "pnetlab_db" }}
{{- end }}
{{- else }}
  default:
    dsn:
      dialect: mysql
      user: ""
      password: ""
      host: localhost
      port: 3306
      database: pnetlab_db
{{- end }}
metrics:
  node_cpu:
    type: gauge
    description: CPU usage of nodes in lab
    labels:
      - node_port
      - node_id
      - lab_id
      - lab_path
  node_memory:
    type: gauge
    description: Memory usage of nodes in lab
    labels:
      - node_port
      - node_id
      - lab_id
      - lab_path
  node_used_space:
    type: gauge
    description: Used space of nodes in lab
    labels:
      - node_port
      - node_id
      - lab_id
      - lab_path
  node_running:
    type: gauge
    description: Running state of nodes in lab
    labels:
      - node_port
      - node_id
      - lab_id
      - lab_path
  {{- with .Values.extraConfig.metrics }}
  {{- toYaml . | nindent 2 }}
  {{- end }}

{{- $interval := .Values.extraConfig.queryInterval | default 60 }}
queries:
  query1:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "pnetlab-exporter.joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_running]
    sql: SELECT a.node_session_running as node_running  , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  query2:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "pnetlab-exporter.joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_cpu]
    sql: SELECT a.node_session_cpu as node_cpu , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  query3:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "pnetlab-exporter.joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_memory]
    sql: SELECT a.node_session_ram as node_memory , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  query4:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "pnetlab-exporter.joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_used_space]
    sql: SELECT a.node_session_hdd as node_used_space , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  {{- with .Values.extraConfig.queries }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}