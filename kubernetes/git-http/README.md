# git-http

Lightweight authenticated Git Smart HTTP server. The
chart runs Apache with `git-http-backend`, exposes bare repositories below
`/srv/git`, and supports authenticated fetch and push over HTTP.

## Responsibilities

This chart owns the Git server and bare repository infrastructure:

- expose Git Smart HTTP through the `git-http` Service;
- protect repository access with HTTP Basic Authentication;
- create missing bare repositories listed in `repositories`;
- apply the Git server settings;
- normalize repository ownership for the non-root Apache container.

This chart does **not** seed repository content. Another dedicated bootstrap workflow is responsible for pushing the initial `main` and `upstream` branches after the Git server becomes available.

## Repository initialization

Declare bare repositories as direct children of `apache.repositoryRoot`:

```yaml
repositories:
  - grafana-entities.git
  - another-repository.git
```

Repository names cannot contain `/` and cannot be `.` or `..`.

On every pod start, the `init-repositories` container:

1. creates each missing bare repository;
2. validates that an existing path is a bare Git repository;
3. configures:
   - `uploadpack.allowFilter=true`;
   - `receive.denyNonFastForwards=true`;
   - `receive.denyDeletes=true`;
   - `http.receivepack=true`;
4. changes repository ownership to the Apache runtime UID/GID;
5. grants read/write access to the owner and group only.

The init container runs as root with only the capabilities required to prepare
the mounted storage. The Apache container continues to run as UID/GID `10001`.
The relevant defaults are:

```yaml
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 10001
  runAsGroup: 10001
  fsGroup: 10001

initContainerSecurityContext:
  runAsNonRoot: false
  runAsUser: 0
  runAsGroup: 0
  allowPrivilegeEscalation: false
  capabilities:
    drop: [ALL]
    add: [CHOWN, DAC_OVERRIDE, FOWNER]
```

## Authentication

The chart creates the `git-http-auth` Secret containing an `htpasswd` entry.
Credentials are read from:

```yaml
global:
  github:
    user: "git-user"
    fg_token: "git-password-or-token"
```

Both values are required when rendering this chart. Do not commit real tokens
to `values.yaml`; supply them through the platform's secret-management flow or
a protected values file.

Example: the internal repository URL used by Grafana is:

```text
http://git-http:8080/git/grafana-entities.git
```

## Repository storage

The default configuration expects a PVC named `git-repository-pvc` and mounts
it at `/srv/git` through the shared-volume convention:

```yaml
global:
  sharedVolume:
    enabled: true
  sharedPersistenceVolume:
    - volumeName: git-repository
      pvcName: git-repository-pvc
      storageSize: 2Gi
      path: /srv/git
      accessModes: ReadWriteOnce
      storageClass: git-repository-hostpath
      folderName: git-repository
      shareFor:
        - git-http
```

The `git-http` chart only mounts the referenced claim; the PVC must be created
by the umbrella chart/platform storage templates or supplied separately.

Clear or replace this selector when the storage is available on other nodes.
With `ReadWriteOnce` storage, keep `replicaCount: 1` unless the selected storage
supports concurrent writers safely.

## Git protocol negotiation

Some Pure Git function requires Git Smart HTTP protocol v2 for fetch operations. The
default configuration forwards the client's `Git-Protocol` header:

```yaml
apache:
  forceProtocolV2: false
```

This renders:

```apache
SetEnvIf Git-Protocol ".*" GIT_PROTOCOL=$0
```

Do not force protocol v2 globally. A normal Git CLI push to an empty repository
may use a protocol-v0 `git-receive-pack` advertisement; forcing v2 can make the
client fail with:

```text
fatal: invalid server response; got '000000... capabilities^{}'
```

## Deployment

Render and validate the chart:

```bash
helm template git-http . \
  --set-string global.github.user=test-user \
  --set-string global.github.fg_token=test-password

helm lint . --strict \
  --set-string global.github.user=test-user \
  --set-string global.github.fg_token=test-password
```

Deploy using the protected values used by the platform:

```bash
helm upgrade --install git-http . -n nmaa -f /path/to/protected-values.yaml
kubectl rollout status deployment/git-http -n nmaa
```

Confirm that the Service has an endpoint:

```bash
kubectl get pod,service,endpoints -n nmaa -l app.kubernetes.io/name=git-http
```

Inspect repository initialization:

```bash
kubectl logs -n nmaa deployment/git-http -c init-repositories
```

Inspect refs and repository configuration:

```bash
kubectl exec -n nmaa deployment/git-http -- sh -ec '
  repo=/srv/git/grafana-entities.git
  git -c safe.directory="$repo" --git-dir="$repo" show-ref || true
  git -c safe.directory="$repo" --git-dir="$repo" config --list
'
```