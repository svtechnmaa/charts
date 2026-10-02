# conductor

Conductor OSS 3.31.0 — durable workflow engine (server + UI) for the NMAA stack.

One container runs both listeners:

| Port | Process | Purpose |
|------|---------|---------|
| `8080` | `conductor-server.jar` | REST/gRPC API, `/health`, `/actuator/prometheus` |
| `5000` | `nginx` | React UI at `/`, proxying `/api`, `/actuator`, `/swagger-ui` to `:8080` |

All state — execution store, task queues, search index, external payload storage — is in
PostgreSQL. No Elasticsearch or Kafka is needed; Redis is needed only for the HA
distributed workflow-execution lock (see below).

## Install standalone

```sh
helm -n nms install conductor charts/kubernetes/conductor --timeout 15m
```

This also deploys a single-node PostgreSQL cluster (repmgr + pgpool) named
`conductor-postgresql-*`, backed by a hostPath PV under `/data`.

Use an existing PostgreSQL instead:

```sh
helm -n nms install conductor charts/kubernetes/conductor \
  --set postgresqlHa.enabled=false \
  --set postgresql.host=my-pgpool \
  --set postgresql.database=conductor \
  --set postgresql.username=conductor \
  --set postgresql.password='<password>'
```

The database named in `postgresql.database` must already exist; Conductor's Flyway
migrations create the tables inside it but not the database itself.

## High availability

`replicaCount > 1` **requires** the distributed workflow-execution lock: without it two Deciders
evaluate the same workflow and double-schedule its tasks. The chart refuses to render the unsafe
combination rather than warn about it:

```sh
$ helm template c . --set replicaCount=2
Error: ... CONDUCTOR VALUES ERROR:
  - replicaCount is 2 but lock.enabled is false: set lock.enabled=true and lock.redisUrl=...
```

The full HA profile — two servers behind the lock, a 3-node Postgres cluster with repmgr quorum,
two pgpool front-ends, and a PodDisruptionBudget on each of the three:

```sh
helm -n nms install conductor . \
  --set replicaCount=2 \
  --set lock.enabled=true --set lock.redisUrl=redis://redis:6379 \
  --set podDisruptionBudget.create=true \
  --set 'postgresql-ha.postgresql.replicaCount=3' \
  --set 'postgresql-ha.postgresql.pdb.create=true' \
  --set 'postgresql-ha.postgresql.pdb.minAvailable=2' \
  --set 'postgresql-ha.pgpool.replicaCount=2' \
  --set 'postgresql-ha.pgpool.pdb.create=true'
```

In the NMAA stack these come from the inventory (`helm_config.conductor.*`), and are already set
in `k8s_nms_mariadb_replication.yml` and `k8s_nms_mariadb_galera_cluster.yml`.

Requirements and limits:

- **At least 3 schedulable worker nodes.** Each Postgres replica takes one `ReadWriteOnce`
  hostPath PV, and those PVs carry no `nodeAffinity`, so a replica rescheduled onto a different
  node starts from an empty directory and repmgr re-clones it from the primary. At
  `postgresql-ha.postgresql.replicaCount: 1` the same event is data loss instead.
- **Two pgpool replicas, not one.** Every JDBC connection goes through the
  `conductor-postgresql-pgpool` Service; a single pgpool pod is a SPOF in front of an otherwise-HA
  database.
- Keep `replicaCount * postgresql.maxPoolSize` under pgpool's connection ceiling.
- The lock's Redis (`lock.redisUrl`) is the stack's shared single-pod, non-persistent `redis`. If
  it is down, servers cannot take the lock and workflow evaluation stalls until it returns —
  state is not corrupted.
- `podDisruptionBudget.create=true` is ignored at one *effective* replica, including any render
  with `global.ci=true` (which forces replicas to 1), so it can never block a node drain.
- `worker.replicaCount` must stay `1` in every profile: the worker is the single writer to the
  shared zones.d and gitlist git repos. The chart refuses anything higher.
- `postgresql-ha.{postgresql,pgpool}.pdb.create` must move together with that component's
  `replicaCount`. The chart refuses to render a budget that could never permit a voluntary
  eviction (for example `minAvailable: 2` with one replica), because such a budget blocks
  `kubectl drain` indefinitely rather than protecting anything.

## Exposure

The Service is `ClusterIP` and named `conductor`. The UI bundle's base path is fixed at
build time (`VITE_PUBLIC_URL`), so it cannot be served under a sub-path such as
`/conductor`. In the NMAA stack it is published on the ingress controller's backend VIP
via TCP passthrough:

```yaml
ingress-nginx:
  service:
    portBackend:
      - name: conductor
        port: 5000
        targetPort: 5000
        protocol: TCP
```

→ UI at `http://<global.backendVip>:5000`, API at `http://<global.backendVip>:5000/api`.
In-cluster clients should use `http://conductor:8080/api`.

## Verify

```sh
kubectl -n nms rollout status deploy/<release>-conductor --timeout=10m
kubectl -n nms exec deploy/<release>-conductor -- curl -sf http://localhost:8080/health
kubectl -n nms exec deploy/<release>-conductor -- curl -sf http://localhost:8080/api/metadata/workflow
```

`/health` returns a Spring Boot health document; `/api/metadata/workflow` returns `[]` on a
fresh install.

## Worker

`worker.enabled=true` deploys ONE worker that serves every converted job: `device_discovery`,
`device_rediscovery`, `device_delete`, `device_backup` and the shared `icinga2_reload` task.
The image, `ghcr.io/svtechnmaa/svtech_conductor_worker`, is built from
`stacked_charts/images/svtech_conductor_worker` and holds the **runtime only** (python,
ansible, the conductor SDK, the network libraries, `ping`/`snmp`/`git`/`ssh`). The code is
SVTECH-Junos-Automation, mounted the way Rundeck mounts it: the image's CMD runs
`Python-Development/conductor_workflows/workers/run_workers.py` from the mount, which loads
every `workers/*_workers.py`, so a new job needs no new Deployment. A code change that needs
a new library or tool must also update that image folder (`requirements.txt` or the
Dockerfile's apt line) and bump `worker.image.tag`.

- **Job settings** are `worker.jobEnv.<job>` maps. Each becomes a ConfigMap
  `<fullname>-worker-env-<job>` loaded with `envFrom`; a change rolls the pod. A new job with
  settings adds one block. The render refuses a key set by two jobs, or one the Deployment
  sets itself.
- **icinga2 reload targets** (`ICINGA2_RELOAD_URLS`) are derived from the release:
  `https://<release>-icinga2-master-<i>.icinga2-headless.<namespace>.svc.cluster.local:5665`
  for `i < worker.icinga2.masterReplicaCount`. Keep that equal to `icinga2.master.replicaCount`,
  or set `worker.icinga2.reloadUrls` explicitly.
- **Volumes**: shared volumes whose `shareFor` lists `conductor-worker` — in the stack,
  `automation-repo-volume` (the code, mounted **read-only**), `icinga2-zones-volume` (host
  config) and `gitlist-data-volume` (backups). The render refuses a worker with no volume at
  `/opt/SVTECH-Junos-Automation`: the pod could not start without its code.
- **icinga2 API password**: read from a Secret, not set in the Deployment. The chart
  creates `<fullname>-worker` (key `ICINGA2_API_PASSWORD`) from `worker.icinga2.apiPassword`;
  set `worker.icinga2.existingSecret` to use a Secret you create instead.
- **Runs as root** (`worker.podSecurityContext`): the stack's shared volumes are hostPath PVs,
  where `fsGroup` is not applied, and their folders are root-owned.

## Tests

```sh
bash charts/kubernetes/conductor/tests/render.sh
```

Renders the chart in several configurations and asserts on the output. No cluster needed.

## Values

See `values.yaml` — every key is commented. The most-used ones:

| Key | Default | Purpose |
|---|---|---|
| `replicaCount` | `1` | Server replicas; `>1` needs `lock.enabled=true` (enforced) |
| `lock.enabled` | `false` | Distributed workflow-execution lock; mandatory above one replica |
| `lock.redisUrl` | `redis://redis:6379` | Lock backend; the stack's shared `redis` |
| `podDisruptionBudget.create` | `false` | PDB for the server; ignored at one effective replica |
| `image.tag` | `3.31.0` | Overridden in CI via `image_chart_mapping.yml` |
| `postgresqlHa.enabled` | `true` | Deploy the bundled PostgreSQL cluster |
| `postgresql-ha.postgresql.replicaCount` | `1` | PostgreSQL nodes; `3` for HA (odd number = repmgr quorum) |
| `postgresql-ha.postgresql.pdb.create` | `false` | PDB for the Postgres StatefulSet (`minAvailable: 2`) |
| `postgresql-ha.pgpool.replicaCount` | `1` | pgpool front-ends; `2` for HA, otherwise a SPOF |
| `postgresql-ha.pgpool.pdb.create` | `false` | PDB for the pgpool Deployment |
| `postgresqlHa.persistence.size` | `8Gi` | Per-node volume size |
| `postgresqlHa.persistence.hostPath` | `/data` | hostPath root for the PVs |
| `postgresql-ha.persistence.storageClass` | `conductor-postgresql` | Must equal `postgresqlHa.persistence.storageClass` — the chart refuses a mismatch |
| `postgresql-ha.persistence.size` | `8Gi` | Must equal `postgresqlHa.persistence.size` |
| `conductorConfig.extraProperties` | `[]` | Raw property lines appended to the config file |
| `registerWorkflows.enabled` | `false` | Post-install Job registering NMAA workflow metadata; enable once the stack's automation release carries `conductor_workflows/`. Runs on `worker.image` (no image of its own) with the repo mounted read-only |
| `worker.enabled` | `false` | The NMAA worker for every converted job (see *Worker*) |
| `worker.icinga2.masterReplicaCount` | `1` | icinga2 masters `icinga2_reload` posts to |
| `worker.icinga2.reloadUrls` | `[]` | Explicit reload URLs; replace the derived list |
| `worker.icinga2.apiPassword` | `icingaAdmin` | Goes into the Secret `<fullname>-worker` |
| `worker.icinga2.existingSecret` | `""` | Your own Secret with key `ICINGA2_API_PASSWORD`; the chart then creates none |
| `worker.jobEnv` | `shared`, `backup` | One ConfigMap per job |
| `worker.podSecurityContext` | `runAsUser: 0` | Root, for the root-owned hostPath volumes |
