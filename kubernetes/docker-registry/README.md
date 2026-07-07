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
  --set registry.s3.bucket=registry \
  --set registry.s3.accesskey=<s3-access-key> \
  --set registry.s3.secretkey=<s3-secret-key>
```

By default, the chart builds the S3 endpoint from `seaweedfs.protocol`, `seaweedfs.serviceName`, `seaweedfs.namespace`, and `seaweedfs.port`.
Use `registry.s3.endpointOverride` only when the registry must connect to a custom S3 endpoint.

### Filesystem Local PV

```bash
helm -n registry upgrade --install registry ./docker-registry/ \
  --create-namespace \
  --set registry.storageBackend=filesystem \
  --set imagePullSecret.username=<username> \
  --set imagePullSecret.password=<token> \
  --set registry.http.secret=<stable-random-secret> \
  --set registry.sharedVolume.enabled=true \
  --set registry.sharedVolume.path=/opt/shared/registry \
  --set registry.sharedVolume.pvcName=docker-registry-pvc \
  --set registry.sharedVolume.storageSize=20Gi \
  --set registry.sharedVolume.nodeName=nms-02
```

### With Syncthing Dependency

This chart follows the stacked `netops-data` pattern: `syncthing` is a chart dependency from the SVTECH chart repository and is controlled by `global.syncthing.enabled`.
Before installing or upgrading the parent chart, update chart dependencies from `charts/kubernetes`:

```bash
helm dependency update ./docker-registry
```

Syncthing is enabled by default and configured through the parent values under the `syncthing:` key:

```yaml
global:
  basePath: /opt/shared/
  syncthing:
    enabled: true

syncthing:
  replicaCount: 3
  env:
    LIST_FOLDER: "syncthing_config, registry"
```

The Syncthing chart mounts a hostPath at `<global.basePath><namespace>`, so make sure that path is valid on the target nodes.
To install without Syncthing, set `global.syncthing.enabled=false`.

Example install with filesystem backend and Syncthing enabled:

```bash
helm -n registry upgrade --install registry ./docker-registry/ \
  --create-namespace \
  --set registry.storageBackend=filesystem \
  --set imagePullSecret.username=<username> \
  --set imagePullSecret.password=<token> \
  --set registry.http.secret=<stable-random-secret> \
  --set registry.sharedVolume.enabled=true \
  --set registry.sharedVolume.path=/opt/shared/registry \
  --set registry.sharedVolume.pvcName=docker-registry-pvc \
  --set registry.sharedVolume.storageSize=20Gi \
  --set registry.sharedVolume.nodeName=nms-02 \
  --set global.basePath=/opt/shared/ \
  --set global.syncthing.enabled=true \
  --set syncthing.replicaCount=3
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

In `s3` mode, the chart renders the bucket creation Job. The Job uses the same resolved S3 endpoint and creates `registry.s3.bucket` if it does not already exist.

## Filesystem Backend

Use this mode when the registry stores blobs on a mounted PVC/local PV.

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
    nodeName: nms-02
    reclaimPolicy: Retain
```

In `filesystem` mode, the chart renders PV/PVC templates and does not render the bucket creation Job.
`registry.sharedVolume` follows the same value shape used by stacked charts such as `netops-data`. `registry.sharedVolume.nodeName` is required for this mode: the PV uses it for node affinity, and the Deployment uses it as a node selector so all 3 registry replicas run on the same node and mount the same local shared volume.
