{{/*
Copyright Broadcom, Inc. All Rights Reserved.
SPDX-License-Identifier: APACHE-2.0
*/}}

{{/* Compatibility helpers for running this chart with Bitnami common 1.x. */}}

{{- define "postgresql-ha.v1compat.capabilities.networkPolicy.apiVersion" -}}
networking.k8s.io/v1
{{- end -}}

{{- define "postgresql-ha.v1compat.capabilities.policy.apiVersion" -}}
{{- if semverCompare "<1.21-0" (include "common.capabilities.kubeVersion" .) -}}
policy/v1beta1
{{- else -}}
policy/v1
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.capabilities.psp.supported" -}}
{{- if semverCompare "<1.25-0" (include "common.capabilities.kubeVersion" .) -}}
true
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.images.image" -}}
{{- $registry := default .imageRoot.registry ((.global).imageRegistry) -}}
{{- $repository := .imageRoot.repository -}}
{{- $separator := ":" -}}
{{- $termination := .imageRoot.tag | toString -}}
{{- if .imageRoot.digest -}}
  {{- $separator = "@" -}}
  {{- $termination = .imageRoot.digest | toString -}}
{{- end -}}
{{- if $registry -}}
{{- printf "%s/%s%s%s" $registry $repository $separator $termination -}}
{{- else -}}
{{- printf "%s%s%s" $repository $separator $termination -}}
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.images.renderPullSecrets" -}}
{{- $pullSecrets := list -}}
{{- $context := .context -}}
{{- range (($context.Values.global).imagePullSecrets) -}}
  {{- $name := . -}}
  {{- if kindIs "map" . -}}
    {{- $name = .name -}}
  {{- end -}}
  {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" $name "context" $context)) -}}
{{- end -}}
{{- range .images -}}
  {{- range .pullSecrets -}}
    {{- $name := . -}}
    {{- if kindIs "map" . -}}
      {{- $name = .name -}}
    {{- end -}}
    {{- $pullSecrets = append $pullSecrets (include "common.tplvalues.render" (dict "value" $name "context" $context)) -}}
  {{- end -}}
{{- end -}}
{{- if $pullSecrets -}}
imagePullSecrets:
  {{- range ($pullSecrets | uniq) }}
  - name: {{ . }}
  {{- end }}
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.images.version" -}}
{{- $tag := .imageRoot.tag | toString -}}
{{- if regexMatch `^([0-9]+)(\.[0-9]+)?(\.[0-9]+)?(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$` $tag -}}
  {{- $version := semver $tag -}}
  {{- printf "%d.%d.%d" $version.Major $version.Minor $version.Patch -}}
{{- else -}}
  {{- .chart.AppVersion -}}
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.labels.standard" -}}
{{- $base := include "common.labels.standard" .context | fromYaml -}}
{{- with .context.Chart.AppVersion -}}
  {{- $_ := set $base "app.kubernetes.io/version" (. | toString | replace "+" "_" | trunc 63 | trimSuffix "-" | trimSuffix "_" | trimSuffix ".") -}}
{{- end -}}
{{- $custom := include "common.tplvalues.render" (dict "value" .customLabels "context" .context) | fromYaml -}}
{{- merge (default (dict) $custom) $base | toYaml -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.labels.matchLabels" -}}
{{- $base := include "common.labels.matchLabels" .context | fromYaml -}}
{{- $custom := include "common.tplvalues.render" (dict "value" .customLabels "context" .context) | fromYaml -}}
{{- $customMatchLabels := pick (default (dict) $custom) "app.kubernetes.io/name" "app.kubernetes.io/instance" -}}
{{- merge $customMatchLabels $base | toYaml -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.tplvalues.merge" -}}
{{- $merged := dict -}}
{{- range .values -}}
  {{- $rendered := include "common.tplvalues.render" (dict "value" . "context" $.context) | fromYaml -}}
  {{- $merged = merge $merged (default (dict) $rendered) -}}
{{- end -}}
{{- $merged | toYaml -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.compatibility.renderSecurityContext" -}}
{{- $securityContext := .secContext -}}
{{- $openshift := (((.context.Values.global).compatibility).openshift) -}}
{{- if and $openshift (or (eq $openshift.adaptSecurityContext "force") (and (eq $openshift.adaptSecurityContext "auto") (.context.Capabilities.APIVersions.Has "security.openshift.io/v1"))) -}}
  {{- $securityContext = omit $securityContext "fsGroup" "runAsUser" "runAsGroup" -}}
  {{- if not .secContext.seLinuxOptions -}}
    {{- $securityContext = omit $securityContext "seLinuxOptions" -}}
  {{- end -}}
{{- end -}}
{{- if $securityContext.privileged -}}
  {{- $securityContext = omit $securityContext "capabilities" -}}
{{- end -}}
{{- omit $securityContext "enabled" | toYaml -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.resources.preset" -}}
{{- $presets := dict
  "nano" (dict "requests" (dict "cpu" "100m" "memory" "128Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "150m" "memory" "192Mi" "ephemeral-storage" "2Gi"))
  "micro" (dict "requests" (dict "cpu" "250m" "memory" "256Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "375m" "memory" "384Mi" "ephemeral-storage" "2Gi"))
  "small" (dict "requests" (dict "cpu" "500m" "memory" "512Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "750m" "memory" "768Mi" "ephemeral-storage" "2Gi"))
  "medium" (dict "requests" (dict "cpu" "500m" "memory" "1024Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "750m" "memory" "1536Mi" "ephemeral-storage" "2Gi"))
  "large" (dict "requests" (dict "cpu" "1.0" "memory" "2048Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "1.5" "memory" "3072Mi" "ephemeral-storage" "2Gi"))
  "xlarge" (dict "requests" (dict "cpu" "1.0" "memory" "3072Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "3.0" "memory" "6144Mi" "ephemeral-storage" "2Gi"))
  "2xlarge" (dict "requests" (dict "cpu" "1.0" "memory" "3072Mi" "ephemeral-storage" "50Mi") "limits" (dict "cpu" "6.0" "memory" "12288Mi" "ephemeral-storage" "2Gi")) -}}
{{- if hasKey $presets .type -}}
{{- index $presets .type | toYaml -}}
{{- else -}}
{{- fail (printf "Invalid resources preset %q" .type) -}}
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.secrets.lookup" -}}
{{- $secretData := (lookup "v1" "Secret" (include "common.names.namespace" .context) .secret).data -}}
{{- if and $secretData (hasKey $secretData .key) -}}
{{- index $secretData .key -}}
{{- else if .defaultValue -}}
{{- .defaultValue | toString | b64enc -}}
{{- end -}}
{{- end -}}

{{- define "postgresql-ha.v1compat.errors.insecureImages" -}}
{{- $invalidImages := list -}}
{{- $globalRegistry := ((.context.Values.global).imageRegistry) -}}
{{- $originalImages := .context.Chart.Annotations.images -}}
{{- range .images -}}
  {{- $registry := default .registry $globalRegistry -}}
  {{- $image := printf "%s/%s" $registry .repository -}}
  {{- if not (contains $image $originalImages) -}}
    {{- $invalidImages = append $invalidImages (printf "%s:%s" $image (.tag | toString)) -}}
  {{- end -}}
{{- end -}}
{{- if and $invalidImages (not (((.context.Values.global).security).allowInsecureImages)) -}}
  {{- fail (printf "Original containers have been substituted with unrecognized images: %s. Set global.security.allowInsecureImages=true only if you trust them." (join ", " $invalidImages)) -}}
{{- else if $invalidImages -}}
WARNING: Image verification was skipped for: {{ join ", " $invalidImages }}
{{- end -}}
{{- end -}}

{{/* common 1.x predates these informational image/resource warnings. */}}
{{- define "postgresql-ha.v1compat.noop" -}}{{- end -}}
