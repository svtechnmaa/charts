# Telegraf Helm chart

[Telegraf](https://github.com/influxdata/telegraf) is a plugin-driven server agent used for collecting and reporting metrics.

The Telegraf Helm chart uses the [Helm](https://helm.sh) package manager to bootstrap a Telegraf (`telegraf`) deployment on a [Kubernetes](http://kubernetes.io) cluster.

To see a list of available Telegraf plugins, see https://github.com/influxdata/telegraf/tree/master/plugins/.

## Prerequisites

- Helm v2 or later
- Kubernetes 1.4+ with beta APIs enabled

## Install the chart

1. Run the following command, providing a name for your Telegraf release:

   ```bash
   helm upgrade --install my-release .
   ```

   > **Tip**: `--install` can be shortened to `-i`.

   This command deploys Telegraf on the Kubernetes cluster using the default configuration. To find parameters you can configure during installation, see [Configure the chart](#configure-the-chart).

  > **Tip**: To view all Helm chart releases, run `helm list`.

## Uninstall the chart

To uninstall the `my-release` deployment, use the following command:

```bash
helm uninstall my-release
```

This command removes all Kubernetes components associated with the chart and deletes the release.

## Configure the chart

Plugins are configured as arrays of key/value dictionaries. Find configurable parameters, their descriptions, and their default values stored in `values.yaml`.

To configure the chart, do either of the following:

- Specify each parameter using the `--set key=value[,key=value]` argument to `helm upgrade --install`. For example:

  ```bash
  helm upgrade --install my-release \
    --set persistence.enabled=true \
      .
  ```

  This command enables persistence.

- Provide a YAML file that specifies the parameter values while installing the chart. For example, use the following command:

  ```bash
  helm upgrade --install my-release -f values.yaml influxdata/telegraf
  ```

  > **Tip**: Use the default [values.yaml](values.yaml).

## Additional Configuration

| Parameter                                    | Description                                                                                                | Default             |
|----------------------------------------------|------------------------------------------------------------------------------------------------------------|---------------------|
| `config.influxdb_host`                       | Define influxdb host (using an FQDN to point to another namespace eg: influxdb.namespace.svc.cluster.local | influxdb-relay      |
| `config.influxdb_port`                       | Define influxdb port                                                                                       | 9096                |
| `config.influxdb_database`                   | Define influxdb database                                                                                   | influxdb_nms        |
| `config.influxdb_user`                       | Define user access to influxdb database                                                                    |                     |
| `config.influxdb_password`                   | Define password  access to influxdb database                                                               |                     |
| `config.influxdb_skip_database_creation`     | Set to `false` if need to create new database                                                              | "true"              |

