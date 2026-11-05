# App Adapters

Packages Grafana and Rundeck integration services from
[deploy/app-adapters](https://github.com/svtechnmaa/x-portal/tree/59ed07338aff16af203204d4b5b203b5cc9f6452/deploy/app-adapters).
Both are opt-in. This chart installs no gateway/Home, Jobs, TLS issuer, database,
Redis, Keycloak or native application. The only bundled dependency is `common`.
The parent stack may install this chart alongside `x-portal`; neither chart
depends on the other. Helpers are namespaced `app-adapters.*` so both can render
as sibling dependencies.

## Values and credentials

Keep configuration under `adapters.grafana` and `adapters.rundeck` in this chart's
values. Each adapter has independent image, auth, resources and pod settings.
Set a published immutable digest or tag for each enabled adapter; Rundeck's
upstream local image must be published before installation. Global image registry
and pull Secrets are supported, as are per-adapter image pull Secrets. Both
adapters run with UID/GID/fsGroup 1000; scheduling and container security settings
are chart-level inputs. Management Services are private ClusterIP services.

External credentials are referenced using `auth.existingSecret` and
`auth.secretKeys`; `existingSecret` takes precedence over supplied initial values.
The chart never copies external credentials. An empty `existingSecret` enables a
managed Secret populated from explicitly supplied, matching credentials:

- `adapters.grafana.auth`: `nativeCredentials` (JSON user/password), `managementToken`.
- `adapters.rundeck.auth`: `nativeToken`, `managementToken`, `bindingKey`, `clientSecret`, `cookieSecret`.

Stored managed keys take precedence on upgrade. Missing keys require explicit
input; empty stored keys fail. This chart does not provision native application
or OIDC accounts, and changing a retained input does not rotate those accounts.
Keep actual credentials out of committed values and prefer producer/stack-owned
Secret references. Offline lookup fixtures verify template behavior, not live
cluster preservation. Credential files are mounted through selected Secret keys;
restart the adapter when its credential reload behavior requires it.

## Adapter configuration

`examples/existing-secrets.yaml` demonstrates both integrations. Replace its addresses,
client IDs and Rundeck image before deployment. The Grafana digest comes from the
upstream example manifest; it is not a claim about the currently deployed lab.

Grafana uses `adapters.grafana.descriptor` as its public discovery document;
`GRAFANA_URL` is derived from the same `gateway.upstream_url`. The native JSON
credential and management bearer token are projected as separate files. Use
`nativeAuth.existingSecret` / `nativeAuth.key` to reuse the upstream
`home-admin-credentials` key `grafana`, while `auth.existingSecret` supplies its
separate management token. Secret directories use normal mounts, not `subPath`,
so credentials can refresh. Public config changes trigger a rollout.

Rundeck uses `adapters.rundeck.config` for one process and one generated
`config.json`. Its management and browser Services are always separate ClusterIP
Services; management is 8090, browser is 4180. The default `browser_url` is templated
to the release's browser Service. Configure its actual browser/OIDC routing,
registered callback, `allowed_return_hosts` and `secure_cookies` for the site.
The session directory stays inside `/var/lib/rundeck-adapter/`, persisted by
`adapters.rundeck.persistence` with one replica and Recreate.

The Rundeck Secret needs all five upstream keys. `binding-key` must contain at
least 32 persistent random bytes; `cookie-secret` must contain exactly 32 random
binary bytes. For a managed Secret, `auth.cookieSecret` is **canonical Base64 of
those 32 bytes**, placed directly in Kubernetes Secret `data` without another
encoding layer. For an external Secret, provision the actual 32-byte file under
its configured key. Do not put native credentials into descriptors or public JSON.

Rundeck's native filesystem ACL roots can be mounted read-only with the adapter's
`extraVolumes` / `extraVolumeMounts` and listed in `config.policy_directories`.
Keep `policy_sources_complete=false` until the operator confirms every native
policy source. Publishing a discovery Service does not configure native Grafana
or Rundeck authorization and does not register it automatically in Home.

## Releases, storage and migration from the combined chart

Default names use the app-adapters chart/release fullname, including ConfigMaps,
Services, managed Secrets and Rundeck's session PVC. Update Home's registered
management/browser origins and token references to these endpoints. Publishing
Services does not register adapters automatically. No Ingress or serving TLS
Certificate is created by this chart; configure browser/OIDC routing at the site.

Rundeck session storage supports `persistence.existingClaim`, storage class (`-`
means an empty class), size, access modes and annotations. Its Recreate deployment
has one writer; the storage driver must apply fsGroup or equivalent permissions.
Back up sessions and their binding/cookie keys together. Chart-owned claims are
deleted on uninstall unless an explicit retention policy is configured.

For a fresh installation, pass the old `adapters` block to this chart and remove
it from x-portal's values. For an existing combined Helm release, splitting charts
is an ownership and data migration, not an automatic resource move:

1. Inventory existing names, Helm release ownership, Secret keys, session claim
   and Home registry entries. Back up the session data and matching credentials.
2. Plan a maintenance window and one writer. Preserve or restore the same session
   binding/cookie keys; use external credential references to their established
   producer, or securely supply preserved values to the new managed Secrets.
3. Choose restored storage for the new release, or explicitly plan retention and
   Helm ownership transfer for the old PVC before using `existingClaim`. A claim
   reference alone does not stop the old release deleting its owned PVC.
4. Coordinate removal of old resources and installation of the independent chart.
   Do not upgrade the old combined release first: removed templates may delete
   its Deployments, Secrets and PVC. Matching `fullnameOverride` alone does not
   transfer Helm ownership or immutable Deployment selectors.
5. Verify mounts, credential access, session continuity and management discovery;
   update Home registry origins and browser/OIDC routes. Keep backups and the old
   configuration for a deliberate rollback. Rollback does not restore deleted data.

No release ownership transfer, deployment or publication is performed by packaging.

## Offline verification

```bash
helm lint /opt/charts/kubernetes/app-adapters --strict \
  -f /opt/charts/kubernetes/app-adapters/examples/existing-secrets.yaml \
  --set adapters.rundeck.image.tag=render-check
python3 -B -m unittest discover -s /opt/charts/tests -p test_x_portal.py -v
helm package /opt/charts/kubernetes/app-adapters --destination /tmp
```

The example endpoints are illustrative site inputs. Supply real images, Secrets,
OIDC/native application settings and storage permissions before installation.
