# Kafka Chart
This chart defines a Kafka cluster as Kubernetes objects and it depends on the Strimzi Kafka Operator, which is available at https://strimzi.io/docs/
In detail:
- The Kafka Object is created to define the Kafka cluster (replicas, version, listeners, config, etc.) and Zookeeper cluster (storage, resources, replicas, etc.)

## Tree level

```
+--- Chart.yaml : Chart information and dependencies (you can use as {{ .Chart }} variable on template files )
+--- README.md
+--- templates : define your template files in this folder
|   +--- kafka.yaml
|   +--- *.tpl : define your custom template variable here, and you can create new file .tpl
+--- values.yaml : define {{ .Values }} variable to use in template files
```

## How to use

- Install strimzi Operator:
    ```
    wget https://github.com/strimzi/strimzi-kafka-operator/releases/download/0.45.0/strimzi-cluster-operator-0.45.0.yaml
    sed 's/myproject/netflows/' strimzi-cluster-operator-0.45.0.yaml > strimzi.yaml
    kubectl apply -f strimzi.yaml
    ```

- Clone this Charts repo to /opt:
    ```
    cd /opt
    git clone https://github.com/svtechnmaa/charts.git
    ```

- Edit values.yaml at /opt/charts/kubernetes/kafka/values.yaml
- Start chart alone:
    ```
    helm install kafka /opt/charts/kubernetes/kafka \
        --namespace kafka \
        --create-namespace
    ```

- Uninstallation:
    ```
    helm uninstall kafka \
        --namespace kafka
    ```

