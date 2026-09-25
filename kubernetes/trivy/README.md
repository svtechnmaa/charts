# Trivy Server Helm Chart

Wrapper chart triển khai Trivy server chính thức cùng một Redis standalone dùng làm shared cache cho nhiều Trivy replica.

## Kiến trúc

```text
Trivy clients
      |
      v
Service trivy-server:4954
      |
  +---+---+
  |       |
Trivy-0 Trivy-1
  \       /
   \     /
Service trivy-server-redis:6379
      |
Redis Deployment (1 replica, ephemeral)
```

Vulnerability DB nằm trong PVC riêng của từng Trivy pod. Redis chỉ giữ cache kết quả/layer dùng chung.

## Thành phần

| Thành phần | Phiên bản |
|---|---:|
| Trivy chart | `0.24.0` |
| Trivy | `0.72.0` |
| Common library chart | `1.4.3` |
| Redis image | `ghcr.io/svtechnmaa/redis:7.2.3` |

Redis được render trực tiếp bằng `Deployment + Service`, không dùng Redis subchart.

## Cài đặt

```bash
helm dependency build .

helm upgrade --install trivy-server . \
  --namespace trivy \
  --create-namespace
```

## GHCR private

Nếu Redis image là private:

```bash
kubectl -n trivy create secret docker-registry ghcr-pull-secret \
  --docker-server=ghcr.io \
  --docker-username=svtechnmaa \
  --docker-password="$GHCR_TOKEN"
```

Khai báo pull secret:

```yaml
global:
  imagePullSecrets:
    - ghcr-pull-secret
```

Không cần pull secret nếu package GHCR là public.

## Values chính

| Key | Mặc định | Ý nghĩa |
|---|---:|---|
| `global.imageRegistry` | `ghcr.io` | Registry mặc định cho Redis image |
| `global.imagePullSecrets` | `[]` | Secret dùng để pull private image |
| `trivy.replicaCount` | `2` | Số Trivy server |
| `trivy.image.registry` | `ghcr.io` | Trivy image registry |
| `trivy.image.repository` | `svtechnmaa/trivy` | Trivy image repository |
| `trivy.image.tag` | `0.72.0` | Trivy image tag |
| `trivy.trivy.serverToken` | `""` | Tắt xác thực token |
| `trivy.trivy.cache.redis.ttl` | `24h` | TTL của shared cache |
| `redis.replicaCount` | `1` | Số Redis pod |
| `redis.image.repository` | `svtechnmaa/redis` | Redis image repository |
| `redis.image.tag` | `7.2.3` | Redis image tag |
| `redis.service.port` | `6379` | Redis Service port |

Các value khác của Trivy chart vẫn được override dưới nhánh `trivy.*`.

Trivy Service mặc định là `ClusterIP` và không sử dụng token. Chỉ nên dùng cấu hình này trong cluster nội bộ đáng tin cậy; không expose Service bằng LoadBalancer, NodePort hoặc Ingress.

## Redis

Redis hiện được thiết kế như cache ephemeral:

- Một `Deployment` replica.
- `ClusterIP` Service, không expose ra ngoài cluster.
- Không PVC hoặc AOF persistence.
- Không password.
- Không ConfigMap.
- Không NetworkPolicy.
- Readiness và liveness probe dùng `redis-cli ping`.

Khi Redis pod restart, cache bị mất và được xây dựng lại. Vulnerability DB của Trivy không bị ảnh hưởng. Trong cluster không trusted, nên bổ sung authentication hoặc NetworkPolicy.

## Kiểm tra

```bash
helm lint .
helm template trivy-server . --namespace trivy
```

Test Trivy:

```bash
trivy image \
  --server http://trivy-server.trivy.svc:4954 \
  alpine:3.22
```
