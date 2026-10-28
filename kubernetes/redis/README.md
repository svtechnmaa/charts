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