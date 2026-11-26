# Icinga2 Report Chart

## Tree level

```
+--- .helmignore : define list ignore expression
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- files
|   +--- auth
|   +--- configuration
|   |   +--- configuration.yml
|   |   +--- graphql_configuration.yml
|   |   +--- report_template
|   |   |   +--- mobifone-template.yml
|   +--- datasources.yml
|   +--- icinga2-report.conf
+--- README.md
+--- templates : define your template files in this folder
|   +--- configmap-auth.yaml
|   +--- configmap-configuration.yaml
|   +--- configmap-datasources.yaml
|   +--- configmap-icinga2-report-conf.yaml
|   +--- configmap-report-template.yaml
|   +--- deployment.yaml
|   +--- service.yaml
|   +--- _helpers.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files
```


## Upgrade notes

### icinga2 > 1.8.24, icingaweb > 1.7.10: Redis / Icinga DB in the master pods

- `global.redis.*` and `global.icingadb.enabled` are no longer read by `icinga2` and `icingaweb`:
    - Every icinga2 master pod always runs its own `redis` and `icingadb` containers; icinga2 and
      icingadb always use `localhost:6379` (Icinga DB HA: one Redis + one icingadb per master).
    - icingaweb always uses `redis1` = Redis of master-0, `redis2` = Redis of master-1, through the
      per-pod DNS of `icinga2-headless`.
    - An environment that pointed icinga2 / icingaweb at an external Redis (`global.redis.host`),
      or disabled Icinga DB (`global.icingadb.enabled: false`), is switched to the in-pod Redis
      without warning on upgrade.
- `redis.persistence` (hostPath `/data/redis`) is removed: Redis keeps an AOF in an emptyDir, so
  its data survives a restart of the redis container but not a new pod (icinga2 dumps the config
  into Redis again at start).
- The icingaweb health-check CronJob (`cronjob.*` in icingaweb values) and its
  ServiceAccount / Role (`pods/exec`) are removed; per-container probes replace it.
- icingaweb writes its env into `redis.ini` only on the first install (the ini files live on a
  shared volume). On a running cluster, set `redis1` / `redis2` in `redis.ini` by hand.

### icinga2 > 1.8.24: config reload and satellite zones

Why: an Icinga2 node that is restarted from outside while it copies a config sync into
`/var/lib/icinga2/api/zones` keeps a half-copied zone. Icinga2 copies `.timestamp` before the
`.conf` files, so every later sync of that zone is skipped and the node misses hosts until its
`api/zones` is removed. Only the config master (Lease holder) restarts because of a config change;
the other nodes restart themselves after they received the sync.

- The `post-commit` hook of `/opt/zones.d/.git` (Rundeck, Ansible, icinga2-rebalance) no longer
  restarts the masters. It writes `/opt/zones.d/.reload-request` (`<epoch> <commit> <host>`); the
  config master waits until that commit reached its node (Syncthing), validates, restarts itself,
  verifies the running hosts and writes `/opt/zones.d/.reload-result`
  (`<commit> ok|validate-failed|reload-failed <time> <pod> <detail>`). Tools that need the result
  read that file. See `master.election` in values.yaml.
- Every master start rewrites the hook (only when its content differs) and adds `.reload-request*`
  and `.reload-result*` to `/opt/zones.d/.gitignore`, so a running cluster gets the new hook with
  the rollout of the master StatefulSet.
- Removed: the `auto-reload-satellite` CronJob and the `cronjob.*` values. It restarted every
  satellite from outside once a week.
- `master_zones.conf` always lists the Endpoint of every master ordinal `0..master.replicaCount-1`
  and is rewritten with the same content on every master start; the master preStop hook that
  removed the stopping pod's Endpoint and `master/<pod>.conf` host is removed. Deleting both
  masters at once no longer leaves a host whose endpoint is gone (master-0 failed to validate and
  `OrderedReady` never created master-1). A master that is down stays declared and its host shows
  DOWN. Host files of ordinals `>= replicaCount` are removed on the next master start. The first
  rollout to this version still runs the old preStop once per pod.
- Do not restart a follower master or a satellite from outside (`restart-process`,
  `reload-satellite`) right after a config change; it reloads by itself once the sync is copied.
- Satellites: a sidecar keeps the two satellites of a zone listed in each other's zone config
  (`satellite.zoneWatcher`). It adds a peer at once, removes a peer only when it is missing from
  DNS for `removeAfterSeconds`, and reloads icinga2 only when neither the satellite nor a master
  started less than `reloadQuietSeconds` ago.
- `satellite.headlessService.publishNotReadyAddresses` (default `false`): `true` keeps restarting
  or crashlooping satellites in the DNS of `icinga2-satellite-headless`, so neither the zone
  watcher nor icinga2-rebalance reacts to a satellite restart. Enable it only with an icinga2 image
  whose icinga2-rebalance health-checks the satellites (`rebalance.satelliteHealth`, env
  `REBALANCE_*`); an older icinga2-rebalance reads the satellites from DNS only and would keep the
  hosts of a zone whose satellites are all broken.

## How to use

- Clone this Container repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/stacked_charts.git

- Edit values.yaml at /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/icinga2-report
    - You can change value at values.yaml file to apply your case:
        - timezone
        - image: registry, repository, tag
        - replicaCount
        - service: type, port, externalIPs
        - datasources
- Start chart alone:
    ```
    helm install icinga2-report /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/icinga2-report
    ```

- Verify:
    - Check Pods
        ```
        kubectl get pods
        ```
    - Check service
        ```
        kubectl get svc
        ```

- Uninstallation:
    ```
    helm uninstall icinga2-report
    ```

