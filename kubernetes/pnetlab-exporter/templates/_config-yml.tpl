{{- define "joinList" }}
  {{- $list := list }}
  {{- range .arr }}
    {{- $list = append $list .host }}
  {{- end }}
  {{- join "," $list }}
{{- end }}

# pnetlab-exporter config
{{- define "pnetlab-exporter.config.yaml" -}}
databases:
{{- if .Values.extraConfig.databases }}
{{- range .Values.extraConfig.databases }}
  {{ .host }}:
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

{{- /* "queries.interval" is kept as a fallback for older values files. */}}
{{- $queries := .Values.extraConfig.queries | default dict }}
{{- $interval := .Values.extraConfig.queryInterval | default $queries.interval | default 60 }}
queries:
  query1:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_running]
    sql: SELECT a.node_session_running as node_running  , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  query2:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_cpu]
    sql: SELECT a.node_session_cpu as node_cpu , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  query3:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_memory]
    sql: SELECT a.node_session_ram as node_memory , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  query4:
    interval: {{ $interval }}
    databases: [{{ default "default" (include "joinList" (dict "arr" .Values.extraConfig.databases)) }}]
    metrics: [node_used_space]
    sql: SELECT a.node_session_hdd as node_used_space , b.lab_session_path as lab_path, a.node_session_port as node_port, a.node_session_lab as lab_id, a.node_session_nid as node_id from node_sessions as a inner join lab_sessions as b on a.node_session_lab = b.lab_session_id
  {{- with (omit $queries "interval") }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}