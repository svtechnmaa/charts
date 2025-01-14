# Icinga2 Chart

## Tree level

```
+--- .helmignore : define list ignore expression
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- templates : define your template files in this folder
|   +--- configmap.yaml
|   +--- deployment-standalone.yaml
|   +--- service-headless.yaml
|   +--- service.yaml
|   +--- statefulset-distribute.yaml
|   +--- _helpers.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files
```


## How to use

- Clone this Container repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/stacked_charts.git

- Edit values.yaml at /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/icinga2
    - You can change value at values.yaml file to apply your case:
        - timezone
        - image: registry, repository, tag
        - replicaCount
        - service: type, port, externalIPs
        - influxdb_connection
        - ido_connection
        - notifications
- Start csv-view chart alone:
    ```
    helm install icinga2 /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/icinga2
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
    helm uninstall icinga2
    ```

