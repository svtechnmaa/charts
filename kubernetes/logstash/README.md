# Logstash Chart

Multi-vendor syslog ingestion for the NMAA stack. Logstash terminates syslog listeners for
Juniper (Junos), H3C (Comware), Huawei (VRP) and Fortinet (FortiOS) devices, plus a Beats
listener for offline log bundles uploaded by Rundeck, normalises each vendor format with
grok/kv/translate filters, and writes to per-vendor Elasticsearch indices managed by the
`elasticsearch` chart's ILM policies and rollover aliases.

Image: `ghcr.io/svtechnmaa/logstash:{{ .Values.global.elasticsearch.version }}` (8.9.1).

## Tree level

```
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- charts : packaged dependencies (common-1.4.3.tgz)
+--- templates : define your template files in this folder
|   +--- logstash.yml : Deployment
|   +--- logstash-service.yml : Service (syslog listeners)
|   +--- general-config-cm.yml : logstash.yml, jvm.options, startup.options
|   +--- pipelines-cm.yml : pipelines.yml - the list of active pipelines
|   +--- patterns-cm.yml : shared grok pattern sets
|   +--- dictionary-cm.yml : facility/severity/client-mode/timezone lookup tables
|   +--- flat-facility-configmap.yml : eventname -> facility lookup (offline pipeline)
|   +--- flat-severity-configmap.yml : eventname -> severity lookup (offline pipeline)
|   +--- flat-type-configmap.yml : eventname -> type lookup (offline pipeline)
|   +--- online-log-cm.yml : Junos live syslog pipeline
|   +--- offline-log-cm.yml : Junos offline (Rundeck upload) pipeline
|   +--- h3c-cm.yml : H3C Comware pipeline
|   +--- huawei-cm.yml : Huawei VRP pipeline
|   +--- fortinet-cm.yml : Fortinet FortiOS pipeline
+--- values.yaml : define {{ .Values }} variable to use in template files
```

## What it deploys

| Template | Object | Name |
|---|---|---|
| `templates/logstash.yml` | Deployment | `logstash` (`common.names.fullname`) |
| `templates/logstash-service.yml` | Service | `logstash` (`.Chart.Name`) |
| `templates/general-config-cm.yml` | ConfigMap | `logstash-general-config` |
| `templates/pipelines-cm.yml` | ConfigMap | `logstash-pipelines` |
| `templates/patterns-cm.yml` | ConfigMap | `logstash-patterns` |
| `templates/dictionary-cm.yml` | ConfigMap | `logstash-dictionary` |
| `templates/flat-*-configmap.yml` | ConfigMap | `flat-facility`, `flat-severity`, `flat-type` |
| `templates/online-log-cm.yml` | ConfigMap | `online-log` |
| `templates/offline-log-cm.yml` | ConfigMap | `offline-log` |
| `templates/h3c-cm.yml` | ConfigMap | `h3c` |
| `templates/huawei-cm.yml` | ConfigMap | `huawei` |
| `templates/fortinet-cm.yml` | ConfigMap | `fortinet` |

The Deployment runs one `init-chown-data` initContainer (busybox) that creates
`/var/log/logstash` on the host and chowns it to `1000:1000`. Parse-failure files are
written there through a `hostPath` mount, so they survive pod restarts and are readable
from the node.

## Pipelines

All five pipelines are declared in `templates/pipelines-cm.yml` and run with
`pipeline.ecs_compatibility: disabled`.

| Pipeline id | Listener | Input plugin | Tag | Target index | Parse-failure sink |
|---|---|---|---|---|---|
| `svtechlab` | 5515 TCP + UDP | `tcp`, `udp` | `junos_log` | `first index.name` (e.g. `junos-log`) | `/var/log/logstash/login_failed_onlinelog_events-%{+YYYY-MM}` |
| `offline` | 5555 TCP | `beats` | `junos_offlog` | `offline-log` (hard-coded) | `/tmp/jun-offline-logstash_failed_parse_events-%{+YYYY-MM}` |
| `h3c` | 5513 UDP | `udp` | `h3c_log` | entry with prefix `h3c` | `/var/log/logstash/h3c_failed_log-%{+YYYY-MM}` |
| `huawei` | 5514 UDP | `udp` | `huawei_log` | entry with prefix `huawei` | `/var/log/logstash/huawei_failed_log-%{+YYYY-MM}` |
| `fortinet` | 5519 UDP | `udp` | `fortinet_log` | entry with prefix `fortinet` | `/var/log/logstash/fortinet_failed_log-%{+YYYY-MM}` |

Every pipeline stamps `received_at` (ingest time) and `received_from` (sender, from
`[host]`) before parsing.

### Field naming

The Junos pipelines emit `junos_*`-prefixed field names; the vendor pipelines emit
unprefixed names (`hostname`, `severitycode`, `severityname`, `msg`, `time`). Two
couplings constrain any renaming:

- **`kubernetes/juniper-syslog-api`** matches on `junos_eventname`, `junos_procsname` and
  `junos_severitycode`, and lists `junos_procsname`, `junos_msg`, `junos_eventname`,
  `junos_hostname`, `@timestamp`, `junos_severityname`, `junos_facilityname`. Renaming any
  of those breaks its alarm rules.
- **`kubernetes/elasticsearch/templates/bootstrap-index.yaml`** maps only `@timestamp`,
  `time` and `received_at` as `date` in the shared index template. Any other timestamp
  field name falls through to the `string_fields` dynamic template and is mapped as
  text+keyword for the life of the index.

`templates/online-log-cm.yml` captures the device timestamp as `time` and its `date`
filter has no `target`, so it also promotes `@timestamp`. `templates/offline-log-cm.yml`
still uses `junos_time` and its `date` filter targets `junos_time`, so `@timestamp` there
stays at ingest time.

### Index selection

Three different mechanisms are in use — worth knowing before changing
`global.elasticsearch.index.name`:

| Pipeline | Selection | Notes |
|---|---|---|
| `svtechlab` | `{{ first .Values.global.elasticsearch.index.name }}` | Depends on the Junos index being **first** in the list |
| `h3c`, `huawei`, `fortinet` | `range` + `hasPrefix "<vendor>"` | Site-specific names such as `h3c-svtechlab-log` still resolve |
| `offline` | literal `"offline-log"` | Ignores the values list entirely |

The vendor templates call Helm `fail` if no entry carries their prefix, e.g.

```
logstash/h3c-cm.yml: global.elasticsearch.index.name has no entry with prefix "h3c" (got [junos-log offline-log])
```


Index names must match the ILM policy, index template and rollover alias created by the
`elasticsearch` chart's `bootstrap-es-index` Job, which iterates over the same
`global.elasticsearch.index.name` list.

## Shared patterns and dictionaries

`logstash-patterns` is mounted at `/etc/logstash/patterns/`. Each ConfigMap key is one
pattern file; pipelines select one with `patterns_files_glob`.

| Key | Used by |
|---|---|
| `structured_log` | `svtechlab`, `h3c` — `PRIORITYCODE`, `TIMESTAMP_ISO8601`, `JUNHOSTNAME`, `PROCESSNAME`, `PROCESSID`, `EVENTNAME`, `SNMPINFO`, `MESSAGE`, `H3C_TIMESTAMP`, `H3C_MODULENAME` |
| `junos_off_*`, `junos_offlog_*`, `offlog_*`, `junos_fpc` | `offline` |
| `radius_log` | unused by the shipped pipelines |

`huawei` and `fortinet` use only built-in grok patterns and inline named captures, so they
need no entry here.

Dictionaries are projected together into `/etc/logstash/dictionary/` from four ConfigMaps:

| File | Source ConfigMap | Used by |
|---|---|---|
| `facilitycode.yml`, `severitycode.yml`, `client_mode.yml`, `timezone.yml` | `logstash-dictionary` | `svtechlab`, `offline`, `h3c`, `huawei` |
| `flat_facility.yml` | `flat-facility` | `offline` |
| `flat_severity.yml` | `flat-severity` | `offline` |
| `flat_type.yml` | `flat-type` | `offline` |

`fortinet` uses no dictionary at all — FortiOS sends the severity name directly as
`level=`, so deploying it needs no change to the shared dictionaries and cannot disturb the
running Junos pipelines.

## Prerequisites

- Kubernetes 1.19+, Helm 3
- The `elasticsearch` chart deployed in the same namespace. It provides:
  - the `es-basic-auth` Secret consumed by the Deployment's `ES_USER` / `ES_PASSWORD`
  - the `<clusterName>-es-<node>` Services used as Logstash output hosts
  - the ILM policies, index templates and rollover aliases created by `bootstrap-es-index`
- `ghcr-pull-secret` in the namespace (both the Deployment and the initContainer pull from
  `ghcr.io`)
- A writable `/var/log/logstash` on every node that can schedule the pod (`hostPath`)

## Configuration

### Chart values

| Parameter | Description | Default |
|---|---|---|
| `timezone` | `TZ` for the container; also the JVM default zone used by every `date` filter that has no explicit `timezone` | `Asia/Ho_Chi_Minh` |
| `replicas` | Intended replica count — **see gotcha 1**, the Deployment reads `replicaCount` | `2` |
| `heapSize` | `-Xms` / `-Xmx` in `jvm.options` | `1001m` |
| `init.image.registry` / `.repository` / `.tag` / `.pullPolicy` | initContainer image | `ghcr.io` / `svtechnmaa/busybox` / `1.33` / `IfNotPresent` |
| `service.type` | Service type | `LoadBalancer` |
| `service.annotations` | Rendered through `common.tplvalues.render` if set | unset |
| `affinity` | Pod affinity; the chart ships a `requiredDuringScheduling` anti-affinity on `app=logstash` | see `values.yaml` |
| `nodeSelector`, `tolerations`, `resources` | Standard pod scheduling / limits | unset |
| `securityContext.enabled`, `securityContext.fsGroup` | Pod `fsGroup` | `{}` (disabled) |

### Globals consumed

Supplied by the umbrella chart or the `elasticsearch` chart.

| Parameter | Used for |
|---|---|
| `global.elasticsearch.clusterName` | Builds output hosts `<clusterName>-es-<node>` |
| `global.elasticsearch.nodes[].name` | The node list those hosts are built from — **not defined in this chart's values.yaml** |
| `global.elasticsearch.version` | Logstash image tag |
| `global.elasticsearch.index.name` | Index selection (see above) |
| `global.elasticsearch.adminUser.name` / `.pass` | Credentials rendered into every pipeline's `elasticsearch` output |
| `global.logstash.loadBalancerIP` | Service `loadBalancerIP` |
| `global.externalIP` | Service `externalIPs` |
| `global.imageRegistry` | Overrides `ghcr.io` for the Logstash image |
| `global.timezone` | Overrides `.Values.timezone` via `common.timezone` |
| `global.ci` | Forces one replica via `common.replicas` |

## How to use

- Clone this repo:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/charts.git
    ```

- Edit `values.yaml` at `kubernetes/logstash`:
    - `timezone`, `heapSize`, `service.type`
    - `global.elasticsearch.clusterName` and `global.elasticsearch.index.name` — the index
      list must contain one entry per vendor prefix (`h3c`, `huawei`, `fortinet`) or the
      render fails
    - `global.logstash.loadBalancerIP`

- Start chart alone (requires `global.elasticsearch.nodes` to be supplied, see gotcha 2):
    ```
    helm install logstash kubernetes/logstash \
      --set-json 'global.elasticsearch.nodes=[{"name":"master"},{"name":"data"}]'
    ```

- Verify:
    - Check pods and service
        ```
        kubectl get pods -l app.kubernetes.io/name=logstash
        kubectl get svc logstash
        ```
    - Check that all five pipelines started
        ```
        kubectl logs deploy/logstash | grep -i "Pipeline started"
        ```
    - Query the monitoring API (basic auth `logstash`, password in `general-config-cm.yml`)
        ```
        kubectl exec deploy/logstash -- curl -s -u logstash:PASS localhost:9600/_node/stats/pipelines?pretty
        ```
    - Send a test event
        ```
        kubectl exec deploy/logstash -- bash -c 'echo "<190>Sep 25 09:20:34 2026 SW01 %%10SHELL/6/SHELL_LOGIN: test" > /dev/udp/127.0.0.1/5513'
        ```
    - Check for parse failures
        ```
        kubectl exec deploy/logstash -- ls -l /var/log/logstash/
        ```
    - Confirm the target index is a rollover alias, not a concrete index
        ```
        curl -sk -u elastic:PASS https://CLUSTERNAME-es-http:9200/_alias/h3c-log
        ```

- Apply a pipeline change:

    The pipeline configs are mounted with `subPath`, which Kubernetes never updates in
    place, and the Deployment carries no ConfigMap checksum annotation. A `helm upgrade`
    that changes only a pipeline will **not** restart the pod:
    ```
    helm upgrade logstash kubernetes/logstash
    kubectl rollout restart deploy/logstash
    ```

- Uninstallation:
    ```
    helm uninstall logstash
    ```

## Adding a vendor pipeline

1. Add any vendor-specific grok patterns to a new key in `templates/patterns-cm.yml`
   (skip if built-in patterns and inline named captures suffice).
2. Create `templates/<vendor>-cm.yml`: copy the `$newArray` + index-selector preamble from
   an existing vendor template and change the prefix and the `fail` message.
3. Add a `- pipeline.id: <vendor>` entry to `templates/pipelines-cm.yml`.
4. Add the volume and the `subPath` mount to `templates/logstash.yml`.
5. Add the listener port to `templates/logstash-service.yml`.
6. Add `<vendor>-log` to `global.elasticsearch.index.name` in **both**
   `kubernetes/logstash/values.yaml` and `kubernetes/elasticsearch/values.yaml`.
7. Re-run the `bootstrap-es-index` Job so the ILM policy, index template and rollover
   alias exist before the first event arrives.

