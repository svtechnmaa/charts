{{- define "grafana.adminUser" -}}
{{- $local := tpl .Values.grafanaConfig.auth.username . -}}
{{- $global := tpl (default "" .Values.global.authenUsers.grafana.user) . -}}
{{- $legacy := tpl (default "" .Values.global.adminUser | toString) . -}}
{{- default (default $local $legacy) $global | required "grafanaConfig.auth.username or global.authenUsers.grafana.user is required" -}}
{{- end -}}

{{- define "grafana.adminSecretName" -}}
{{- if .Values.grafanaConfig.auth.existingSecret -}}
{{- tpl .Values.grafanaConfig.auth.existingSecret . | required "grafanaConfig.auth.existingSecret resolved empty" -}}
{{- else -}}
{{- printf "%s-admin" (include "common.names.fullname" . | trunc 57 | trimSuffix "-") -}}
{{- end -}}
{{- end -}}

{{- define "grafana.adminSecretKey" -}}
{{- tpl .Values.grafanaConfig.auth.existingSecretPasswordKey . | required "grafanaConfig.auth.existingSecretPasswordKey is required" -}}
{{- end -}}

{{/* Chart-managed credentials, including Git/CD keys, always use this Secret. */}}
{{- define "grafana.managedAuthSecretName" -}}
{{- printf "%s-admin" (include "common.names.fullname" . | trunc 57 | trimSuffix "-") -}}
{{- end -}}

{{- define "grafana.databaseSecretName" -}}
{{- if .Values.grafanaConfig.database.auth.existingSecret -}}
{{- tpl .Values.grafanaConfig.database.auth.existingSecret . | required "grafanaConfig.database.auth.existingSecret resolved empty" -}}
{{- else -}}
{{- include "grafana.managedAuthSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "grafana.databaseSecretKey" -}}
{{- tpl .Values.grafanaConfig.database.auth.existingSecretPasswordKey . | required "grafanaConfig.database.auth.existingSecretPasswordKey is required" -}}
{{- end -}}

{{/*
Build a stable environment variable name for datasource secure fields.
*/}}
{{- define "grafana.datasourceEnvName" -}}
{{- $name := regexReplaceAll "[^A-Z0-9_]" ((index . 0) | upper) "_" -}}
{{- $field := regexReplaceAll "[^A-Z0-9_]" ((index . 1) | upper) "_" -}}
{{- printf "GF_DS_%s_%s" $name $field -}}
{{- end -}}
{{- define "grafana.gitsyncMode" -}}
{{- range $key := list "url" "organizations" "remote_branch" "forcePush" "gitHttp" "path" -}}
{{- if hasKey $.Values.gitsync $key -}}
{{- fail (printf "gitsync.%s is retired; configure gitsync.mode and gitsync.<mode>.organizations instead" $key) -}}
{{- end -}}
{{- end -}}
{{- $mode := required "gitsync.mode must be git or github" .Values.gitsync.mode -}}
{{- if not (has $mode (list "git" "github")) -}}{{- fail "gitsync.mode must be git or github" -}}{{- end -}}
{{- $mode -}}
{{- end -}}

{{- define "grafana.gitsyncOrganizationsJson" -}}
{{- $mode := include "grafana.gitsyncMode" . -}}
{{- $config := index .Values.gitsync $mode -}}
{{- $orgs := default list $config.organizations -}}
{{- if not $orgs -}}{{- fail (printf "gitsync.%s.organizations must contain at least one organization" $mode) -}}{{- end -}}
{{- $seen := dict -}}
{{- range $org := $orgs -}}
{{- $name := required (printf "gitsync.%s.organizations[].org is required" $mode) $org.org -}}
{{- $_ := required (printf "gitsync.%s.organizations[%s].branch is required" $mode $name) $org.branch -}}
{{- if or (not (kindIs "slice" $org.path)) (empty $org.path) -}}
{{- fail (printf "gitsync.%s.organizations[%s].path must be a nonempty list" $mode $name) -}}
{{- end -}}
{{- $key := lower $name -}}
{{- if hasKey $seen $key -}}{{- fail (printf "gitsync.%s has duplicate organization %s" $mode $name) -}}{{- end -}}
{{- $_ := set $seen $key true -}}
{{- end -}}
{{- toJson $orgs -}}
{{- end -}}

{{- define "grafana.gitsyncUrl" -}}
{{- $mode := include "grafana.gitsyncMode" . -}}
{{- required (printf "gitsync.%s.url is required" $mode) (index .Values.gitsync $mode).url -}}
{{- end -}}
{{/* Destination credentials belong to git-http when that server is selected. */}}
{{- define "grafana.gitAuthSecretName" -}}
{{- if eq (include "grafana.gitsyncMode" .) "git" -}}
{{- required "gitsync.git.auth.existingSecret is required for git mode" .Values.gitsync.git.auth.existingSecret -}}
{{- else -}}
{{- include "grafana.managedAuthSecretName" . -}}
{{- end -}}
{{- end -}}

{{- define "grafana.gitAuthUsernameKey" -}}
{{- if eq (include "grafana.gitsyncMode" .) "git" -}}
{{- required "gitsync.git.auth.usernameKey is required" .Values.gitsync.git.auth.usernameKey -}}
{{- else -}}signer_name{{- end -}}
{{- end -}}

{{- define "grafana.gitAuthPasswordKey" -}}
{{- if eq (include "grafana.gitsyncMode" .) "git" -}}
{{- required "gitsync.git.auth.passwordKey is required" .Values.gitsync.git.auth.passwordKey -}}
{{- else -}}token{{- end -}}
{{- end -}}
