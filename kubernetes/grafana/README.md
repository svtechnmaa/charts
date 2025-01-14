# Grafana Chart

## Tree level

```
+--- .helmignore : define list ignore expression
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- files
|   +--- datasources
|   |   +--- audit_config.json
|   |   +--- grafana_thruk.json
|   |   +--- hardware_inventory.json
|   |   +--- IDO_icinga.json
|   |   +--- influxdb_nms.json
|   |   +--- report.json
+--- README.md
+--- templates : define your template files in this folder
|   +--- configmap-datasources.yaml
|   +--- deployment.yaml
|   +--- init-data.yaml
|   +--- service.yaml
|   +--- _helpers.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files

```


## How to use

- Clone this Container repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/stacked_charts.git

- Edit values.yaml at /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/grafana
    - You can change value at values.yaml file to apply your case:
        - timezone
        - image: registry, repository, tag
        - replicaCount
        - service: type, port, externalIPs
        - grafanaConfig: input your mysql connection and admin user
- Start chart alone:
    ```
    helm install debuger /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/grafana
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
    helm uninstall grafana
    ```

