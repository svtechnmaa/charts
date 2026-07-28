# maxscale

Helm chart deploying a MariaDB MaxScale pod in front of a MariaDB/Galera
backend (or an external MariaDB/Galera cluster), plus a `mariadb` ClusterIP
Service exposing one port per configured router.

## What this chart deploys

- A single `Deployment` running the `svtechnmaa/svtech_maxscale` image,
  with an init container that waits until the backend database(s) accept
  connections before MaxScale itself starts.
- A `mariadb` `Service` (ClusterIP, or with `externalIPs` set) with one
  port per entry in `routers`, so each router is reachable as its own
  MySQL-protocol endpoint.
- Router/monitor configuration is driven entirely by environment
  variables derived from `values.yaml` — there is no static
  `maxscale.cnf` shipped with the chart. Monitors are **not** declared in
  values at all; the image auto-derives them from probing the backends
  (see [How monitors work](#how-monitors-work)).

## Values reference

| Key | Type | Default | Description |
|---|---|---|---|
| `replicaCount` | int | `2` | MaxScale pod replica count. |
| `image.registry` | string | `ghcr.io` | Registry for the MaxScale image. |
| `image.repository` | string | `svtechnmaa/svtech_maxscale` | MaxScale image repository. |
| `image.tag` | string | `v1.0.10` | MaxScale image tag. `v1.0.10`+ is required for the `routers[*].servers` / `routers[*].params` fields below — older tags ignore those env vars but keep working via the legacy path. |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy. |
| `init.image.*` | object | `svtechnmaa/mysql:8.2.0` | Image used by the `wait-for-mariadb` init container. |
| `service.externalIPs` | list | `[]` | Reserved for future use (see `global.externalIP` for the currently-wired external IP). |
| `maxscaleConfig.server` | list | 3 internal `dbNN://host:port` entries | Backend server list, **used only** when `global.mariadb-galera.enabled` is `false` (external database mode). Ignored when the bundled `mariadb-galera` subchart is enabled. |
| `maxscaleConfig.monitor_user` | string | `maxscale_monitor` | DB user MaxScale uses to monitor backend health. |
| `maxscaleConfig.monitor_user_password` | string | `maxscale@123` | Password for `monitor_user`. Override in production. |
| `routers` | list | one `rwsplit` entry (see below) | List of MaxScale router services to expose. Each entry becomes a router inside the container and a port on the `mariadb` Service. |
| `routers[*].id` | string | — | Router identifier. Becomes the `MXS_<id>_*` env var prefix and the Service port name. |
| `routers[*].type` | string | — | MaxScale router type: `readwritesplit`, `readconnroute`, or `schemarouter`. |
| `routers[*].port` | int | — | Container port the router listens on. |
| `routers[*].servicePort` | int | — | Port exposed on the `mariadb` Service for this router. |
| `routers[*].servers` | list of string | *(unset)* | Optional. Scopes this router to a backend subset (`MXS_<id>_SERVERS`). Omit to attach every backend. Requires image `v1.0.10`+. |
| `routers[*].params` | map | *(unset)* | Optional. Free-form router tuning parameters, rendered as `MXS_<id>_<KEY>` (key upper-cased) per entry. See the image README's [router parameter reference](https://github.com/svtechnmaa/stacked_charts/blob/master/images/svtech_maxscale/README.md#router-parameter-reference) for the full list per router type. Requires image `v1.0.10`+. |
| `routers[*].options` | string | *(unset)* | Legacy free-text `MXS_<id>_ROUTER_OPTIONS` string. Still supported for backward compatibility; prefer `params.router_options` in new configs. |

## Router configuration

- **`readwritesplit`** — splits reads and writes across the backend
  subset, sending writes to the current primary and load-balancing reads
  across replicas/other nodes. Pick this for a standard OLTP application
  connection that shouldn't have to know about the topology.
- **`readconnroute`** — routes every connection to servers matching a
  fixed role (`master`, `slave`, or a combination via
  `params.router_options`), without read/write splitting. Pick this for a
  dedicated write endpoint that follows failover, or a read-only
  offload endpoint for reporting/analytics traffic.
- **`schemarouter`** — routes by schema/database name rather than by
  role, and is the only router type allowed to span two different
  topologies in `servers` (e.g. one Galera cluster and one standalone
  node). Pick this when different schemas live on different backend
  topologies and the application connects through one endpoint.

## Examples

The same three recipes are also available as commented-out blocks
directly in `values.yaml`, ready to copy-paste over the default `routers:`
list.

**1. rwsplit with causal reads** — use this when the application needs
read-your-writes consistency against a Galera cluster (an immediate read
after a write must see that write, even if it lands on a different node):

```yaml
routers:
  - id: rwsplit
    type: readwritesplit
    port: 4006
    servicePort: 3306
    params:
      causal_reads: universal
```

**2. readconnroute pinned to master** — use this when you want a single
write endpoint that always resolves to the current primary, transparently
following failover:

```yaml
routers:
  - id: write
    type: readconnroute
    port: 4007
    servicePort: 3307
    params:
      router_options: master
```

**3. Multi-router mix** — use this when OLTP traffic needs read/write
splitting, reporting traffic should be offloaded to replicas, and a
separate schema-routed endpoint needs to span two topologies:

```yaml
routers:
  - id: rwsplit
    type: readwritesplit
    port: 4006
    servicePort: 3306
    servers: [g1, g2, g3]
  - id: readoffload
    type: readconnroute
    port: 4008
    servicePort: 3308
    servers: [g1, g2, g3]
    params:
      router_options: slave
  - id: schema
    type: schemarouter
    port: 4009
    servicePort: 3309
    servers: [g1, m1]
```

## How monitors work

Chart values never declare monitors. When any `routers[*].servers` is
set, the image probes the declared backends at boot, groups them into
topologies (Galera cluster, replication chain, or standalone node), and
creates exactly the monitors each router's server subset needs —
reusing one monitor per topology across routers that share it. If no
router sets `servers`, the pod falls back to the original legacy
behaviour: one monitor covering every backend, shared by every router.
See the image README's
[How auto-monitoring works](https://github.com/svtechnmaa/stacked_charts/blob/master/images/svtech_maxscale/README.md#how-auto-monitoring-works)
section for the full topology-detection and guard-rail details.

