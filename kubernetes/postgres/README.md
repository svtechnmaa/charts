# PostgreSQL Helm Chart

This chart deploys PostgreSQL for applications that need either:

- A high-availability PostgreSQL cluster managed by `repmgr` and exposed through Pgpool.
- A standalone PostgreSQL instance.

The chart also creates a Kubernetes Secret containing a PostgreSQL connection URL for use by other workloads.

## Prerequisites

- Kubernetes cluster
- Helm 3
- A StorageClass matching the selected mode
- A `ghcr-pull-secret` Secret in the target namespace when using the default private GHCR images
- A suitable persistent storage location on every node that may run PostgreSQL

The chart creates static `hostPath` PersistentVolumes, but it does not create the referenced StorageClass. Create the StorageClass before installing the chart.

> `hostPath` is node-local storage. For production or multi-node clusters, prefer CSI-backed storage. If `hostPath` must be used, constrain each PV and PostgreSQL Pod to the node that owns its data. Moving a Pod to another node with the same path can expose it to unrelated or empty data.

## Deployment modes

Only one PostgreSQL mode should be enabled at a time.

| Mode | `postgresql-ha.enabled` | `postgresql.enabled` | Client endpoint |
| --- | ---: | ---: | --- |
| High availability | `true` | `false` | `<release>-postgresql-ha-pgpool:5432` by default |
| Standalone | `false` | `true` | Value of `postgresql.fullnameOverride`, `postgresql-service:5432` by default |

High availability is enabled by default.

## High-availability installation

Create a values file such as `values-ha.yaml`:

```yaml
postgresql-ha:
  enabled: true
  postgresqlExternalHost: postgresql-ha-pgpool

  postgresql:
    username: app_user
    password: change-me
    database: app_db
    repmgrUsername: repmgr
    repmgrPassword: change-me-too
    repmgrDatabase: repmgr
    replicaCount: 3

  persistence:
    storageClass: postgresql-ha-postgresql
    accessModes:
      - ReadWriteOnce
    size: 20Gi

postgresql:
  enabled: false

# Base directory used by the static hostPath PVs.
persistence:
  hostPath: /data/postgresql
```

Install the chart:

```bash
helm upgrade --install postgres ./kubernetes/postgres \
  --namespace database \
  --create-namespace \
  --values values-ha.yaml
```

Use an odd `postgresql-ha.postgresql.replicaCount`; three replicas are the minimum recommended for quorum-based failover.

## Standalone installation

Create a values file such as `values-standalone.yaml`:

```yaml
postgresql-ha:
  enabled: false

postgresql:
  enabled: true
  fullnameOverride: postgresql-service

  auth:
    username: app_user
    password: change-me
    database: app_db

  primary:
    persistence:
      storageClass: postgresql-standalone-postgresql
      accessModes:
        - ReadWriteOnce
      size: 20Gi

# Base directory used by the static hostPath PV.
persistence:
  hostPath: /data/postgresql
```

Install it with:

```bash
helm upgrade --install postgres ./kubernetes/postgres \
  --namespace database \
  --create-namespace \
  --values values-standalone.yaml
```

Helm stops rendering with an error if standalone mode is enabled without `persistence.hostPath`.

## Application connection Secret

When either mode is enabled, the chart creates a Secret named from the chart fullname with the suffix `-connection-url`. It contains:

```text
POSTGRES_CONNECTION_URL=postgresql://<username>:<password>@<service>:5432/<database>
```

Inspect the generated Secret name:

```bash
kubectl get secrets --namespace database | grep connection-url
```

Decode its connection URL:

```bash
kubectl get secret <connection-secret-name> \
  --namespace database \
  --output jsonpath='{.data.POSTGRES_CONNECTION_URL}' | base64 --decode
```

Applications in another namespace must use a namespace-qualified service hostname, for example:

```text
<service>.database.svc.cluster.local
```

## Important configuration

| Value | Default | Description |
| --- | --- | --- |
| `postgresql-ha.enabled` | `true` | Enable the HA PostgreSQL dependency. |
| `postgresql-ha.postgresql.replicaCount` | `3` | Number of HA PostgreSQL members. Use an odd number. |
| `postgresql-ha.postgresql.username` | `dummy` | HA application database user. |
| `postgresql-ha.postgresql.password` | `dummy@123` | HA application database password. Change before deployment. |
| `postgresql-ha.postgresql.database` | `postgres` | HA application database. |
| `postgresql-ha.persistence.storageClass` | `postgresql-ha-postgresql` | StorageClass used by HA PVCs and static PVs. |
| `postgresql-ha.persistence.size` | `3Gi` | Capacity used by both HA PVCs and static PVs. |
| `postgresql.enabled` | `false` | Enable standalone PostgreSQL. |
| `postgresql.auth.username` | `dummy` | Standalone application database user. |
| `postgresql.auth.password` | `dummy@123` | Standalone application database password. Change before deployment. |
| `postgresql.auth.database` | `default` | Standalone application database. |
| `postgresql.primary.persistence.*` | See `values.yaml` | Storage settings used by both the standalone PVC and static PV. |
| `persistence.hostPath` | `/data/postgresql-ha-postgresql` | Host directory under which the chart creates per-PV data paths. |

See [`values.yaml`](./values.yaml) for image settings and additional dependency configuration.

## Upgrade and recovery notes

- Back up the database before changing image versions, storage settings, or deployment mode.
- Do not enable HA and standalone modes simultaneously.
- Existing PV and PVC capacity does not automatically change when `size` is updated.
- Static PVs use the `Retain` reclaim policy. Uninstalling the release does not delete database data.
- Do not delete or reinitialize retained data until the authoritative PostgreSQL primary and required backups have been identified.
- Avoid overlapping upgrades of a stateful database release.

## Uninstall

```bash
helm uninstall postgres --namespace database
```

The retained PVs and their underlying data must be reviewed and removed separately when data deletion is intentional.
