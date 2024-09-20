# Thruk Chart

## Tree level

```
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- templates : define your template files in this folder
|   +--- configmap-index-html.yaml
|   +--- configmap-proxy.yaml
|   +--- configmap-thruk-local.yaml
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

- Edit values.yaml at /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/thruk
    - You can change value at values.yaml file to apply your case:
        - timezone
        - image: registry, repository, tag
        - replicaCount
        - service: type, port, externalIPs
        - thrukConfig
- Start chart alone:
    ```
    helm install thruk /opt/SVTECH_Projects_Container/kubernetes/nms_project/charts/thruk
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
    helm uninstall thruk
    ```

