# BNGBlaster GUI Helm Chart

Helm chart for BNGBlaster GUI with:

- Frontend service exposed by `Ingress`
- Backend service exposed by `ClusterIP`
- External PostgreSQL for backend database connectivity

## Install

Install with the required secrets:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace bngblaster-gui \
  --docker-server=ghcr.io \
  --docker-username=<username> \
  --docker-password=<token>

helm upgrade --install bngblaster-gui ./bngblaster-gui \
  --namespace bngblaster-gui \
  --create-namespace \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set backend.secret.secretKey=<output-of-openssl-rand-hex-32> \
  --set externalPostgresql.host=postgres.database.svc.cluster.local \
  --set externalPostgresql.username=bng_user \
  --set externalPostgresql.password=change-me-db-password \
  --set externalPostgresql.database=bng_web
```

Generate `backend.secret.secretKey` with `openssl rand -hex 32`; it should be a 64-character hex string.

The chart already defines default image repositories and tags in `values.yaml`.
Override them only when deploying a different build.
`ghcr-pull-secret` must already exist in the target namespace.

## Ingress

By default the chart is configured for path-based ingress at:

```text
/bngblaster
```

Key values:

```yaml
ingress:
  enabled: true
  className: ""
  host: ""
  path: /bngblaster
```

When you use a host or IP with this path, requests are routed as:

```text
http://<host-or-ip>/bngblaster -> frontend
http://<host-or-ip>/bngblaster/api -> backend
```

## Database

The backend always connects with:

- `externalPostgresql.host`
- `externalPostgresql.port`
- `externalPostgresql.username`
- `externalPostgresql.password`
- `externalPostgresql.database`

When deploying this chart you should provide:

- `externalPostgresql.host`
- `externalPostgresql.port`
- `externalPostgresql.username`
- `externalPostgresql.password`
- `externalPostgresql.database`

```yaml
externalPostgresql:
  host: pgpool.database.svc.cluster.local
  port: 5432
  username: bng_user
  password: change-me-db-password
  database: bng_web
```

## Production Values

Review these before production:

- `ingress.*`
- `backend.secret.secretKey`
- `externalPostgresql.*`
- `backend.secret.googleClientId`
- `backend.secret.googleClientSecret`
- `backend.secret.googleRedirectUri`
- `backend.secret.keycloakServerUrl`
- `backend.secret.keycloakRealm`
- `backend.secret.keycloakClientId`
- `backend.secret.keycloakClientSecret`
- `backend.secret.keycloakRedirectUri`
- SSO client IDs and secrets
