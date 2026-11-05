# X-Portal 0.2.0

Packages the gateway/Home process, controlled migration and credential-bootstrap
Jobs. Grafana/Rundeck integration services live in the separate `app-adapters`
chart. MySQL, Redis,
Keycloak and the native applications remain external dependencies.

Source: [deploy/kubernetes](https://github.com/svtechnmaa/x-portal/tree/59ed07338aff16af203204d4b5b203b5cc9f6452/deploy/kubernetes)
and [deploy/app-adapters](https://github.com/svtechnmaa/x-portal/tree/59ed07338aff16af203204d4b5b203b5cc9f6452/deploy/app-adapters).
Manifest example addresses are site inputs, not verified cluster settings.

Gateway/Home templates, helpers and Secrets are in `templates/x-portal/`.

## Workloads and defaults

| Upstream artifact | Chart configuration / behavior |
| --- | --- |
| `base/deployment.yaml`, `base/configmap.yaml` | `gateway.enabled=true`, one replica, Recreate, UID/GID/fsGroup 10001, read-only root filesystem; gateway 8443 and Home loopback 8090 in the same process |
| `base/pvc.yaml` | `homeSecrets.persistence`: 1Gi RWO writable file-secret store |
| `base/audit-pvc.yaml` | `audit.persistence`: separate 1Gi RWO audit volume; `audit.retentionDays=30` |
| `base/service.yaml` | ClusterIP 8443; no Home Service/container port |
| Gateway TLS (site integration) | cert-manager Certificate and optional SelfSigned Issuer; IP SAN includes `global.frontendVip` |
| `overlays/loadbalancer` | `examples/loadbalancer.yaml`: LoadBalancer 443 → HTTPS 8443 |
| `jobs/migrate.yaml` | `migration.enabled=false` until explicitly enabled; DDL credential only, zero retries by default |
| `jobs/secret-bootstrap.yaml` | `bootstrap.enabled=false` until explicitly enabled; mounts bootstrap Secret and shared file store, uses stdin |

Helm names are scoped to the release; no namespace is hardcoded. The bundled
`common` library supplies repository naming, labels, pull-secret and timezone
conventions.
All gateway probes use HTTPS `/healthz`; they report process liveness only,
not database, identity or adapter readiness.

## Site inputs and secret ownership

Start with `examples/existing-secrets.yaml`. Fill in `gateway.env` for the public
HTTPS origin, Redis address, exact OIDC issuer, auth/token/JWKS URLs, realm and
portal/Home administration clients. Defaults follow the generic Kubernetes
manifest (`https://keycloak:8443/auth`, realm `nmaa`, portal client `home`,
administration client `home-admin`). Register `<GATEWAY_PUBLIC_URL>/auth/callback`
on the actual portal client. cert-manager supplies gateway TLS as described below.

Set `image.digest` to the published `sha256:...` digest. A digest takes precedence
over `image.tag`; a published tag is supported when a digest is unavailable.
Runtime, migration and bootstrap always use this same image. Pull credentials
use `image.pullSecrets` or `global.imagePullSecrets`.

The external Secret/ConfigMap names below come from the example values file:

| Object | Required keys / content | Consumer |
| --- | --- | --- |
| `x-portal-runtime` | `MYSQL_DSN`, `HOME_MYSQL_DSN`, `OIDC_CLIENT_SECRET` | Gateway only |
| `x-portal-migrator` | `HOME_MYSQL_DSN` | Migration Job only |
| `x-portal-bootstrap` | `keycloak-admin`, `deploy`, `recovery` | Credential-bootstrap Job only |
| Gateway TLS Secret | `tls.crt`, `tls.key`, produced by cert-manager (default `<fullname>-tls`), or `gateway.tls.existingSecret` | Gateway serving certificate at `/certs/tls.crt`, `/certs/tls.key` |
| ConfigMap `x-portal-trust` | `ca.crt`: public PEM CA roots | Gateway's four outbound CA settings via `/trust/ca.crt` |

Each `auth.existingSecret` supports a templated name; `auth.secretKeys` maps the
application fields to the actual Secret keys. External Secrets are referenced,
never created or updated. For a chart-managed Secret, leave `existingSecret`
empty and supply matching credentials through a protected values file:

- `gateway.auth`: `mysqlDsn`, `homeMysqlDsn`, `oidcClientSecret`.
- `migration.auth`: `mysqlDsn`.
- `bootstrap.auth`: `keycloakAdmin`, `deploy`, `recovery`.

Managed keys are retained with `lookup` on upgrades; missing keys require an
explicit value. Runtime credentials are also retained during gateway maintenance
when its managed Secret already exists. No random credential is invented for an
external account. Rotate the external account and Kubernetes Secret together;
changing a retained values credential alone does not rotate it. Helm-managed
inputs remain in release data; prefer external Secrets for centralized management.
Offline rendering cannot look up retained cluster values.

`trust.existingConfigMap` references a site-managed CA bundle; alternatively set
`trust.caBundle` to create a chart-owned ConfigMap. With `trust.enabled=true`, the
chart supplies `OIDC_CA_FILE`, `HOME_OIDC_CA_FILE`, `HOME_KEYCLOAK_CA_FILE` and
`GATEWAY_UPSTREAM_CA_FILE`. Explicit custom paths in `gateway.env` can override
these when paired with `extraVolumes` / `extraVolumeMounts`. Disable `trust.enabled`
only when system roots or separately mounted trust paths suffice. Insecure TLS
verification flags remain false.

## Gateway TLS with cert-manager

cert-manager and its CRDs are platform prerequisites; this chart does not install
another cert-manager or provision MySQL, Redis or Keycloak. With
`gateway.tls.existingSecret` empty, `gateway.tls.certManager.enabled=true` creates
one Certificate. cert-manager is the sole producer of its TLS Secret, and the
Deployment resolves that exact Secret through the same helper. The chart never
renders a second TLS Secret containing generated key material.

`global.frontendVip` (this exact casing) is automatically added to
`Certificate.spec.ipAddresses`. IPv4 and IPv6 are supported; additional addresses
under `gateway.tls.certManager.ipAddresses` are merged and deduplicated. The
Certificate also includes the release's short Service DNS name and
`<service>.<namespace>.svc`, plus `certManager.dnsNames`. Without a VIP it still
has the Service DNS SANs. Invalid IP addresses and CIDR values fail values schema
validation. This parameter adds a certificate identity; it does not allocate a
VIP, change `service.loadBalancerIP`, or replace `GATEWAY_PUBLIC_URL`. Configure
those network/origin settings to match the actual frontend separately.

The default creates a namespaced SelfSigned Issuer, following the Traefik chart's
local pattern. The Certificate has an organization subject, RSA-2048 key with
`rotationPolicy: Always`, duration 2160h and renewBefore 360h. Self-signed serving
certificates need client trust distribution. For the site's existing CA or other
platform issuer, use `examples/cert-manager.yaml`, replacing the issuer name:

```yaml
global:
  frontendVip: 192.0.2.10 # replace with the parent stack's actual IP
gateway:
  env:
    GATEWAY_PUBLIC_URL: https://192.0.2.10
  tls:
    existingSecret: ""
    certManager:
      createIssuer: false
      issuerRef:
        name: site-ca
        kind: ClusterIssuer
        group: cert-manager.io
```

An existing namespaced Issuer must be in the release namespace; ClusterIssuer is
cluster-scoped. The issuer must support issuing certificates for the requested
IP SANs. `createIssuer=true` creates a SelfSigned `cert-manager.io` Issuer; set it
false for external issuers. `certManager.secretName` can customize the output
Secret name. `Certificate.spec.ipAddresses` and `issuerRef` follow the
[cert-manager Certificate API](https://cert-manager.io/docs/usage/certificate/).

The Certificate and optional Issuer remain present while `gateway.enabled=false`
for migration/bootstrap maintenance. This avoids removing their ownership and
potentially garbage-collecting the TLS Secret between phases. These phases also
require cert-manager when managed TLS is selected. Cert-manager resource presence
is not silently skipped based on offline Helm API discovery.

To reuse a TLS Secret managed elsewhere, apply `examples/existing-tls.yaml` or
set `gateway.tls.existingSecret`. This reference takes precedence and suppresses
both Certificate and Issuer creation. External mode retains configurable
`certKey`/`privateKeyKey`; cert-manager mode requires the standard `tls.crt` and
`tls.key` keys. Disabling cert-manager requires an external TLS Secret when the
gateway is enabled. Review ownership before switching an already deployed
Certificate to external mode; disabling a producer is not a renewal migration.

The outbound `trust` CA bundle remains separate from the gateway serving
certificate: it authenticates Keycloak and upstreams, not incoming browser TLS.
Do not automatically copy the generated serving certificate into that bundle.

cert-manager renews the Kubernetes Secret, but the gateway currently loads its
serving certificate at process startup. After issuance/renewal, restart the
gateway or use the site's existing Secret-change rollout controller; this chart
does not install one. Mounted files alone do not prove the process reloaded them.
See [cert-manager renewal/reload guidance](https://cert-manager.io/docs/usage/certificate/#rotation-of-the-private-key).

## Database and credential bootstrap

Create separate Gateway and Home schemas before running either application Job.
The Home runtime account needs DML only; the migrator needs DML plus
CREATE/ALTER/INDEX/REFERENCES/TRIGGER/DROP on the same Home schema. The DBA must
account for MySQL binary-log trigger creation policy. DSNs use the Go MySQL driver
format with `parseTime=true`; the migrator may also need `multiStatements=true`.
The gateway currently supports a Redis address only, without Redis AUTH/TLS options.

For a fresh Gateway database, `files/gateway-schema.sql` is the upstream neutral
DDL: three tables, no users or demo data. Apply it separately using a DBA credential
after selecting the Gateway database. It does not reconcile existing tables.
Home's versioned migrations are embedded in `/usr/local/bin/x-portal-migrate`.

The file-secret store cannot be populated by projecting Kubernetes Secret keys
at `HOME_SECRET_DIR`. The bootstrap Job runs `x-portal-secret put` with these
values on stdin, not command arguments:

| Bootstrap key | Default destination reference |
| --- | --- |
| `keycloak-admin` | `secret://keycloak/home-admin` |
| `deploy` | `secret://deploy/bootstrap` |
| `recovery` | `secret://recovery/home` |

The destination references are read from `gateway.env.HOME_*_CREDENTIAL_REF`, so
the bootstrap Job and runtime stay aligned when these names change. Updating the
bootstrap Kubernetes Secret alone does not update the file store: explicitly
rerun the Job. The runtime never mounts bootstrap or migrator credentials.

## Ordered install and maintenance

Jobs are normal opt-in resources, not install/upgrade hooks. Routine Helm upgrades
with the default flags cannot migrate the database or overwrite file credentials.
`bootstrap.enabled=true` requires `gateway.enabled=false` and persistent secret
storage. Do not bootstrap a writable store while another gateway uses that claim.

For an existing release, first stop the gateway and wait for all of its pods to
terminate. Use its actual Deployment name (default `x-portal` for release
`x-portal`), and serialize deployments to the same databases/file store. Then run
these phases with one consistent, site-specific values file:

```bash
# Maintenance on an existing installation only:
kubectl -n x-portal scale deployment/x-portal --replicas=0
kubectl -n x-portal wait --for=delete pod \
  -l app.kubernetes.io/instance=x-portal,app.kubernetes.io/component=gateway --timeout=300s

# 1. Provision PVCs and migrate Home. Runtime Secrets/TLS/trust are not needed here.
helm upgrade --install x-portal /opt/charts/kubernetes/x-portal -n x-portal --create-namespace \
  -f /secure/x-portal-values.yaml \
  --set gateway.enabled=false --set migration.enabled=true --set bootstrap.enabled=false \
  --wait --wait-for-jobs --timeout 15m

# 2. Write initial file credentials. Do this only for initial bootstrap or rotation.
helm upgrade x-portal /opt/charts/kubernetes/x-portal -n x-portal \
  -f /secure/x-portal-values.yaml \
  --set gateway.enabled=false --set migration.enabled=false --set bootstrap.enabled=true \
  --wait --wait-for-jobs --timeout 10m

# 3. Start the gateway with its normal runtime inputs. Both Jobs are disabled.
helm upgrade x-portal /opt/charts/kubernetes/x-portal -n x-portal \
  -f /secure/x-portal-values.yaml \
  --set gateway.enabled=true --set migration.enabled=false --set bootstrap.enabled=false \
  --wait --timeout 10m
```

Jobs have revision-specific names. Save their results/logs before moving to the
next phase: disabling a Job removes it from the release. If `migration.enabled`
and `gateway.enabled` are deliberately enabled together, a narrowly scoped waiter
holds gateway startup until the current revision's migration Job completes. The
waiter alone mounts an API token; its Role permits reading only that named Job.
Keep that Job while this configuration is active, since future pods also wait for
it. Match `migration.wait.image.tag` to the Kubernetes server's supported minor.

Migration/bootstrap failure stops the corresponding `--wait-for-jobs` command;
inspect the Job logs and resolve the failure before advancing. Helm rollback does
not reverse DB migrations or file-store writes. Stop the old gateway for schema
changes that are incompatible with its binary.

After initial bootstrap, the external bootstrap Secret may be removed if the site's
credential system can recover/rotate its values. Seed initial roles/users through
the operator-only Home API using a local port-forward or operator client inside
the Pod, then register applications through supported APIs. Do not insert Home
domain objects directly into SQL. Management origins and adapter tokens are stored
in Home's App Registry; no gateway environment update registers an adapter.

## Seed initial roles and administrator users

The credential-bootstrap Job only writes credentials to Home's file store.
After the gateway is ready, `seed.enabled=true` creates a separate, revisioned
Job that calls Home's operator-only `POST /api/v1/seed` using the deploy bearer.
It sends roles first, then users, then app entries, one at a time, waiting for
each entry before proceeding. This avoids role/user target-lease collisions.
It waits for every returned operation to have terminal `success`; partial
success, failure, retry-required or timeout fails the Job. Acceptance (HTTP 202)
alone is not success. Zero operations is a valid idempotent rerun. No automatic
POST retries or Kubernetes Job retries are used after an ambiguous submission.
Inspect operations before explicitly rerunning a failed seed.

Provide a retained external Secret through `seed.artifactSecret` /
`seed.artifactKey` with a JSON artifact containing roles and users. For example,
the JSON structure is:

```json
{
  "roles": [{
    "name": "portal-admin",
    "description": "Portal administrators",
    "home_permissions": ["home:settings:users", "home:settings:roles", "home:settings:apps", "home:settings:integration", "home:operations:view"]
  }],
  "users": [{
    "username": "portal-admin",
    "email": "portal-admin@example.test",
    "first_name": "Portal",
    "last_name": "Admin",
    "role": "portal-admin",
    "initial_password": "<provide privately in the Secret>"
  }]
}
```

Supply the same deploy credential that was written to the file store through
`seed.deployAuth.existingSecret` / `seed.deployAuth.key`. Keep that Secret
available after disabling credential bootstrap; a removed chart-managed
bootstrap Secret cannot serve this consumer. These references support `tpl`.
The chart does not create/copy these Secrets, generate user passwords, import
fixture users, or change a user's password on every Helm upgrade. Secret inputs
stay outside Helm values/ConfigMaps. Existing role/user handling follows the
app's seed contract; this is not a general permission reconciliation/rotation API.

Home remains bound to 127.0.0.1:8090. The Job has a native kubectl sidecar that
port-forwards the release Deployment to its own loopback listener; no Home Service
or public endpoint is added. Kubernetes >=1.29 with SidecarContainers enabled is
required. Set `seed.tunnel.image.tag` to a kubectl version compatible with the
cluster. RBAC grants get on the named Deployment, get/list on namespace pods and
create on namespace pods/portforward. Only the tunnel container mounts its
projected API token. Only the Python client mounts the artifact and selected
deploy-token key; it mounts no runtime, migrator or Keycloak administration Secret.
Native sidecar lifecycle lets the Job finish when the Python client exits.

With site inputs and Secrets ready:

```bash
helm upgrade x-portal /tmp/x-portal-0.2.0.tgz --kube-context <verified-context> -n test \
  -f values_test.yaml --set seed.enabled=true --wait --wait-for-jobs --timeout 8m
# Save the Job logs/results, then disable seed.enabled for routine upgrades.
```

Seed is opt-in, requires `gateway.enabled=true`, and cannot run alongside
migration or credential bootstrap. Each enabled Helm revision starts a new Job;
disable it once the initial seed is verified. Disabling removes the Job, script,
ServiceAccount and RBAC, but does not remove the externally managed artifact or
the accounts/roles created through Home. Seeded initial passwords are temporary
according to the application contract; complete the first-login password change.
Keep the artifact Secret under the site's credential retention/rotation policy.

The test site's seed artifact is `test/x-portal-admin-seed`, key `seed.json`,
with username `portal-admin`. To retrieve its initial password in an authorized
operator terminal:

```bash
kubectl --context kubernetes-admin@cluster.local -n test get secret x-portal-admin-seed \
  -o jsonpath='{.data.seed\.json}' | base64 -d | \
  python3 -c 'import json,sys; print(json.load(sys.stdin)["users"][0]["initial_password"])'
```

After the first-login password change, the artifact's initial password no longer
represents the account's current password. Do not use reseeding as rotation.

## Application adapters

Grafana and Rundeck adapters are packaged separately in
[app-adapters](../app-adapters/README.md). This chart has no adapter dependency;
the parent stack can include both charts and configure their values independently.
Move the former `adapters` block into the `app-adapters` chart's values. Passing
that block to `x-portal` now fails with migration guidance.

Management origins and tokens still require registration in Home's App Registry.
For existing combined releases, follow the ownership and state migration guidance
in the app-adapters README before upgrading.

## Storage, networking and upgrading from 0.1.0

The two stateful directories (Home secrets and Home audit)
support storage class, size, annotations and external claims. Setting storageClass
to `-` renders an empty storage class; an empty value uses the cluster default.
Ephemeral storage is available for disposable testing; bootstrap requires a PVC.
Claims remain rendered while gateway is disabled for maintenance. Back up them
before upgrades/uninstall; chart-owned claims are deleted on Helm uninstall unless
an explicit retention policy is configured. The CSI driver must apply fsGroup or
provide equivalent permissions; Kubernetes does not inherit image volume ownership.

Compared with 0.1.0, gateway UID/GID/fsGroup changes from 1000 to upstream 10001.
Existing secret files with mode 0600 need a controlled ownership migration, or
retain the prior numeric security context consistently for runtime and bootstrap.
The Home secret claim name is preserved. A new audit claim is added. Home 8090
now binds loopback and is never published; probes move to HTTPS `/healthz`.
Migration now defaults to disabled and must be selected for each planned schema
change. Gateway TLS filenames become `/certs/tls.crt` and `/certs/tls.key`.
CA trust is explicit and required by default. Gateway TLS now defaults to
cert-manager; a nonempty existingSecret keeps the external TLS behavior. The
Certificate automatically includes global.frontendVip as an IP SAN. Update saved
values accordingly.

Only gateway 8443 is allowed by the default ingress NetworkPolicy. There is no
egress restriction. No Ingress resource is created; use the site's existing
edge with an HTTPS upstream, or the LoadBalancer example for native HTTPS 443.
Home 8090 is private even when NetworkPolicy enforcement is unavailable.
External runtime Secret, serving TLS and trust ConfigMap changes need an explicit
rollout because they are read at startup. Managed public config/trust changes
trigger rollouts through checksums.

## Temporary test deployment

`values_test.yaml` records the overrides for release `x-portal`, namespace `test`,
on the cluster containing node `10.98.5.231`. The public HTTPS origin is
`https://10.98.5.236`; cert-manager includes that IP in the serving certificate.
It uses the NMAA realm at `https://10.98.5.234/keycloak` (clients `home` and
`home-admin`), Redis in `nmaa`, and the separately deployed Grafana adapter.
The values file contains Secret references rather than credentials.

The pinned application image fails migration 26 against the existing MariaDB
10.11 backend because it uses MySQL multi-valued index syntax. For this temporary
test only, `examples/mysql-test.yaml` supplies a standalone, one-replica MySQL
8.4.8 deployment with the requested digest, a private Service and a 5Gi local-path
PVC. This manifest is applied separately; it is not a chart dependency or Helm
template. Uninstalling x-portal does not remove this temporary DB or its PVC.

Before applying that manifest, provision Secret `x-portal-mysql-test-auth` with
`root-password`, `gateway-password`, `home-password`, and `migrator-password`.
Use shell-safe random hexadecimal values for these initialization inputs. Init
scripts run only against an empty data directory; changing a Secret does not
rotate accounts in an initialized PVC. The script creates `x_portal_gateway_test`
and `x_portal_home_test`, Gateway tables and three schema-scoped accounts. Home
schema migrations still run through the chart's explicit migration Job. The test
server enables `log_bin_trust_function_creators` for that short-lived migrator.

Provision `x-portal-mysql-runtime` with `MYSQL_DSN`, `HOME_MYSQL_DSN` and
`OIDC_CLIENT_SECRET`, and `x-portal-mysql-migrator` with `HOME_MYSQL_DSN`. DSNs
point to `x-portal-mysql-test.test.svc.cluster.local:3306`; runtime accounts have
DML privileges, and only the migrator has schema DDL privileges. Retain the
`x-portal-bootstrap` Secret and public CA ConfigMap `x-portal-trust`. Run the
migration/bootstrap/runtime phases above using `values_test.yaml` and namespace
`test`; final values keep both Jobs disabled. With local-path's
WaitForFirstConsumer provisioning, wait for each maintenance Job explicitly:
unused audit/storage claims can remain Pending until their consumer starts.

The MariaDB test databases and credentials are preserved. After the application
adds MariaDB support, validate its migration recovery from the existing partial
schema before switching DSNs back. A working MySQL test does not establish
MariaDB or Galera compatibility.

## Offline verification

```bash
helm lint /opt/charts/kubernetes/x-portal --strict \
  -f /opt/charts/kubernetes/x-portal/examples/existing-secrets.yaml --set image.tag=render-check
python3 -B -m unittest discover -s /opt/charts/tests -p test_x_portal.py -v
helm package /opt/charts/kubernetes/x-portal --destination /tmp
```

These checks validate packaging and wiring. A live installation still needs real
images, Secrets, trust/TLS, DB grants/migrations, storage permissions and OIDC/native
application qualification. No live cluster changes are part of chart preparation.
