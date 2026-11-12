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
- normalize repository ownership for the non-root Apache container;
- periodically import offline Git bundles from the repository PVC.

The bundle sidecar only creates a missing branch or fast-forwards an existing
branch. The Grafana bootstrap workflow remains responsible for creating its
initial `main` and `upstream` branches when no imported bundle provides them.

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
   - every key/value declared in `repositoryConfig`;
4. changes repository ownership to the Apache runtime UID/GID;
5. grants read/write access to the owner and group only.

The init container runs as root with only the capabilities required to prepare
the mounted storage. It assigns the runtime UID/GID read/write/traverse access
to `apache.repositoryRoot` itself before preparing repositories and bundle
directories. This also covers PVC roots initially owned by root with restrictive
permissions. The Apache container and bundle sidecar continue to run as UID/GID
`10001`. The relevant defaults are:

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

The default receive policy allows intentional non-fast-forward updates while
continuing to reject ref deletion:

```yaml
repositoryConfig:
  uploadpack.allowFilter: true
  receive.denyNonFastForwards: false
  receive.denyDeletes: true
  http.receivepack: true
```

Grafana uses this capability only when promoting a non-`main`
`gitsync.remote_branch` to destination `main`, and protects the update with
`--force-with-lease`. Set `receive.denyNonFastForwards: true` when no consumer
requires that promotion behavior. Additional repository-local Git settings can
be added to the same map without changing the Deployment template.

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

## Offline bundle synchronization

The optional `bundle-sync` sidecar scans `bundleSync.incomingRoot` periodically:

```yaml
bundleSync:
  enabled: true
  incomingRoot: /srv/git/bundle
  processedRoot: /srv/git/processed
  intervalSeconds: 30
```

Place each bundle below its target repository and branch:

```text
/srv/git/bundle/<repository>/<branch>/*.bundle
```

Branch names containing `/` are represented by nested directories. For example,
this imports `refs/heads/customer/test` into `grafana-entities.git`:

```text
/srv/git/bundle/grafana-entities.git/customer/test/20261110.bundle
```

Create the bundle with the same branch ref:

```bash
git bundle create 20261110.bundle refs/heads/customer/test
```

Copy a bundle under a temporary filename and rename it to the `.bundle` suffix
only after the copy completes. This prevents the scanner from reading a partial
file. Files and their parent directories must be readable and writable by the
pod runtime UID/GID `10001:10001` so the non-root sidecar can archive them.

For every valid bundle, the sidecar imports the named branch into a temporary
repository and compares its commit with the bare repository:

| Repository state | Action |
| --- | --- |
| Branch missing | Create the branch from the bundle. |
| Repository behind bundle | Fast-forward the branch. |
| Equal | Skip the push. |
| Repository ahead of bundle | Log and skip the push. |
| Histories diverged | Log and skip the push. |

Every inspected bundle is moved below `processedRoot`, preserving the relative
repository/branch path under an outcome directory:

```text
processed/
├── applied/   # missing/behind pushed successfully
├── skipped/   # equal/ahead/diverged
└── failed/    # invalid path/ref/bundle/repository or failed push
```

After correcting the cause of a failure, move its `.bundle` file from
`processed/failed` back to the matching path below `incomingRoot` to retry it.
The sidecar never force-pushes or deletes a branch.

Inspect the sidecar:

```bash
kubectl logs -n nmaa deployment/git-http -c bundle-sync
```

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
