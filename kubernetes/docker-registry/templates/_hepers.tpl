{{/*
SeaweedFS S3 endpoint
*/}}
{{- define "registry.s3.endpoint" -}}
{{- $protocol := .Values.seaweedfs.protocol | default "http" -}}
{{- $svc := .Values.seaweedfs.serviceName | default "seaweedfs-s3" -}}
{{- $ns := .Values.seaweedfs.namespace | default .Release.Namespace -}}
{{- $port := .Values.seaweedfs.port | default 8333 -}}
{{- printf "%s://%s.%s.svc.cluster.local:%v" $protocol $svc $ns $port -}}
{{- end }}

{{/*
SeaweedFS Filer endpoint used to configure bucket metadata
*/}}
{{- define "registry.filer.endpoint" -}}
{{- $protocol := .Values.seaweedfs.protocol | default "http" -}}
{{- $svc := .Values.seaweedfs.filerServiceName | default "seaweedfs-filer-client" -}}
{{- $ns := .Values.seaweedfs.namespace | default .Release.Namespace -}}
{{- $port := .Values.seaweedfs.filerPort | default 8888 -}}
{{- printf "%s://%s.%s.svc.cluster.local:%v" $protocol $svc $ns $port -}}
{{- end }}
