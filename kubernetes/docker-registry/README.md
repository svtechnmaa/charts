# Docker Registry Chart

Deploy a Docker Registry with one of two storage backends:

- `s3`: SeaweedFS S3 backend
- `filesystem`: PVC/local PV backend


## Install

Run commands from the parent chart directory, for example `charts/kubernetes`.

### SeaweedFS S3

```bash
helm -n registry upgrade --install registry ./docker-registry/ \
  --create-namespace \
  --set registry.storageBackend=s3 \
  --set imagePullSecret.username=<username> \
  --set imagePullSecret.password=<token> \
  --set registry.http.secret=<stable-random-secret> \
  --set registry.s3.accesskey=<s3-access-key> \
  --set registry.s3.secretkey=<s3-secret-key>
```

### Filesystem Local PV

```bash
helm -n registry upgrade --install registry ./docker-registry/ \
  --create-namespace \
  --set registry.storageBackend=filesystem \
  --set imagePullSecret.username=<username> \
  --set imagePullSecret.password=<token> \
  --set registry.http.secret=<stable-random-secret> \
  --set registry.persistence.size=30Gi \
  --set registry.persistence.localPV.enabled=true \
  --set registry.persistence.localPV.path=/opt/shared/registry \
  --set registry.persistence.localPV.nodeName=nms-02
```

## Backend Selection

Set the backend with:

```yaml
registry:
  storageBackend: s3 # s3 | filesystem
  http:
    secret: "<stable-random-secret>"
```

`registry.http.secret` must be a stable random value for each release. Generate
one with `openssl rand -hex 32`.

S3 credentials and the registry HTTP secret are rendered into Kubernetes
Secrets and injected into the registry container through environment variables.
They are not written into the registry ConfigMap.

`storage.cache.blobdescriptor` is intentionally not rendered because it can hide
filesystem consistency issues during bootstrap/migrate writes.

## S3 Backend

Use this mode when the registry stores blobs through the SeaweedFS S3 API.

```yaml
registry:
  storageBackend: s3
  http:
    secret: "<stable-random-secret>"
  s3:
    bucket: registry
    region: us-east-1
    endpointOverride: ""
    accesskey: ""
    secretkey: ""
    secure: false
    v4auth: true
    forcepathstyle: true
    chunksize: 134217728
    multipartcopythresholdsize: 1073741824
    multipartcopychunksize: 134217728
    multipartcopymaxconcurrency: 1

seaweedfs:
  serviceName: seaweedfs-s3
  namespace: seaweedfs
  port: 8333
  protocol: http
```

In `s3` mode, the chart renders the bucket creation Job.

## Filesystem Backend

Use this mode when the registry stores blobs on a mounted PVC/local PV.

```yaml
registry:
  storageBackend: filesystem
  http:
    secret: "<stable-random-secret>"
  replicaCount: 1
  strategy:
    type: Recreate
  filesystem:
    rootdirectory: /var/lib/registry
    delete:
      enabled: true
  persistence:
    enabled: true
    mountPath: /var/lib/registry
    accessModes:
      - ReadWriteOnce
    size: 30Gi
    storageClassName: registry-local
    localPV:
      enabled: true
      path: /opt/shared/registry
      nodeName: nms-02
      reclaimPolicy: Retain
```

In `filesystem` mode, the chart renders PV/PVC templates and does not render the bucket creation Job.

For local PV, keep `replicaCount: 1` unless the storage supports multi-writer access.
