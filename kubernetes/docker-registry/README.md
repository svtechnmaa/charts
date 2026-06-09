# Docker Private Registry — SeaweedFS S3 Backend

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [How It Works — Full Flow](#how-it-works--full-flow)
  - [Push Flow (skopeo copy to registry)](#1-push-flow-skopeo-copy-to-registry)
  - [Pull Flow (containerd pull image)](#2-pull-flow-containerd-pull-image)
  - [Registry ↔ SeaweedFS S3 Interaction](#3-registry--seaweedfs-s3-interaction)
- [Inspect Registry via curl](#inspect-registry-via-curl)
- [Inspect Registry via SeaweedFS GUI](#inspect-registry-via-seaweedfs-gui)
- [Pull Images using crictl](#pull-images-using-crictl)
- [Data Layout on SeaweedFS](#data-layout-on-seaweedfs)

---

## Architecture Overview

### Component Diagram

Three distinct services involved — each has a different role:

```
  +-----------------------------------------------------------------------+
  |  Kubernetes Cluster                                                   |
  |                                                                       |
  |  [ skopeo ]          : CLI tool — copies images between registries    |
  |  [ containerd ]      : Container runtime — pulls images for pods      |
  |  [ Docker Registry ] : Service — exposes image API on port 5000       |
  |  [ SeaweedFS S3 ]    : Service — stores actual image data (blobs)     |
  |                                                                       |
  +-----------------------------------------------------------------------+

                              PUSH (skopeo)
   +----------+   1. copy image   +-----------------+   S3 API   +-------------+
   |  ghcr.io |◄──────────────────| skopeo          |            |             |
   |  source  |   (download blob) |                 |            |  SeaweedFS  |
   +----------+                   | runs on any K8s |            |  S3         |
                                  | node or host    |            |  :8333      |
                2. push blob      |                 |            |             |
                ─────────────────►| Docker Registry |────────────►  bucket:    |
                                  | ns: registry    |            |  registry   |
                                  | :5000           |            |             |
                                  +-----------------+            +-------------+

                              PULL (containerd — triggered via crictl)

   +--------------+                                                +-------------+
   | crictl       |                                                |             |
   | pull image   |                                                |  SeaweedFS  |
   +--------------+                                                |  S3 :8333   |
          |                                                        |             |
          ▼                                                        |  bucket:    |
   +--------------+   Step 1. GET manifest   +-----------------+   |  registry   |
   |              |─────────────────────────►| Docker Registry |──►|             |
   | containerd   |◄─────────────────────────| ns: registry    |◄─ |             |
   | (each node)  |   manifest JSON          | :5000           |   |             |
   |              |                          |                 |   |             |
   |              |   Step 2. GET blob       |                 |   |             |
   |              |─────────────────────────►|                 |   |             |
   |              |◄─────────────────────────|                 |   |             |
   |              |   307 Redirect           +-----------------+   |             |
   |              |   Location: http://seaweedfs-s3:8333/...       |             |
   |              |                                                |             |
   |              |   Step 3. download blob directly (bypass Registry)           |
   |              |───────────────────────────────────────────────►|             |
   |              |◄───────────────────────────────────────────────|             |
   |              |   blob content (raw stream)                    |             |
   |              |                                                |             |
   |              |   (repeat Step 2→3 for each layer in manifest) |             |
   +--------------+                                                +-------------+

  -----------------------------------------------------------------------
  Docker Registry : registry-docker-registry-service.registry.svc.cluster.local:5000
  SeaweedFS S3    : seaweedfs-s3.seaweedfs.svc.cluster.local:8333
  containerd alias: private.registry → points to Docker Registry :5000
  -----------------------------------------------------------------------
```

> **Key point:** When pulling, containerd downloads blobs **directly from SeaweedFS** via a 307 redirect — the Registry only handles the manifest and redirect, it does not proxy the blob data itself. This keeps Registry resource usage low.

---

### Flow Diagram

#### PUSH — skopeo copies image from ghcr.io into private registry

```
   ghcr.io        skopeo          Docker Registry       SeaweedFS S3
  ──────────     ─────────        ───────────────       ────────────
      │               │                  │                    │
      │  Step 1       │                  │                    │
      │  Download     │                  │                    │
      │  manifest  ◄──│                  │                    │
      │  & blobs      │                  │                    │
      │               │                  │                    │
      │               │  Step 2          │                    │
      │               │  HEAD blob       │  HeadObject        │
      │               │  (already exist?)│──────────────────► │
      │               │◄─────────────────│◄────── 404 ────────│
      │               │  404 not found   │  (blob missing)    │
      │               │                  │                    │
      │               │  Step 3          │                    │
      │               │  POST            │  PutObject         │
      │               │  (init session)  │  (create temp file)│
      │               │─────────────────►│──────────────────► │
      │               │◄─────────────────│◄────── 200 ────────│
      │               │  202 + uuid      │                    │
      │               │                  │                    │
      │               │  Step 4          │                    │
      │               │  PATCH × N       │  PutObject         │
      │               │  (upload chunks) │  (write each chunk)│
      │               │─────────────────►│──────────────────► │
      │               │◄─────────────────│◄────── 200 ────────│
      │               │  202 accepted    │  (repeat per chunk)│
      │               │                  │                    │
      │               │  Step 5          │                    │
      │               │  PUT             │  CopyObject        │
      │               │  (finalize blob) │  _uploads/ → blobs/│
      │               │─────────────────►│──────────────────► │
      │               │◄─────────────────│◄────── 200 ────────│
      │               │  201 created     │  (blob committed)  │
      │               │                  │                    │
      │               │  Step 6          │                    │
      │               │  PUT manifest    │  PutObject         │
      │               │─────────────────►│──────────────────► │
      │               │◄─────────────────│◄────── 200 ────────│
      │               │  201 created     │  (manifest saved)  │
  ───────────────────────────────────────────────────────────────────────────    
```

#### PULL — containerd pulls image from private registry

```
   containerd      Docker Registry       SeaweedFS S3
  ────────────     ───────────────       ────────────
       │                  │                    │
       │  Step 1          │                    │
       │  GET manifest    │  GetObject         │
       │─────────────────►│──────────────────► │
       │◄─────────────────│◄───────────────────│
       │  manifest JSON   │                    │
       │                  │                    │
       │  Step 2          │                    │
       │  HEAD blob       │  HeadObject        │
       │  (check size)    │──────────────────► │
       │◄─────────────────│◄───────────────────│
       │  200 + size      │                    │
       │                  │                    │
       │  Step 3          │                    │
       │  GET blob        │                    │
       │─────────────────►│                    │
       │◄─────────────────│                    │
       │  307 Redirect    │                    │
       │  Location: http://seaweedfs-s3:8333/. │
       │                  │                    │
       │  Step 4 — bypass Registry, go direct  │
       │──────────────────────────────────────►│
       │◄──────────────────────────────────────│
       │  blob content (raw stream)            │
       │                  │                    │
       │  (repeat Step 2→4 for each layer)     │
  ────────────────────────────────────────────────────────────
```

---

## How It Works — Full Flow

### 1. Push Flow (skopeo copy to registry)

```
skopeo copy docker://ghcr.io/svtechnmaa/arangodb:3.12.2 \
            docker://registry:5000/svtechnmaa/arangodb:3.12.2
```

```
skopeo                       Registry                        SeaweedFS S3
  │                              │                                │
  │─── GET  /v2/                 │                                │
  │         ← 200 OK             │                                │
  │                              │                                │
  │  ① Fetch source manifest     │                                │
  │─── GET ghcr.io/manifests/tag │                                │
  │         ← manifest list      │                                │
  │           (multi-arch)       │                                │
  │                              │                                │
  │  ② Check each blob exists    │                                │
  │─── HEAD /v2/.../blobs/sha256:111
  │         ← 404 (not found)   ─┼──► HEAD s3://registry/.../sha256:111
  │                              │         ← 404 (not found)      │
  │                              │                                │
  │  ③ Init upload session       │                                │
  │─── POST /v2/.../blobs/uploads/
  │                             ─┼──► PUT s3://_uploads/<uuid>/data (empty)
  │         ← 202 + uuid        ─┼◄── 200 OK                      │
  │                              │                                │
  │  ④ Upload blob in chunks     │                                │
  │─── PATCH /uploads/<uuid>     │                                │
  │    [chunk 1: 0→128MB]       ─┼──► PUT s3://_uploads/<uuid>/data
  │         ← 202               ─┼◄── 200 OK                      │
  │─── PATCH /uploads/<uuid>     │                                │
  │    [chunk 2: 128→256MB]     ─┼──► PUT s3://_uploads/<uuid>/data
  │         ← 202               ─┼◄── 200 OK                      │
  │                              │                                │
  │  ⑤ Finalize upload           │                                │
  │─── PUT /uploads/<uuid>       │                                │
  │    ?digest=sha256:111       ─┼──► CopyObject                  │
  │                              │    src:  _uploads/<uuid>/data  │
  │                              │    dest: blobs/sha256:111      │
  │                              │─── Delete _uploads/<uuid>/data │
  │         ← 201 Created        │                                │
  │                              │                                │
  │  ⑥ Push manifest             │                                │
  │─── PUT /v2/.../manifests/tag │                                │
  │                             ─┼──► PUT s3://.../manifests/tag  │
  │         ← 201 Created        │                                │
  ───────────────────────────────────────────────────────────────────────────
```

---

### 2. Pull Flow (containerd pull image)

```
crictl pull private.registry/svtechnmaa/arangodb:3.12.2
```

```
containerd                   Registry                        SeaweedFS S3
  │                              │                                │
  │  ① Fetch manifest            │                                │
  │─── GET /v2/.../manifests/3.12.2
  │                             ─┼──► GET s3://.../manifests/3.12.2
  │         ← manifest JSON     ─┼◄── blob content                │ 
  │                              │                                │
  │  ② Check each layer          │                                │
  │─── HEAD /v2/.../blobs/sha256:111
  │                             ─┼──► HEAD s3://.../blobs/sha256:111
  │         ← 200 + size        ─┼◄── 200 OK                      │
  │                              │                                │
  │  ③ Download blob             │                                │
  │─── GET /v2/.../blobs/sha256:111
  │                              │                                │
  │         ← 307 Redirect       │  (redirect: disable: false)    │
  │    Location: http://seaweedfs-s3:8333/registry/...            │
  │                              │                                │
  │─────────────────────────────────────────────────────────────► │
  │  GET http://seaweedfs-s3:8333/registry/.../blobs/sha256:111   │
  │         ← blob content (streamed directly from SeaweedFS)     │
  │◄───────────────────────────────────────────────────────────── │
  │                              │                                │
  │  ④ Repeat for each layer     │                                │
  ───────────────────────────────────────────────────────────────────────────
```

> **Note:** `redirect: disable: false` → containerd downloads blobs **directly from SeaweedFS** instead of going through the Registry. The Registry only returns a redirect URL and does not proxy the blob data — this significantly reduces CPU and memory usage on the Registry pod.

---

### 3. Registry ↔ SeaweedFS S3 Interaction

The Registry never stores data locally. Every read/write goes through the S3 driver to SeaweedFS. The table below maps each Registry API action to the exact S3 API call it triggers:

| Triggered by | Registry API | S3 API called | What happens on SeaweedFS |
|---|---|---|---|
| skopeo HEAD blob | `HEAD /v2/.../blobs/<digest>` | `HeadObject` | Check if blob file exists in `blobs/sha256/` |
| skopeo POST init | `POST /v2/.../blobs/uploads/` | `PutObject` (empty) | Create empty temp file at `_uploads/<uuid>/data` |
| skopeo PATCH chunk | `PATCH /v2/.../blobs/uploads/<uuid>` | `PutObject` (append) | Write chunk data into `_uploads/<uuid>/data` |
| skopeo PUT finalize (blob < 1GB) | `PUT /v2/.../blobs/uploads/<uuid>` | `CopyObject` (single call) | Move `_uploads/<uuid>/data` → `blobs/sha256/<digest>` in one operation |
| skopeo PUT finalize (blob > 1GB) | `PUT /v2/.../blobs/uploads/<uuid>` | `CreateMultipartUpload` → `CopyPart` × N → `CompleteMultipartUpload` | Move `_uploads/<uuid>/data` → `blobs/sha256/<digest>` in multiple parts |
| skopeo PUT manifest | `PUT /v2/.../manifests/<tag>` | `PutObject` | Write manifest JSON to `repositories/<name>/_manifests/` |
| containerd GET manifest | `GET /v2/.../manifests/<tag>` | `GetObject` | Read manifest JSON from `repositories/<name>/_manifests/` |
| containerd GET blob | `GET /v2/.../blobs/<digest>` | — (redirect) | Registry returns `307 Redirect` to pre-signed SeaweedFS URL; containerd downloads directly |
| curl DELETE image | `DELETE /v2/.../manifests/<digest>` | `DeleteObject` | Remove manifest file — blob files remain until garbage collection runs |
| curl GET catalog | `GET /v2/_catalog` | `ListObjects` | List all directories under `repositories/` |

---

## Inspect Registry via curl

### Catalog & Tags

```bash
# List all repositories (images) available in the registry
curl -s http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/_catalog | jq .

# Example response:
# {
#   "repositories": [
#     "svtechnmaa/arangodb",
#     "svtechnmaa/redis",
#     ...
#   ]
# }
```

```bash
# List all tags of a specific image
curl -s http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/<image_name>/tags/list | jq .

# Example:
curl -s http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/svtechnmaa/arangodb/tags/list | jq .

# Example response:
# {
#   "name": "svtechnmaa/arangodb",
#   "tags": ["3.12.2"]
# }
```

---

### Manifest

```bash
# Get the manifest of an image (returns manifest list if multi-arch)
curl -s \
  -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/<image_name>/manifests/<tag> | jq .

# Example:
curl -s \
  -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/svtechnmaa/arangodb/manifests/3.12.2 | jq .
```

```bash
# Get the SHA256 digest of a manifest (needed for deletion)
curl -sI \
  -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
  http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/<image_name>/manifests/<tag> \
  | grep -i "docker-content-digest"

# Example response:
# docker-content-digest: sha256:a1b2c3d4...
```

---

### Blob

```bash
# Check whether a blob exists and get its size
curl -sI \
  http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/<image_name>/blobs/<digest>

# Example:
curl -sI \
  http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/svtechnmaa/arangodb/blobs/sha256:abc123...

# Response if blob exists:
# HTTP/1.1 200 OK
# Content-Length: 52428800
# Docker-Content-Digest: sha256:abc123...

# Response if blob does not exist:
# HTTP/1.1 404 Not Found
```

---

### Registry Health & Info

```bash
# Check if registry is alive
curl -s http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/
# Expected response: {} → registry is healthy

# Check registry API version
curl -sI http://registry-docker-registry-service.registry.svc.cluster.local:5000/v2/ \
  | grep -i "docker-distribution-api-version"
# Expected response: docker-distribution-api-version: registry/2.0
```
---

## Inspect Registry via SeaweedFS GUI

1. Expose the SeaweedFS filer as a NodePort service:
```bash
kubectl -n seaweedfs expose svc/seaweedfs-filer \
  --name=seaweedfs-filer-nodeport \
  --type=NodePort \
  --port=8888 \
  --target-port=8888

# Get the assigned NodePort
kubectl -n seaweedfs get svc seaweedfs-filer-nodeport
# Example output:
# NAME                       TYPE       CLUSTER-IP   PORT(S)          
# seaweedfs-filer-nodeport   NodePort   10.96.x.x    8888:3XXXX/TCP   
```

2. Open in browser:
```
http://<node_ip>:<node_port>/buckets/registry/docker/registry/v2/repositories/
```

Data layout on SeaweedFS:
```
buckets/registry/docker/registry/v2/
├── blobs/
│   └── sha256/
│       ├── 11/sha256:111...   ← layer blob (tar.gz compressed filesystem)
│       ├── 22/sha256:222...   ← layer blob (tar.gz compressed filesystem)
│       └── ab/sha256:abc...   ← config blob (image metadata JSON)
│
└── repositories/
    └── svtechnmaa/
        ├── arangodb/
        │   ├── _manifests/    ← manifest index by tag and digest
        │   ├── _layers/       ← links pointing back to blobs/
        │   └── _uploads/      ← temporary upload dir (empty when no upload is running)
        └── redis/
            ├── _manifests/
            ├── _layers/
            └── _uploads/
```

---

## Pull Images using crictl

```bash
crictl pull private.registry/svtechnmaa/<image_name>:<tag>
```

> **`private.registry`** is an alias configured in containerd that points to `registry-docker-registry-service.registry.svc.cluster.local:5000`.

Configuration at `/etc/containerd/certs.d/private.registry/hosts.toml`:

```toml
server = "http://registry-docker-registry-service.registry.svc.cluster.local:5000"

[host."http://registry-docker-registry-service.registry.svc.cluster.local:5000"]
  capabilities = ["pull", "resolve"]
  skip_verify = true
```

> **Why this is required:** containerd defaults to HTTPS for all registries. This registry runs on plain HTTP — the `hosts.toml` file explicitly tells containerd to allow HTTP and skip TLS verification for this alias.

