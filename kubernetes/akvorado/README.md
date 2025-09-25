# Akvorado Chart

This Helm chart deploys Akvorado, a flow collector and exporter for network traffic analytics, on Kubernetes. It is designed to integrate with ClickHouse for scalable storage and querying.

## Features

- Deploys Akvorado as a Kubernetes Deployment.
- Configurable resource requests and limits.
- Integrates with ClickHouse for data storage.
- Supports custom environment variables and configuration.

## Prerequisites

- Kafka cluster
- ClickHouse cluster

## Installation

1. Clone the charts repository:
    ```bash
    cd /opt
    git clone https://github.com/svtechnmaa/charts.git
    ```

2. Edit `/opt/charts/kubernetes/akvorado/values.yaml` to configure Akvorado parameters, such as ClickHouse connection details, resource limits, and flow sources.

Key parameters in `values.yaml`:

| Parameter                              | Description                                                                                               | Default       |
|----------------------------------------|-----------------------------------------------------------------------------------------------------------|---------------|
| `global.kafka.topic`                   | Define Kafka topic, must defined in global to reuse in another charts (like kafka,...)                    | ""            |
| `global.kafka.partition`               | Define Kafka partition, must defined in global to reuse in another charts (like kafka,...)                | 1             |
| `global.kafka.replicationFactor`       | Define Kafka replication factor, must defined in global to reuse in another charts (like kafka,...)       | 1             |
| `inlet.config.providers`               | Define device subnet and community for collecting additional information                                  | `::/0-public` |
| `geoip.env`                            | Define ipinfo db for getting geoip data and update time                                                   | {}            |
| `clickhouse`                           | Define clickhouse cluster for connecting database                                                         | {}            |


3. Install the Akvorado chart:
    ```bash
    helm install akvorado /opt/charts/kubernetes/akvorado \
        --namespace akvorado \
        --create-namespace
    ```

## Uninstallation

To remove Akvorado:

```bash
helm uninstall akvorado \
    --namespace akvorado
```

## References

- [Akvorado Documentation](https://github.com/akvorado/akvorado)
- [ClickHouse Operator](https://docs.altinity.com/clickhouse-operator)
- [Kafka Strimzi](https://strimzi.io/)
