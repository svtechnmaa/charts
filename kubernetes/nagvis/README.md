# Nagvis Chart

## Tree level

```
+--- .helmignore : define list ignore expression
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- templates : define your template files in this folder
|   +--- deployment.yaml
|   +--- service.yaml
|   +--- _helpers.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files
```


## How to use

- Clone this Container repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/stacked_charts.git

- Edit values.yaml at /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/nagvis
    - You can change value at values.yaml file to apply your case:
        - timezone
        - image: registry, repository, tag
        - replicaCount
        - service: type, port, externalIPs
        - nagvisConfig: backend infomations, icinga2 connection
- Start chart alone:
    ```
    helm install nagvis /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/nagvis
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
    helm uninstall nagvis
    ```

