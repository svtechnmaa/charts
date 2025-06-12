{{- define "gdg.importer" -}}
context_name: {{ .Values.gdgConfig.contextName }}
storage_engine: {}
contexts:
  main:
    token: {{ .Values.gdgConfig.mainContext.credentials.token | quote }}
    connections:
      credential_rules:
      {{- range .Values.gdgConfig.mainContext.connectionRules }}
        - rules:
        {{- range .rules }}
          - field: {{ .field }}
            regex: {{ .regex }}
        {{- end }}
          secure_data: {{ .secureData }}
      {{- end }}
    dashboard_settings:
      nested_folders: {{ .Values.gdgConfig.mainContext.dashboardSettings.nestedFolders }}
      ignore_filters: {{ .Values.gdgConfig.mainContext.dashboardSettings.ignoreFilters }}
      ignore_bad_folders: {{ .Values.gdgConfig.mainContext.dashboardSettings.ignoreBadFolders }}
    watched:
    {{- range .Values.gdgConfig.mainContext.watched }}
      - {{ . }}
    {{- end }}
    watched_folders_override: {{ .Values.gdgConfig.mainContext.watchedFoldersOverride | toYaml | nindent 6 }}
    organization_name: {{ .Values.gdgConfig.mainContext.organizationName | quote }}
    output_path: {{ .Values.gdgConfig.mainContext.outputPath | quote }}
    {{- $username := default .Values.global.adminUser .Values.gdgConfig.mainContext.credentials.username | quote }}
    {{- $password := default .Values.global.adminPassword .Values.gdgConfig.mainContext.credentials.password | quote }}
    password: {{ include "admin.password" . }}
    storage: ""
    url: {{ .Values.gdgConfig.mainContext.url | quote }}
    user_name: {{ include "admin.user" . }}
    user: null
global:
  debug: {{ .Values.gdgConfig.global.debug }}
  api_debug: {{ .Values.gdgConfig.global.apiDebug }}
  ignore_ssl_errors: {{ .Values.gdgConfig.global.ignoreSSLErrors }}
  retry_count: {{ .Values.gdgConfig.global.retryCount }}
  retry_delay: {{ .Values.gdgConfig.global.retryDelay }}
  clear_output: {{ .Values.gdgConfig.global.clearOutput }}
{{- end -}}
