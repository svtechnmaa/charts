# Preparation Chart

## Tree level

```
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- templates : define your template files in this folder
|   +--- default-pod-reader-rolebinding.yaml
|   +--- init-repo.yaml
|   +--- pod-reader-role.yaml
|   +--- secret.yaml
|   +--- _helpers.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files
```

## How to use

- Clone this Container repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/stacked_charts.git

- Edit values.yaml at /opt/charts/kubernetes/preparation
    - You can change value at values.yaml file to apply your case:
        - initRepo: repoList, fg_token
- Start chart alone:
    ```
    helm install preparation /opt/charts/kubernetes/preparation
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
    helm uninstall preparation
    ```

