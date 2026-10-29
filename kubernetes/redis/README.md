# Redis

This chart deploys Redis; RedisInsight is optional. Connection settings and Redis authentication are separate.

## Basic values

```yaml
replicaCount: 1
service:
  type: ClusterIP
args:
  - redis-server
  - --appendonly
  - "yes"
```

Run from the charts repository with your storage/configuration overlay:

```sh
helm upgrade --install redis ./kubernetes/redis -n speedtest \
  --create-namespace -f /etc/svtech/redis-values.yaml
```

## Persistent data and upgrades

`sharedPersistenceVolume.enabled` defaults to `false`. Enable it to create a PVC;
the default templated `volumes` and `volumeMounts` then mount it at `/data`:

```yaml
sharedPersistenceVolume:
  enabled: true
  volumeName: redis-data
  pvcName: redis-data-pvc
  storageSize: 1Gi
  accessModes: ReadWriteMany
  storageClass: seaweedfs-storage
  path: /data
```

Use a StorageClass that exists and supports the requested access mode. The chart
creates only the PVC; a dynamic provisioner supplies the PV, or you must supply
a suitable static PV. An explicit `storageClass: ""` requests no StorageClass.
Preserve `pvcName` when upgrading an existing installation.

`volumes` and `volumeMounts` accept YAML lists or templated strings (`|`). If you
override either field, include the Redis data volume/mount in your replacement;
Helm does not append list entries, and the chart does not inject missing mounts
or deduplicate them. Avoid duplicating mounts supplied by global shared volumes.
AOF/RDB must also be enabled in Redis configuration; a PVC alone does not enable
Redis persistence.

`updateStrategy` defaults to `Recreate`, stopping the old Pod before starting its
replacement. This avoids concurrent writers and RWO multi-attach on upgrades,
with downtime during replacement. Use one replica for standalone Redis; this
chart does not configure Redis replication.

The managed PVC has `helm.sh/resource-policy: keep` and remains after uninstall.
Plan explicit reuse of that claim or manual cleanup; keeping the PVC is not a
backup of the database.
