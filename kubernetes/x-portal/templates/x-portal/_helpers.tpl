{{- define "x-portal.name" -}}
{{- include "common.names.fullname" . -}}
{{- end -}}

{{- define "x-portal.waiterName" -}}
{{- printf "%s-migrate-wait" (include "x-portal.name" . | trunc 50 | trimSuffix "-") -}}
{{- end -}}

{{- define "x-portal.claimName" -}}
{{- if .Values.homeSecrets.persistence.existingClaim -}}
{{- tpl .Values.homeSecrets.persistence.existingClaim . -}}
{{- else -}}
{{- printf "%s-home-secrets" (include "x-portal.name" . | trunc 50 | trimSuffix "-") -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.labels" -}}
{{ include "common.labels.standard" . }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end -}}

{{- define "x-portal.migrationName" -}}
{{- printf "%s-migrate-%v" (include "x-portal.name" . | trunc 40 | trimSuffix "-") .Release.Revision -}}
{{- end -}}

{{- define "x-portal.secretName" -}}
{{- if .auth.existingSecret -}}
{{- tpl .auth.existingSecret .context | required "auth.existingSecret resolved empty" -}}
{{- else -}}
{{- printf "%s-%s-auth" (include "x-portal.name" .context | trunc 45 | trimSuffix "-") .component -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.secretKey" -}}
{{- tpl (index .auth.secretKeys .field) .context | required (printf "auth.secretKeys.%s is required" .field) -}}
{{- end -}}

{{- define "x-portal.image" -}}
{{- include "x-portal.containerImage" (dict "image" .Values.image "context" .) -}}
{{- end -}}

{{- define "x-portal.containerImage" -}}
{{- $registry := default .image.registry .context.Values.global.imageRegistry -}}
{{- if .image.digest -}}
{{- if not (regexMatch "^sha256:[a-f0-9]{64}$" .image.digest) -}}
{{- fail "image.digest must be sha256 followed by 64 lowercase hexadecimal characters" -}}
{{- end -}}
{{- printf "%s@%s" (ternary (printf "%s/%s" $registry .image.repository) .image.repository (not (empty $registry))) .image.digest -}}
{{- else -}}
{{- $_ := required "image.tag or image.digest is required; use a published immutable image" .image.tag -}}
{{- include "common.images.image" (dict "imageRoot" .image "global" .context.Values.global) -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.componentName" -}}
{{- printf "%s-%s" (include "x-portal.name" .context | trunc 38 | trimSuffix "-") .component -}}
{{- end -}}

{{- define "x-portal.auditClaimName" -}}
{{- if .Values.audit.persistence.existingClaim -}}
{{- tpl .Values.audit.persistence.existingClaim . -}}
{{- else -}}
{{- include "x-portal.componentName" (dict "context" . "component" "audit") -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.trustName" -}}
{{- if .Values.trust.existingConfigMap -}}
{{- tpl .Values.trust.existingConfigMap . -}}
{{- else -}}
{{- include "x-portal.componentName" (dict "context" . "component" "trust") -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.bootstrapName" -}}
{{- printf "%s-bootstrap-%v" (include "x-portal.name" . | trunc 38 | trimSuffix "-") .Release.Revision -}}
{{- end -}}

{{- define "x-portal.gatewaySelector" -}}
{{ include "common.labels.matchLabels" . }}
app.kubernetes.io/component: gateway
{{- end -}}

{{- define "x-portal.scheduling" -}}
{{- with .Values.nodeSelector }}
nodeSelector: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.affinity }}
affinity: {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.tolerations }}
tolerations: {{- toYaml . | nindent 2 }}
{{- end }}
{{- end -}}

{{/* cert-manager is the TLS producer unless an external Secret is selected. */}}
{{- define "x-portal.tlsSecretName" -}}
{{- if .Values.gateway.tls.existingSecret -}}
{{- tpl .Values.gateway.tls.existingSecret . | required "gateway.tls.existingSecret resolved empty" -}}
{{- else if .Values.gateway.tls.certManager.enabled -}}
{{- if .Values.gateway.tls.certManager.secretName -}}
{{- tpl .Values.gateway.tls.certManager.secretName . | required "gateway.tls.certManager.secretName resolved empty" -}}
{{- else -}}
{{- include "x-portal.componentName" (dict "context" . "component" "tls") -}}
{{- end -}}
{{- else -}}
{{- fail "gateway.tls.existingSecret is required when cert-manager is disabled" -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.tlsIssuerName" -}}
{{- if .Values.gateway.tls.certManager.issuerRef.name -}}
{{- tpl .Values.gateway.tls.certManager.issuerRef.name . | required "gateway.tls.certManager.issuerRef.name resolved empty" -}}
{{- else if .Values.gateway.tls.certManager.createIssuer -}}
{{- include "x-portal.componentName" (dict "context" . "component" "tls-issuer") -}}
{{- else -}}
{{- fail "gateway.tls.certManager.issuerRef.name is required when createIssuer=false" -}}
{{- end -}}
{{- end -}}

{{- define "x-portal.tlsDnsNames" -}}
{{- $name := include "x-portal.name" . -}}
{{- $names := list $name (printf "%s.%s.svc" $name .Release.Namespace) -}}
{{- range .Values.gateway.tls.certManager.dnsNames -}}
{{- $names = append $names (tpl . $) -}}
{{- end -}}
{{- $names | uniq | toYaml -}}
{{- end -}}

{{- define "x-portal.tlsIpAddresses" -}}
{{- $ips := list -}}
{{- with .Values.global.frontendVip -}}
{{- $ips = append $ips . -}}
{{- end -}}
{{- range .Values.gateway.tls.certManager.ipAddresses -}}
{{- $ips = append $ips . -}}
{{- end -}}
{{- $ips | uniq | toYaml -}}
{{- end -}}

{{- define "x-portal.seedName" -}}
{{- printf "%s-seed-%v" (include "x-portal.name" . | trunc 38 | trimSuffix "-") .Release.Revision -}}
{{- end -}}

{{- define "x-portal.seedAccessName" -}}
{{- include "x-portal.componentName" (dict "context" . "component" "seed-access") -}}
{{- end -}}
