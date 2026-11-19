# git-http Helm chart

This chart deploys Apache `git-http-backend` for authenticated Git Smart HTTP
and offline Git bundle imports.

## Components

| Component | Purpose |
| --- | --- |
| `init-auth` | Creates `/auth/htpasswd` from Secret `username/password` |
| `init-repositories` | Creates bare repositories and applies `repositoryConfig` |
| `git-http` | Apache + Git Smart HTTP server |
| `bundle-sync` | Imports bundles from the repository PVC |

## Main configuration

| Key | Required | Purpose |
| --- | --- | --- |
| `repositories` | Yes | Bare repositories directly below `apache.repositoryRoot` |
| `apache.repositoryRoot` | No | Defaults to `/srv/git` |
| `global.github.user` | Managed Secret | Basic Auth username |
| `global.github.fg_token` | Managed Secret | Basic Auth password; long tokens are supported |
| `auth.existingSecret` | No | External Secret with `username/password` keys |
| `bundleSync.enabled` | No | Enable the bundle import sidecar |
| `bundleSync.incomingRoot` | When enabled | Defaults to `/srv/git/bundle` |
| `bundleSync.processedRoot` | When enabled | Defaults to `/srv/git/processed` |
| `repositoryConfig` | No | Git configuration applied to every bare repository |

## Values example

```yaml
global:
  github:
    user: git-user
    fg_token: replace-with-token
  sharedVolume:
    enabled: true
  sharedPersistenceVolume:
    - volumeName: git-repository
      pvcName: git-repository-pvc
      path: /srv/git
      accessModes: [ReadWriteOnce]
      shareFor: [git-http]

repositories:
  - grafana-entities.git

auth:
  existingSecret: ""

repositoryConfig:
  uploadpack.allowFilter: true
  receive.denyNonFastForwards: false
  receive.denyDeletes: true
  http.receivepack: true

bundleSync:
  enabled: true
  incomingRoot: /srv/git/bundle
  processedRoot: /srv/git/processed
  intervalSeconds: 30
```

## Authentication

Managed mode creates `git-http-auth`:

| Key | Source |
| --- | --- |
| `username` | `global.github.user` |
| `password` | `global.github.fg_token` |

`init-auth` runs `/usr/bin/htpasswd -ci5` and writes a SHA-512 crypt hash to a
shared `emptyDir`. Apache mounts only the generated hash file read-only. Build
the image from [`/root/hieund/git-server/Dockerfile`](/root/hieund/git-server/Dockerfile)
with `apache2-utils` and `htpasswd -5` support.

For an external Secret:

```yaml
auth:
  existingSecret: git-http-auth
```

The external Secret must contain `username` and `password` in the same
namespace. Grafana references it through `gitsync.gitHttp.auth`.

## Storage and permissions

- The PVC is mounted at `/srv/git`.
- `init-repositories` runs as root to repair ownership.
- Apache and `bundle-sync` run as UID/GID `10001:10001`.
- With `ReadWriteOnce`, keep `replicaCount: 1`.
- Do not edit the live bare repository as root from another node.

## Offline bundle flow

Place bundles below:

```text
/srv/git/bundle/<repository>/<branch>/*.bundle
```

Branch names containing `/` use nested directories:

```text
/srv/git/bundle/grafana-entities.git/customer/test/update.bundle
```

Create a bundle with the matching branch ref:

```bash
git bundle create update.bundle refs/heads/customer/test
```

Copy the completed file into the incoming directory and ensure UID `10001` can
read and write it.

| Branch state | Action |
| --- | --- |
| Missing | Create branch from bundle |
| Destination behind | Fast-forward |
| Equal | Skip |
| Destination ahead | Skip; never downgrade |
| Diverged | Skip; never force-push |

Processed bundles are moved to:

```text
/srv/git/processed/applied/
/srv/git/processed/skipped/
/srv/git/processed/failed/
```

Move a failed bundle back to the matching incoming path after correcting the
cause. Equal/ahead/diverged bundles require a new reconciled bundle.

## Git protocol

Keep the default:

```yaml
apache:
  forceProtocolV2: false
```

The chart forwards the client's `Git-Protocol` header. Do not force protocol v2
globally because pushes to empty repositories may require protocol v0.

## Deploy and verify

```bash
helm lint --strict . \
  --set-string global.github.user=test-user \
  --set-string global.github.fg_token=test-password

helm upgrade --install git-http . -n nmaa \
  -f values-private.yaml

kubectl rollout status deployment/git-http -n nmaa
kubectl get pod,service,endpoints -n nmaa \
  -l app.kubernetes.io/name=git-http
```

Logs:

```bash
kubectl logs -n nmaa deployment/git-http -c init-auth
kubectl logs -n nmaa deployment/git-http -c init-repositories
kubectl logs -n nmaa deployment/git-http -c bundle-sync
```

Check refs and repository configuration:

```bash
kubectl exec -n nmaa deployment/git-http -c bundle-sync -- sh -ec '
  repo=/srv/git/grafana-entities.git
  git --git-dir="$repo" show-ref
  git --git-dir="$repo" config --list
'
```

## Grafana integration

```yaml
gitsync:
  url: http://git-http:8080/git/grafana-entities.git
  gitHttp:
    auth:
      existingSecret: git-http-auth
      usernameKey: username
      passwordKey: password
```

When `remote_branch` is not `main`, the Grafana init Job can promote that branch
to `main`. Therefore `receive.denyNonFastForwards` defaults to `false`; Grafana
uses `force-with-lease` only when `forcePush=true`.
