# Elastalert Chart
This chart is a clone of this ones: https://github.com/jertel/elastalert2/tree/master/chart/elastalert2
In this cloned version, we modified the deployment and added configurations to run a UI alongside the Elastalert backend within the same pod.
In detail:
- The configmap named config-ui is added to allow administrators to configure the Elastalert UI.
- The deployment has been modified to mount the added configmap, and the configuration for rules, SMTP, and alerts is mounted as files using hostPath.
- The values.yaml file has been updated to include a configuration block that enables administrators to configure the Elastalert UI.
## Tree level

```
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- templates : define your template files in this folder
|   +--- deployment.yaml
|   +--- config-ui.yaml: 
|   +--- config.yaml
|   +--- ...
|   +--- *.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files
```

## How to use

- Clone this Charts repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/charts.git

- Edit values.yaml at /opt/charts/kubernetes/elastalert-ui, the ref is from original git repo: https://github.com/jertel/elastalert2/tree/master/chart/elastalert2
  But here, the addition configuration parameter is listed:
## Additional Configuration

| Parameter                                    | Description                                                                                                | Default                             |
|----------------------------------------------|------------------------------------------------------------------------------------------------------------|-------------------------------------|
| `elastalertUIConfig.useHostPathRule`         | Define if using Rule mount from hostPath or not                                                            | true                                |
| `elastalertUIConfig.hostPathRuleDir`         | Folder in K8s host used to mount the Rule folder                                                           |                                     |
| `elastalertUIConfig.hostPathAlertDir`        | Folder in K8s host used to mount the Alert folder                                                          |                                     |
| `elastalertUIConfig.elastalertUIConfigPath`  | File in the pod containing the configuration for ElastAlert UI                                             | /opt/elastalert/config-ui.yaml      |
| `elastalertUIConfig.ruleTestFile`            | File in the pod containing the rule for testing                                                            | /opt/elastalert/test_rule.yaml      |
| `elastalertUIConfig.elastalertConfigPath`    | File in the pod containing the configuration for ElastAlert backend                                        | /opt/elastalert/config.yaml         |
| `elastalertUIConfig.alertDir`                | File in the pod containing Alerts                                                                          | /opt/elastalert/alerts              |
| `elastalertUIConfig.templatePath`            | File in the pod containing templates for ElastAlert UI                                                     | /opt/elastalert/code/template       |
| `elastalertUIConfig.esConnection`            | Configuration defining the connection to the target Elasticsearch cluster used to apply rules              |                                     |

- Start chart alone:
    ```
    helm install elasalert-ui /opt/charts/kubernetes/elastalert-ui
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
    helm uninstall elastalert-ui
    ```

