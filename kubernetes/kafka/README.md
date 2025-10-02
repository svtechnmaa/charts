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

- Edit values.yaml at /opt/charts/kubernetes/kafka/values.yaml with the pre configuration parameter is listed:

| Parameter                                               | Description                                                                                                                           | Default    |
|---------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------|------------|
| `global.kafka.topic`                              | Define Kafka topic, must defined in global to reuse in another charts (like akvorado,...)                                             | clickhouse |
| `kafka.config.offsets_topic_replication_factor`         | Specifies the replication factor for the internal `__consumer_offsets` topic                                                          | 3          |
| `kafka.config.transaction_state_log_replication_factor` | Sets the replication factor for the internal `__transaction_state` topic                                                              | 2          |
| `kafka.config.transaction_state_log_min_isr`            | Specifies the minimum number of in-sync replicas (ISR) required for the `__transaction_state` topic before a producer can write to it | 2          |
| `kafka.config.socket.request.max.bytes`                 | Defines the maximum size (in bytes) of a request that the broker will accept over the network.                                        | 419430400  |
| `kafka.config.default_replication_factor`               | Sets the default replication factor for new topics created without explicitly specifying a replication factor                         | 3          |
| `kafka.config.min_insync_replica`                       | Specifies the minimum number of in-sync replicas required for a topic’s partitions before a producer can write to them                | 2          |
| `kafka.config.log_retention_hours`                      | Determines how long (hours) Kafka retains messages in topic logs before deleting them                                                 | 24         |

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

