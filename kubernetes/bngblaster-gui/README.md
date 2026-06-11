# BNGBlaster GUI Helm Chart

Helm chart for BNGBlaster GUI with:

- Frontend service exposed by `LoadBalancer`
- Backend service exposed by `ClusterIP`
- PostgreSQL HA dependency enabled by default
- Static hostPath PVs for the default PostgreSQL HA storage
- Optional chart-managed image pull secret for private registries

## Install

Fetch dependencies:

```bash
helm dependency update ./bngblaster-gui
```

Install with the required secrets:

```bash
helm upgrade --install bngblaster-gui ./bngblaster-gui \
  --namespace bngblaster-gui \
  --create-namespace \
  --set backend.secret.secretKey=change-me-to-a-32-byte-hex-string \
  --set postgresql-ha.postgresql.password=change-me-db-password \
  --set postgresql-ha.postgresql.repmgrPassword=change-me-repmgr-password \
  --set postgresql-ha.pgpool.adminPassword=change-me-pgpool-admin-password \
  --set imagePullSecret.username=your-registry-username \
  --set imagePullSecret.token=your-registry-token
```

The chart already defines default image repositories and tags in `values.yaml`.
Override them only when deploying a different build.

## Default Database

By default, `postgresql-ha.enabled=true`. The backend connects to Pgpool:

```text
<release-name>-postgresql-ha-pgpool:5432
```

Backend database credentials are taken from:

- `postgresql-ha.postgresql.username`
- `postgresql-ha.postgresql.password`
- `postgresql-ha.postgresql.database`

When HA is enabled, `externalPostgresql.*` is ignored.

## External Database

Disable the dependency and set external connection values:

```yaml
postgresql-ha:
  enabled: false

externalPostgresql:
  host: pgpool.database.svc.cluster.local
  port: 5432
  username: bng_user
  password: change-me-db-password
  database: bng_web
```

## Storage

Default storage uses static hostPath PVs:

```yaml
postgresql-ha:
  persistence:
    storageClass: "-"

postgresStorage:
  enabled: true
```

Default PostgreSQL PVC names:

```text
data-<release-name>-postgresql-ha-postgresql-0
data-<release-name>-postgresql-ha-postgresql-1
data-<release-name>-postgresql-ha-postgresql-2
```

Default static PV names and host paths include the app name:

```text
bngblaster-gui-postgres-data-0 -> /data/postgresql/bngblaster-gui/postgres-0
bngblaster-gui-postgres-data-1 -> /data/postgresql/bngblaster-gui/postgres-1
bngblaster-gui-postgres-data-2 -> /data/postgresql/bngblaster-gui/postgres-2
```

For production, prefer a real StorageClass:

```yaml
postgresql-ha:
  persistence:
    storageClass: your-storage-class

postgresStorage:
  enabled: false
```

hostPath requires node affinity, suitable host directory permissions, and a
separate backup strategy. If you override release naming, set
`postgresStorage.volumes[].claimName` explicitly.

## Image Pull Secret

By default, the chart creates `ghcr-pull-secret` from:

```yaml
imagePullSecret:
  create: true
  registry: ghcr.io
  username: ""
  token: ""
```

To use an existing secret instead:

```yaml
imagePullSecret:
  create: false

global:
  imagePullSecrets:
    - name: existing-registry-secret
```

## Production Values

Review these before production:

- `backend.secret.secretKey`
- `postgresql-ha.postgresql.password`
- `postgresql-ha.postgresql.repmgrPassword`
- `postgresql-ha.pgpool.adminPassword`
- `backend.config.frontendUrl`
- `backend.config.googleRedirectUri`
- `backend.config.keycloakRedirectUri`
- SSO client IDs and secrets
- PostgreSQL storage configuration
