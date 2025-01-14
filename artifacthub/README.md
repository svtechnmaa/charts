## Subchart's helm package version
<b>artifactub</b> folder is where all subchart's helm package version being saved.

Because this repo is linked in (artifacthub.io), (artifacthub.io) will read all .tgz file in <b>artifacthub</b> folder so all subchart in here will be public on internet.

### Examples:
You can find grafana subchart on (artifacthub.io) by searching "SVTECH Public Helm Charts" then find "grafana" on (artifacthub.io).

Example result for grafana subchart (https://artifacthub.io/packages/helm/svtech-public-helm-charts/grafana).

Below is how to install grafana subchart:
```
helm repo add svtech-public-helm-charts https://svtechnmaa.github.io/charts/artifacthub/
```

```
helm install my-grafana svtech-public-helm-charts/grafana --version 1.0.0
```
