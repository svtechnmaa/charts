# EMQX Helm Chart

This chart renders an `apps.emqx.io/v2` `EMQX` custom resource for EMQX Operator. It is intended for stacks that want to reuse EMQX instead of keeping the EMQX object inside an application chart such as Speedtest.

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

## Common Values

| Value | Description | Default |
| --- | --- | --- |
| `image.registry` | Image registry | `ghcr.io` |
| `image.repository` | EMQX image repository | `svtechnmaa/emqx` |
| `image.tag` | EMQX image tag | `6` |
| `imagePullSecrets` | Pull secrets passed to EMQX pods | `[{name: ghcr-pull-secret}]` |
| `config.mode` | EMQX Operator config mode | `Merge` |
| `config.data` | Raw EMQX HOCON config. When empty, the chart renders websocket paths from `global.emqx.mqtt.*` | `""` |
| `global.emqx.mqtt.websocket.mqttPath` | WebSocket MQTT path | `/speedtest/ws-ep` |
| `global.emqx.mqtt.secureWebsocket.mqttPath` | Secure WebSocket MQTT path | `/speedtest/wss-ep` |
| `coreTemplate.replicaCount` | Core node replica count | `1` |
| `coreTemplate.persistence.enabled` | Enable core node PVC template | `true` |
| `coreTemplate.persistence.storageClass` | PVC storage class | `local-path` |
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

## Install

```sh
helm upgrade --install emqx . --namespace speedtest --create-namespace
```

## Check Status

```sh
kubectl get emqx -n speedtest
kubectl get pods,svc -n speedtest
```

The EMQX Operator should report the EMQX resource as `Running` after the cluster is ready.

## MQTT credential ownership

By default, `mqtt.enabled: true` enables built-in password authentication and
provisions `mqtt.auth.username` (default `admin`) during authenticator creation. This
is an MQTT client user, not a dashboard administrator or an API key.

```yaml
mqtt:
  auth:
    username: admin
    password: ""  # Generate once and reuse on cluster-backed upgrades.
    existingSecret: ""
    existingSecretPasswordKey: MQTT_BROKER_PASSWORD
  enabled: true
```

The default Secret for a release named `emqx` is `emqx-mqtt`. Speedtest consumes
that same name/key via its own `mqtt.auth.existingSecret` and
`mqtt.auth.existingSecretPasswordKey`. Do not generate another password in Speedtest.
An existing Secret (string or `{name, keyMapping}`) takes precedence over password.
Partial mappings fall back to `existingSecretPasswordKey`.

For externally managed credentials, both charts reference the same pre-created Secret:

```yaml
# Umbrella values; create speedtest-mqtt-auth externally before installation.
emqx:
  mqtt:
    auth:
      username: admin
      existingSecret: speedtest-mqtt-auth
      existingSecretPasswordKey: mqtt-password
speedtest:
  mqtt:
    auth:
      username: admin
      existingSecret: speedtest-mqtt-auth
      existingSecretPasswordKey: mqtt-password
```

Only the Secret name/key enter the custom resource. A bootstrap initContainer
reads the password via `secretKeyRef` and writes a JSON file (escaping quotes, backslashes and control characters) on a
memory-backed emptyDir. Core and replicant Pods mount that file. Passwords are not
embedded in HOCON or ConfigMaps. The bootstrap image is configurable.

Bootstrap runs when the authenticator is created; it does not rotate an existing
user's password. For an already configured broker, migrate users deliberately via
the EMQX API before switching consumers. On password rotation, update the broker
user, Secret, and consumer Pods together. Offline rendering cannot preserve a
random password; use the external Secret workflow for GitOps.

The chart builds an authentication chain from the built-in backend when
`mqtt.enabled` is true, followed by `mqtt.additionalAuthentication`. Use the
additional list for an HTTP backend that validates application users. Set
`mqtt.enabled: false` and leave the additional list empty if `config.data`
owns the complete authentication chain. Enabling it on an existing anonymous broker will require
credentials from every client. Existing custom volumes/initContainers must not
reuse the reserved name `mqtt-bootstrap`.

References:
- [EMQX bootstrap authentication](https://docs.emqx.com/en/emqx/latest/guides/access-control/authn/mnesia.html)
- The installed CRD must serve `apps.emqx.io/v2` and support the fields rendered by this chart.

## API bootstrap keys

`bootstrapAPIKeys` accepts Secret references only. Plaintext `key` / `secret`
values fail rendering:

```yaml
bootstrapAPIKeys:
  - secretRef:
      key:
        secretName: emqx-api-auth
        secretKey: api-key
      secret:
        secretName: emqx-api-auth
        secretKey: api-secret
```

These credentials authorize the management API; they do not provision MQTT users.
Use an Operator/CRD version supporting `BootstrapAPIKey.secretRef` and
core/replicant `initContainers`/extra volumes. Bootstrap API keys have creation-time
semantics in the Operator; updating values is not an automatic rotation mechanism.

For Speedtest browser users, append an HTTP authenticator pointing to
`http://django-service/api/auth/emqx/`, using POST, JSON content type, and body
fields `username: "${username}"`, `password: "${password}"`, and
`clientid: "${clientid}"`. The backend validates the user's MQTT token and tenant;
the built-in database continues to authenticate service accounts from the Secret.

## Additional authentication and upgrades

In an umbrella chart, put this block below `emqx:`. Standalone values:

```yaml
mqtt:
  enabled: true
  additionalAuthentication:
    - mechanism: password_based
      backend: http
      enable: true
      method: post
      url: http://django-service/api/auth/emqx/
      headers:
        content-type: application/json
      body:
        username: "${username}"
        password: "${password}"
        clientid: "${clientid}"
```

The built-in service account is checked first, then the HTTP backend. Browser
users authenticate with their application MQTT token; do not give them the
service account password. Verify that the Django endpoint is reachable from EMQX.

For a supplied initial service password, set `mqtt.auth.password` and leave
`mqtt.auth.existingSecret: ""`. For auto-generation leave both empty. For an
existing Secret, set its name/key and use the matching broker username.
`global.authenUsers.mqtt.password` is a standalone override; the Speedtest stack
maps `global.authenApps.mqtt.password` into `mqtt.auth.password` using `tpl`.

`helm upgrade` updates the EMQX custom resource. With `config.mode: Merge`, some
configuration changes can be applied at runtime without replacing Pods. Check
`kubectl describe emqx <name> -n speedtest` and the active authentication chain;
Pod age alone does not prove that an upgrade failed. Updating a bootstrap Secret
or restarting a Pod does not guarantee rotation of a user stored in EMQX's database.

## Dashboard exposure

`dashboard.ingress.enabled` defaults to `false`; MQTT WS/WSS ingress remains
available. Enable the dashboard ingress explicitly only after securing dashboard
credentials and access. MQTT credentials and bootstrap API keys do not set the
dashboard login password. To configure the account before exposing it, use a
local port-forward to the dashboard Service or your existing administrative access.

```yaml
dashboard:
  ingress:
    enabled: false
```

Upgrading from a version that always exposed the dashboard removes its managed
Ingress unless this flag is set to true. The dashboard Service remains available
inside the cluster. This flag does not rotate or reset dashboard credentials.
