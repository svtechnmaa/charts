# Docker Registry Chart

Deploy a Docker Registry with one of two storage backends:

- `s3`: SeaweedFS S3 backend
- `filesystem`: PVC/hostPath PV backend


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

### Filesystem HostPath PV

```bash
helm -n registry upgrade --install registry ./docker-registry/ \
  --create-namespace \
  --set registry.storageBackend=filesystem \
  --set imagePullSecret.username=<username> \
  --set imagePullSecret.password=<token> \
  --set registry.http.secret=<stable-random-secret>
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
    secure: false
    rootdirectory: /
    endpointOverride: ""
    accesskey: ""
    secretkey: ""
    v4auth: true
    forcepathstyle: true
    chunksize: 5242880
    multipartcopythresholdsize: 5368709120
    multipartcopychunksize: 33554432
    multipartcopymaxconcurrency: 1

seaweedfs:
  serviceName: seaweedfs-s3
  namespace: seaweedfs
  port: 8333
  protocol: http
  filerServiceName: seaweedfs-filer-client
  filerPort: 8888
```

In `s3` mode, the chart renders the bucket creation Job.

## Filesystem Backend

Use this mode when the registry stores blobs on a mounted PVC/hostPath PV.

```yaml
registry:
  storageBackend: filesystem
  http:
    secret: "<stable-random-secret>"
  replicaCount: 3
  strategy:
    type: Recreate
  filesystem:
    rootdirectory: /var/lib/registry
    delete:
      enabled: true
  sharedVolume:
    enabled: true
    volumeName: "docker-registry"
    path: "/opt/shared/registry"
    mountPath: /var/lib/registry
    pvcName: "docker-registry-pvc"
    storageSize: 20Gi
    accessModes: ReadWriteOnce
    storageClass: registry-local
    reclaimPolicy: Retain
```

In `filesystem` mode, the chart renders PV/PVC templates and does not render the bucket creation Job.

`registry.sharedVolume` uses a hostPath PV with `ReadWriteOnce` by default. The Deployment does not render node scheduling constraints, so the chart does not pin registry pods to a specific node. Multiple registry pods reference the same PVC; with `ReadWriteOnce`, Kubernetes storage semantics still allow read-write mounting only on one node at a time.
