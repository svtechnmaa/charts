{{/*define ENV for icingadb configuration*/}}
{{- define "icinga2-icingadb.conf" }}
- name: ICINGADB_REDIS_HOST
  value: {{ .Values.global.redis.host | default "localhost" | quote }}
- name: ICINGADB_REDIS_PORT
  value: {{ .Values.global.redis.port | default "6379" | quote }}
- name: ICINGADB_DATABASE_HOST
  value: {{ .Values.global.database.icingadb.host | default "mariadb" | quote }}
- name: ICINGADB_DATABASE_PORT
  value: {{ .Values.global.database.icingadb.port | default "3306" | quote }}
- name: ICINGADB_DATABASE_USER
  value: {{ .Values.global.database.icingadb.username | default "icingadb" | quote }}
- name: ICINGADB_DATABASE_PASSWORD
  value: {{ .Values.global.database.icingadb.password | default "juniper@123" | quote }}
- name: ICINGADB_DATABASE_DATABASE
  value: {{ .Values.global.database.icingadb.database | default "icingadb" | quote }}
- name: RETENTION_HISTORY_DAYS
  value: {{ .Values.master.icingadb.env.RETENTION_HISTORY_DAYS | default "30" | quote }}
- name: RETENTION_SLA_DAYS
  value: {{ .Values.master.icingadb.env.RETENTION_SLA_DAYS | default "30" | quote }}
- name: RETENTION_OPTION_ACKNOWLEDGEMENT
  value: {{ .Values.master.icingadb.env.RETENTION_OPTION_ACKNOWLEDGEMENT | default "30" | quote }} 
- name: RETENTION_OPTION_COMMENT
  value: {{ .Values.master.icingadb.env.RETENTION_OPTION_COMMENT | default "30" | quote }}
- name: RETENTION_OPTION_DOWNTIME
  value: {{ .Values.master.icingadb.env.RETENTION_OPTION_DOWNTIME | default "30" | quote }}
- name: RETENTION_OPTION_FLAPPING
  value: {{ .Values.master.icingadb.env.RETENTION_OPTION_FLAPPING | default "30" | quote }}
- name: RETENTION_OPTION_NOTIFICATION
  value: {{ .Values.master.icingadb.env.RETENTION_OPTION_NOTIFICATION | default "30" | quote }}
- name: RETENTION_OPTION_STATE
  value: {{ .Values.master.icingadb.env.RETENTION_OPTION_STATE | default "30" | quote }}
{{- end }}