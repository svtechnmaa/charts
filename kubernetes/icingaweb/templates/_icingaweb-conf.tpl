---
{{/* Icingaweb ENV defination */}}
{{- define "icingaweb.conf" -}}
{{/* Icingaweb authentication */}}
- name: icingaweb.authentication.icingaweb2.backend
  value: {{ .Values.auth.type | quote }}
- name: icingaweb.authentication.icingaweb2.resource
  value: {{ .Values.auth.resource | default .Values.global.database.icingaweb2.database | quote }}
- name: icingaweb.passwords.icingaweb2.{{ .Values.auth.admin_user }}
  value: {{ .Values.auth.admin_password | default "juniper@123" | quote }}
- name: icingaweb.config.global.config_resource
  value: {{ .Values.auth.resource | default .Values.global.database.icingaweb2.database | quote }}
- name: icingaweb.groups.icingaweb2.backend
  value: {{ .Values.auth.type | quote }}
- name: icingaweb.groups.icingaweb2.resource
  value: {{ .Values.auth.resource | default .Values.global.database.icingaweb2.database | quote }}
- name: icingaweb.roles.Administrators.users
  value: {{ .Values.auth.admin_user | quote }}
- name: icingaweb.roles.Administrators.permissions
  value: "*"
- name: icingaweb.roles.Administrators.groups
  value: Administrators
- name: icingaweb.roles.Views.groups
  value: Views
- name: icingaweb.roles.Views.permissions
  value: "application/announcements,user/share/navigation,module/grafana,grafana/graph,grafana/showall,user/password-change,icingadb/*,module/icingadb"
{{/* Director module */}}
{{- if .Values.modules.director.enabled }}
- name: icingaweb.modules.director.config.db.resource
  value: {{ .Values.global.database.director.database | quote }}
- name: icingaweb.modules.director.kickstart.config.endpoint
  value: master-0
- name: icingaweb.modules.director.kickstart.config.host
  value: {{ .Release.Name }}-icinga2-master-0.icinga2-headless.{{ .Release.Namespace }}.svc.{{ .Values.clusterDomain }}
- name: icingaweb.modules.director.kickstart.config.username
  value: {{ .Values.global.api.user | default "icingaAdmin" | quote }}
- name: icingaweb.modules.director.kickstart.config.password
  value: {{ .Values.global.api.password | default "icingaAdmin" | quote }}
{{- end }}
{{/* Icingadb module */}}
{{- if .Values.modules.icingadb.enabled }}
- name: icingaweb.modules.icingadb.config.icingadb.resource
  value: {{ .Values.global.database.icingadb.database | quote }}
- name: icingaweb.modules.icingadb.redis.redis1.host
  value: {{ .Values.global.redis.host | default (printf "icinga2.%s.svc.%s" .Release.Namespace .Values.clusterDomain) | quote }}
- name: icingaweb.modules.icingadb.redis.redis1.port
  value: {{ .Values.global.redis.port | default "6379" | quote }}
- name: icingaweb.modules.icingadb.commandtransports.icinga2.transport
  value: api
- name: icingaweb.modules.icingadb.commandtransports.icinga2.skip_validation
  value: "0"
- name: icingaweb.modules.icingadb.commandtransports.icinga2.host
  value: {{ .Values.global.api.host | default (printf "icinga2.%s.svc.%s" .Release.Namespace .Values.clusterDomain) | quote }}
- name: icingaweb.modules.icingadb.commandtransports.icinga2.port
  value: {{ .Values.global.api.port | default 5665 | quote }}
- name: icingaweb.modules.icingadb.commandtransports.icinga2.username
  value: {{ .Values.global.api.user | default "icingaAdmin" | quote }}
- name: icingaweb.modules.icingadb.commandtransports.icinga2.password
  value:  {{ .Values.global.api.password | default "icingaAdmin" | quote }}
{{- end }}
{{/* grafana module */}}
{{- if .Values.modules.grafana.enabled }}
- name: icingaweb.modules.grafana.config.grafana.host
  value: {{ printf "%s/grafana" .Values.global.frontendVip | quote }}
- name: icingaweb.modules.grafana.config.grafana.protocol
  value: "https"
- name: icingaweb.modules.grafana.config.grafana.timerangeAll
  value: "1w/w"
- name: icingaweb.modules.grafana.config.grafana.defaultdashboard
  value: {{ .Values.modules.grafana.default_dashboard | default "Service Detail" | quote }}
- name: icingaweb.modules.grafana.config.grafana.defaultdashboarduid
  value: {{ .Values.modules.grafana.default_dashboard_uid | default "service-detail" | quote }}
- name: icingaweb.modules.grafana.config.grafana.defaultdashboardpanelid
  value: {{ .Values.modules.grafana.default_dashboard_panelid | default "2" | quote }}
- name: icingaweb.modules.grafana.config.grafana.defaultorgid
  value: "1"
- name: icingaweb.modules.grafana.config.grafana.shadows
  value: "0"
- name: icingaweb.modules.grafana.config.grafana.theme
  value: "light"
- name: icingaweb.modules.grafana.config.grafana.datasource
  value: "influxdb"
- name: icingaweb.modules.grafana.config.grafana.accessmode
  value: "iframe"
- name: icingaweb.modules.grafana.config.grafana.debug
  value: "0"
- name: icingaweb.modules.grafana.graphs.hostalive.dashboard
  value: "icinga2-hostalive"
- name: icingaweb.modules.grafana.graphs.hostalive.panelId
  value: "1"
- name: icingaweb.modules.grafana.graphs.hostalive.orgId
  value: "1"
- name: icingaweb.modules.grafana.graphs.hostalive.repeatable
  value: "no"
- name: icingaweb.modules.grafana.graphs.hostalive.dashboarduid
  value: "icinga2-hostalive"
{{- end }}
{{/* pdfexport module */}}
{{- if .Values.modules.pdfexport.enabled }}
- name: icingaweb.modules.pdfexport.config.chrome.host
  value: {{ .Values.modules.pdfexport.host | default "localhost" | quote }}
- name: icingaweb.modules.pdfexport.config.chrome.force_temp_storage
  value: {{ .Values.modules.pdfexport.force_temp_storage | default "0" | quote }}
{{- end }}
{{- end }}