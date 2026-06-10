# BNGBlaster GUI Helm Chart

Default deployment:

- Namespace: `bngblaster-gui`
- Release name: `bngblaster-gui`
- PostgreSQL HA dependency with Pgpool enabled
- Static PostgreSQL PV templates using one hostPath-backed volume per PostgreSQL replica
- Optional chart-managed image pull secret for private registries
- Frontend exposed by `LoadBalancer`
- Backend exposed internally by `ClusterIP`

Fetch chart dependencies before installing:

```bash
helm dependency update ./bngblaster-gui
```

Install example:

```bash
helm install bngblaster-gui ./bngblaster-gui \
  --namespace bngblaster-gui \
  --set backend.image.repository=your-registry/bngblaster-backend \
  --set backend.image.tag=1.0.0 \
  --set frontend.image.repository=your-registry/bngblaster-frontend \
  --set frontend.image.tag=1.0.0 \
  --set backend.secret.secretKey=change-me-to-a-32-byte-hex-string \
  --set postgresql-ha.postgresql.password=change-me-db-password \
  --set postgresql-ha.postgresql.repmgrPassword=change-me-repmgr-password \
  --set postgresql-ha.pgpool.adminPassword=change-me-pgpool-admin-password
```

Update these values for production:

- `backend.secret.secretKey`
- `postgresql-ha.postgresql.password`
- `postgresql-ha.postgresql.repmgrPassword`
- `postgresql-ha.pgpool.adminPassword`
- `postgresStorage.volumes[].hostPath`
- `backend.config.frontendUrl`
- `backend.config.googleRedirectUri`
- `backend.config.keycloakRedirectUri`
- SSO client IDs/secrets if enabled

The backend connects to Pgpool by default through:

```text
<release-name>-postgresql-ha-pgpool:5432
```

For the default in-chart PostgreSQL HA deployment, database credentials can stay
under `postgresql-ha.postgresql` and the backend Secret will reuse them for
backward compatibility.

By default, `postgresql-ha.persistence.storageClass: "-"` disables dynamic
provisioning. Bitnami PVCs render `storageClassName: ""`, and this chart creates
matching static hostPath PVs from `postgresStorage.volumes`.
If you set `postgresql-ha.persistence.storageClass` to a real StorageClass, set
`postgresStorage.enabled=false` so the subchart uses dynamic provisioning.

The default static PVs include `claimRef` entries for Bitnami's StatefulSet PVC
names:

```text
data-<release-name>-postgresql-ha-postgresql-0
data-<release-name>-postgresql-ha-postgresql-1
data-<release-name>-postgresql-ha-postgresql-2
```

If you override the PostgreSQL release naming, set
`postgresStorage.volumes[].claimName` explicitly.

For an external Pgpool or PostgreSQL service, disable the dependency and set the
backend database connection explicitly:

```yaml
postgresql-ha:
  enabled: false

externalPostgresql:
  host: "pgpool.database.svc.cluster.local"
  port: 5432
  username: "bng_user"
  password: "change-me-db-password"
  database: "bng_web"
```

For private images, the chart can create a Docker registry secret:

```bash
helm upgrade --install bngblaster-gui ./bngblaster-gui \
  --namespace bngblaster-gui \
  --set imagePullSecret.create=true \
  --set imagePullSecret.registry=ghcr.io \
  --set imagePullSecret.username=your-github-username \
  --set imagePullSecret.token="$GH_TOKEN"
```

When `imagePullSecret.create=true`, backend and frontend pods automatically use the created secret. You can still use an existing secret instead:

```yaml
global:
  imagePullSecrets:
    - name: existing-registry-secret
```

If the namespace already exists and is not managed by this chart, install with:

```bash
helm install bngblaster-gui ./bngblaster-gui \
  --namespace bngblaster-gui \
  --set namespace.create=false \
  --set backend.image.repository=your-registry/bngblaster-backend \
  --set backend.image.tag=1.0.0 \
  --set frontend.image.repository=your-registry/bngblaster-frontend \
  --set frontend.image.tag=1.0.0 \
  --set backend.secret.secretKey=change-me-to-a-32-byte-hex-string \
  --set postgresql-ha.postgresql.password=change-me-db-password \
  --set postgresql-ha.postgresql.repmgrPassword=change-me-repmgr-password \
  --set postgresql-ha.pgpool.adminPassword=change-me-pgpool-admin-password
```
