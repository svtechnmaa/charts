{{- define "bngblaster-gui.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "bngblaster-gui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "bngblaster-gui.selectorLabels" -}}
app.kubernetes.io/name: {{ include "bngblaster-gui.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "bngblaster-gui.image" -}}
{{- $repository := required (printf "%s.image.repository is required" .component) .image.repository -}}
{{- $tag := required (printf "%s.image.tag is required" .component) .image.tag -}}
{{- if .root.Values.global.imageRegistry -}}
{{- printf "%s/%s:%s" (.root.Values.global.imageRegistry | trimSuffix "/") $repository $tag -}}
{{- else -}}
{{- printf "%s:%s" $repository $tag -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.backendName" -}}
{{- printf "%s-backend" (include "bngblaster-gui.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.frontendName" -}}
{{- printf "%s-frontend" (include "bngblaster-gui.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.postgresName" -}}
{{- printf "%s-postgres" (include "bngblaster-gui.fullname" .) | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.databaseHost" -}}
{{- $externalPostgresql := default dict (index .Values "externalPostgresql") -}}
{{- $host := index $externalPostgresql "host" -}}
{{- if $host -}}
{{- $host -}}
{{- else -}}
{{- $postgresqlHa := index .Values "postgresql-ha" -}}
{{- if $postgresqlHa.enabled -}}
{{- printf "%s-postgresql-ha-pgpool" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- required "externalPostgresql.host is required when postgresql-ha.enabled=false" $host -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.namespace" -}}
{{- $namespace := index .Values "namespace" -}}
{{- if and $namespace (index $namespace "name") -}}
{{- index $namespace "name" -}}
{{- else -}}
{{- .Release.Namespace -}}
{{- end -}}
{{- end -}}

{{- define "bngblaster-gui.imagePullSecretName" -}}
{{- default (printf "%s-registry" (include "bngblaster-gui.fullname" .)) .Values.imagePullSecret.name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "bngblaster-gui.imagePullSecrets" -}}
{{- $secrets := list -}}
{{- $createdSecretName := "" -}}

{{- if .Values.imagePullSecret.create -}}
{{- $createdSecretName = include "bngblaster-gui.imagePullSecretName" . -}}
{{- $secrets = append $secrets (dict "name" $createdSecretName) -}}
{{- end -}}

{{- range .Values.global.imagePullSecrets }}
{{- if kindIs "string" . }}
{{- if ne . $createdSecretName -}}
{{- $secrets = append $secrets (dict "name" .) -}}
{{- end -}}
{{- else }}
{{- if ne (get . "name") $createdSecretName -}}
{{- $secrets = append $secrets . -}}
{{- end }}
{{- end }}
{{- end }}

{{- if $secrets }}
imagePullSecrets:
{{- toYaml $secrets | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "bngblaster-gui.dockerConfigJson" -}}
{{- $registry := required "imagePullSecret.registry is required when imagePullSecret.create=true" .Values.imagePullSecret.registry -}}
{{- $username := required "imagePullSecret.username is required when imagePullSecret.create=true" .Values.imagePullSecret.username -}}
{{- $token := required "imagePullSecret.token is required when imagePullSecret.create=true" .Values.imagePullSecret.token -}}
{{- $auth := printf "%s:%s" $username $token | b64enc -}}
{{- dict "auths" (dict $registry (dict "username" $username "password" $token "auth" $auth)) | toJson -}}
{{- end -}}
