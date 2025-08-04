{{- define "generate_clickhouse_list" -}}
{{- $clusterName := .clusterName -}}
{{- $replicaCount := .replicaCount | int -}}
{{- $shardCount := .shardCount | int -}}
{{- $releaseName := .releaseName -}}

{{- range $i, $ := until $shardCount }}
  {{- range $j, $ := until $replicaCount }}
      {{- printf "- chi-%s-clickhouse-%s-%d-%d:9000" $releaseName $clusterName $i $j -}}
      {{- if not (and (eq $i (sub $shardCount 1)) (eq $j (sub $replicaCount 1))) }}
      {{- printf "\n" -}}
      {{- end -}}
  {{- end -}}
{{- end -}}
{{- end -}}