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
- Not changed yet: the `post-commit` hook in `/opt/zones.d/.git` (Rundeck, rebalance) still restarts
  all masters at the same time, and it is written only when `.git` does not exist yet.

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

