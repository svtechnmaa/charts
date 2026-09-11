# EMQX Helm Chart

This chart renders an `apps.emqx.io/v2beta1` `EMQX` custom resource for EMQX Operator. It is intended for stacks that want to reuse EMQX instead of keeping the EMQX object inside an application chart such as Speedtest.

## Prerequisites

Install the EMQX Operator before installing this chart. The official getting-started guide requires:

- a running Kubernetes cluster
- `kubectl` access to that cluster
- Helm 3 or higher
- `cert-manager` 1.1.6 or higher
- EMQX Operator installed from the EMQX Helm repository

Reference: https://docs.emqx.com/en/emqx-operator/latest/getting-started/getting-started.html

Example operator install:

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo add emqx https://repos.emqx.io/charts
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true

helm upgrade --install emqx-operator emqx/emqx-operator \
  --namespace emqx-operator-system \
  --create-namespace

kubectl wait --for=condition=Ready pods \
  -l "control-plane=controller-manager" \
  -n emqx-operator-system
```

## Install

```sh
helm upgrade --install emqx . --namespace speedtest --create-namespace
```

For the Speedtest stack, keep the EMQX custom resource name as `emqx` so the operator-created services are named `emqx-listeners` and `emqx-dashboard`, matching the current Speedtest defaults:

```yaml
fullnameOverride: emqx

mqtt:
  websocket:
    mqttPath: /speedtest/ws-ep
  secureWebsocket:
    mqttPath: /speedtest/wss-ep

ingress:
  enabled: true
  className: speedtest
  listeners:
    websocket:
      path: /speedtest/ws-ep
    secureWebsocket:
      path: /speedtest/wss-ep
  dashboard:
    path: /speedtest/emqx/(.*)
```

## Common Values

| Value | Description | Default |
| --- | --- | --- |
| `image.registry` | Image registry | `ghcr.io` |
| `image.repository` | EMQX image repository | `svtechnmaa/emqx` |
| `image.tag` | EMQX image tag | `latest` |
| `imagePullSecrets` | Pull secrets passed to EMQX pods | `[{name: ghcr-pull-secret}]` |
| `config.mode` | EMQX Operator config mode | `Merge` |
| `config.data` | Raw EMQX HOCON config. When empty, the chart renders websocket paths from `mqtt.*` | `""` |
| `mqtt.websocket.mqttPath` | WebSocket MQTT path | `/speedtest/ws-ep` |
| `mqtt.secureWebsocket.mqttPath` | Secure WebSocket MQTT path | `/speedtest/wss-ep` |
| `coreTemplate.replicaCount` | Core node replica count | `1` |
| `coreTemplate.persistence.enabled` | Enable core node PVC template | `true` |
| `coreTemplate.persistence.storageClass` | PVC storage class | `seaweedfs-storage` |
| `coreTemplate.persistence.size` | PVC size | `1Gi` |

## Custom EMQX Config

Set `config.data` to replace the generated websocket config block:

```yaml
config:
  mode: Merge
  data: |
    listeners.ws.default {
      websocket.mqtt_path = "/mqtt"
    }
```

## Check Status

```sh
kubectl get emqx -n speedtest
kubectl get pods,svc -n speedtest
```

The EMQX Operator should report the EMQX resource as `Running` after the cluster is ready.
