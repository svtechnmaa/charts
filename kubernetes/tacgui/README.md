<!--- app-name: Tacgui -->

# Helm chart for Tacgui

Tacgui is a modular developed and distributed under the GNU General Public License.

## TL;DR

```bash
$ helm install my-release svtechnmaa/svtech_tacacsgui
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+

## Installing the Chart

To install the chart with the release name `my-release` on `my-release` namespace:

```bash
$ helm repo add startechnica https://startechnica.github.io/apps
$ helm install my-release svtechnmaa/svtech_tacacsgui --namespace my-release --create-namespace
```

These commands deploy Tacgui on the Kubernetes cluster in the default configuration.

> **Tip**: List all releases using `helm list -A`

## Uninstalling the Chart

To uninstall/delete the `my-release` deployment:

```bash
$ helm delete my-release --namespace my-release
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Parameters

### Global parameters

| Name                      | Description                                     | Value |
| ------------------------- | ----------------------------------------------- | ----- |
| `global.imageRegistry`    | Global Docker image registry                    | `""`  |
| `global.imagePullSecrets` | Global Docker registry secret names as an array | `[]`  |
| `global.storageClass`     | Global StorageClass for Persistent Volume(s)    | `""`  |
| `global.basePath`         | Global base path for the application            | `""`  |

### Common parameters

| Name                | Description                                                          | Value           |
| ------------------- | -------------------------------------------------------------------- | --------------- |
| `kubeVersion`       | Force target Kubernetes version (using Helm capabilities if not set) | `""`            |
| `nameOverride`      | String to partially override tacgui.fullname                         | `""`            |
| `namespaceOverride` | String to partially override tacgui.namespace                        | `""`            |
| `fullnameOverride`  | String to fully override adminer.fullname                            | `""`            |
| `commonLabels`      | Labels to add to all deployed objects                                | `{}`            |
| `commonAnnotations` | Annotations to add to all deployed objects                           | `{}`            |
| `clusterDomain`     | Default Kubernetes cluster domain                                    | `cluster.local` |
| `extraDeploy`       | Array of extra objects to deploy with the release                    | `[]`            |

### Tacgui Image parameters

| Name                     | Description                                                                                                                   | Value                         |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------- |
| `image.registry`         | Tacgui image registry                                                                                                         | `ghcr.io`                     |
| `image.repository`       | Tacgui image repository                                                                                                       | `svtechnmaa/svtech_tacacsgui` |
| `image.tag`              | Tacgui image tag (immutable tags are recommended)                                                                             | `v1.0.1`                      |
| `image.pullPolicy`       | Tacgui image pull policy                                                                                                      | `IfNotPresent`                |
| `image.pullSecrets`      | Specify docker-registry secret names as an array                                                                              | `ghcr-pull-secret`            |
| `image.pullAccount`      | Specify docker-registry user login name                                                                                       | `""`                          |
| `image.pullPassword`     | Specify docker-registry user login token                                                                                      | `""`                          |
| `image.debug`            | Specify if debug logs should be enabled                                                                                       | `false`                       |
| `architecture`           | Tacgui architecture (`standalone` or `replication`)                                                                           | `standalone`                  |
| `configuration`          | Tacgui Configuration. Auto-generated based on other parameters when not specified                                             | `""`                          |
| `configurationConfigMap` | ConfigMap with the Tacgui configuration files. The value is evaluated as a template. | `""`                          |
| `existingConfigmap`      | Name of existing ConfigMap with Tacgui configuration                                                                          | `""`                          |
| `extraStartupArgs`       | Extra default startup args                                                                                                    | `""`                          |
| `initConfigs`            | to initialize the configuration files                                                                                         | `true`                        |
| `command`                | Override default container command on Tacgui container(s) (useful when using custom images)                                   | `[]`                          |
| `args`                   | Override default container args on Tacgui container(s) (useful when using custom images)                                      | `[]`                          |
| `lifecycleHooks`         | for the Tacgui container(s) to automate configuration before or after startup                                                 | `{}`                          |
| `hostAliases`            | Add deployment host aliases                                                                                                   | `[]`                          |
| `configuration`          | Tacgui configuration to be injected as ConfigMap                                                                              | `""`                          |

### Tacgui Deployment parameters

| Name                                        | Description                                                                               | Value            |
| ------------------------------------------- | ----------------------------------------------------------------------------------------- | ---------------- |
| `replicaCount`                              | Desired number of cluster nodes                                                           | `1`              |
| `updateStrategy.type`                       | updateStrategy for Tacgui Master StatefulSet                                              | `RollingUpdate`  |
| `podLabels`                                 | Extra labels for Tacgui pods                                                              | `{}`             |
| `podAnnotations`                            | Annotations for Tacgui pods                                                               | `{}`             |
| `podAffinityPreset`                         | Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`       | `""`             |
| `podAntiAffinityPreset`                     | Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`  | `soft`           |
| `nodeAffinityPreset.type`                   | Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard` | `""`             |
| `nodeAffinityPreset.key`                    | Node label key to match. Ignored if `affinity` is set.                                    | `""`             |
| `nodeAffinityPreset.values`                 | Node label values to match. Ignored if `affinity` is set.                                 | `[]`             |
| `affinity`                                  | Affinity for Tacgui pods assignment                                                       | `{}`             |
| `nodeSelector`                              | Node labels for Tacgui pods assignment                                                    | `{}`             |
| `tolerations`                               | Tolerations for Tacgui pods assignment                                                    | `[]`             |
| `topologySpreadConstraints`                 | Topology Spread Constraints for Tacgui pods assignment                                    | `{}`             |
| `priorityClassName`                         | Priority class for Tacgui pods assignment                                                 | `""`             |
| `schedulerName`                             | Name of the k8s scheduler (other than default)                                            | `""`             |
| `podManagementPolicy`                       | podManagementPolicy to manage scaling operation of Tacgui pods                            | `""`             |
| `containerPorts.tacplus`                    | Tacplus Engine container port                                                             | `49`             |
| `containerPorts.webui`                      | Tacgui WebUI container port                                                               | `4443`           |
| `podSecurityContext.enabled`                | Enable security context for Tacgui pods                                                   | `false`          |
| `podSecurityContext.fsGroup`                | Group ID for the mounted volumes' filesystem                                              | `101`            |
| `podSecurityContext.runAsUser`              | User ID for the mounted volumes' filesystem                                               | `101`            |
| `containerSecurityContext.enabled`          | Tacgui container securityContext                                                          | `false`          |
| `containerSecurityContext.runAsUser`        | User ID for the Tacgui container                                                          | `101`            |
| `containerSecurityContext.capabilities.add` | capabilities for the Tacgui container                                                     | `["SYS_PTRACE"]` |
| `containerSecurityContext.runAsNonRoot`     | Set Controller container's Security Context runAsNonRoot                                  | `true`           |
| `resources.limits`                          | The resources limits for Tacgui containers                                                | `{}`             |
| `resources.requests`                        | The requested resources for Tacgui containers                                             | `{}`             |
| `revisionHistoryLimit`                      | Maximum number of revisions that will be maintained in the Deployment                     | `3`              |
| `extraVolumes`                              | Optionally specify extra list of additional volumes to the Tacgui pod(s)                  | `[]`             |
| `extraVolumeMounts`                         | Optionally specify extra list of additional volumeMounts for the Tacgui container(s)      | `[]`             |
| `initContainers`                            | Add additional init containers for the Tacgui pod(s)                                      | `[]`             |
| `sidecars`                                  | Add additional sidecar containers for the Tacgui pod(s)                                   | `[]`             |

### persistentVolumeClaim Parameters

| Name                                     | Description                                                                     | Value               |
| ---------------------------------------- | ------------------------------------------------------------------------------- | ------------------- |
| `persistentVolumeClaim.enabled`          | Enable persistentVolumeClaim on Tacgui replicas using a `PersistentVolumeClaim` | `false`             |
| `persistentVolumeClaim.existingClaim`    | Name of an existing `PersistentVolumeClaim` for Tacgui primary replicas         | `""`                |
| `persistentVolumeClaim.subPath`          | Subdirectory of the volume to mount at                                          | `""`                |
| `persistentVolumeClaim.mountPath`        | Path to mount the volume at                                                     | `""`                |
| `persistentVolumeClaim.storageClassName` | Tacgui persistent volume storage Class                                          | `""`                |
| `persistentVolumeClaim.volumeMode`       | Tacgui persistent volume mode                                                   | `Filesystem`        |
| `persistentVolumeClaim.volumeName`       | Tacgui persistent volume name                                                   | `""`                |
| `persistentVolumeClaim.annotations`      | Tacgui persistent volume claim annotations                                      | `{}`                |
| `persistentVolumeClaim.accessModes`      | Tacgui persistent volume access Modes                                           | `["ReadWriteMany"]` |
| `persistentVolumeClaim.size`             | Tacgui persistent volume claim size to request                                  | `2Gi`               |
| `persistentVolumeClaim.selector`         | Selector to match an existing Persistent Volume                                 | `{}`                |

### persistentVolume Parameters

| Name                                | Description                                                                              | Value               |
| ----------------------------------- | ---------------------------------------------------------------------------------------- | ------------------- |
| `persistentVolume.enabled`          | Enable creation of a Persistent Volume                                                   | `false`             |
| `persistentVolume.capacity`         | Persistent Volume size                                                                   | `3Gi`               |
| `persistentVolume.accessModes`      | Persistent Volume access Modes                                                           | `["ReadWriteMany"]` |
| `persistentVolume.hostPath`         | Persistent Volume host path, If you use global.basePath, the path will be exclusive Path | `/var/tmp/tacgui`   |
| `persistentVolume.nfs.server`       | NFS server                                                                               | `""`                |
| `persistentVolume.nfs.path`         | NFS path                                                                                 | `""`                |
| `persistentVolume.annotations`      | Persistent Volume annotations                                                            | `{}`                |
| `persistentVolume.storageClassName` | Persistent Volume storage Class                                                          | `""`                |
| `persistentVolume.reclaimPolicy`    | Persistent Volume reclaim policy                                                         | `Retain`            |

### External Database Parameters

| Name                                         | Description                                                             | Value         |
| -------------------------------------------- | ----------------------------------------------------------------------- | ------------- |
| `externalDatabase.host`                      | Database host                                                           | `mariadb`     |
| `externalDatabase.port`                      | Database port number                                                    | `3306`        |
| `externalDatabase.user`                      | Non-root username for Tacgui                                            | `tgui_user`   |
| `externalDatabase.password`                  | Password for the non-root username for Tacgui                           | `juniper@123` |
| `externalDatabase.database`                  | Tacgui database name                                                    | `tacgui`      |
| `externalDatabase.logDatabase`               | Tacgui log database name                                                | `tgui_log`    |
| `externalDatabase.existingSecret`            | Name of an existing secret resource containing the database credentials | `""`          |
| `externalDatabase.existingSecretPasswordKey` | Name of an existing secret key containing the database credentials      | `""`          |

### Traffic Exposure Parameters

| Name                                    | Description                                                                                                                      | Value                    |
| --------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------ |
| `service.type`                          | Tacgui Kubernetes service type                                                                                                   | `LoadBalancer`           |
| `service.ports.tacplus`                 | Tacgui Kubernetes service port                                                                                                   | `49`                     |
| `service.ports.webui`                   | Tacgui Kubernetes service port                                                                                                   | `4443`                   |
| `service.nodePorts.tacplus`             | Tacgui Kubernetes service node port                                                                                              | `""`                     |
| `service.nodePorts.webui`               | Tacgui Kubernetes service node port                                                                                              | `""`                     |
| `service.clusterIP`                     | Tacgui Kubernetes service clusterIP IP                                                                                           | `""`                     |
| `service.loadBalancerIP`                | Tacgui loadBalancerIP if service type is `LoadBalancer`                                                                          | `""`                     |
| `service.ipFamilyPolicy`                | Tacgui Kubernetes service ipFamilyPolicy policy                                                                                  | `SingleStack`            |
| `service.externalTrafficPolicy`         | Enable client source IP preservation                                                                                             | `Local`                  |
| `service.allocateLoadBalancerNodePorts` | Allow users to disable node ports for Service Type=LoadBalancer. This is useful for                                              | `false`                  |
| `service.loadBalancerClass`             | Enables to use a load balancer implementation other than the cloud provider default.                                             | `""`                     |
| `service.loadBalancerSourceRanges`      | Address that are allowed when Tacgui service is LoadBalancer                                                                     | `[]`                     |
| `service.extraPorts`                    | Extra ports to expose (normally used with the `sidecar` value)                                                                   | `[]`                     |
| `service.annotations`                   | Provide any additional annotations which may be required                                                                         | `{}`                     |
| `service.sessionAffinity`               | Session Affinity for Kubernetes service, can be "None" or "ClientIP"                                                             | `None`                   |
| `service.sessionAffinityConfig`         | Additional settings for the sessionAffinity                                                                                      | `{}`                     |
| `ingress.enabled`                       | Enable ingress record generation for Tacgui                                                                                      | `false`                  |
| `ingress.pathType`                      | Ingress path type                                                                                                                | `ImplementationSpecific` |
| `ingress.apiVersion`                    | Force Ingress API version (automatically detected if not set)                                                                    | `""`                     |
| `ingress.hostname`                      | Default host for the ingress record                                                                                              | `tacgui.local`           |
| `ingress.path`                          | Default path for the ingress record                                                                                              | `/`                      |
| `ingress.annotations`                   | Additional annotations for the Ingress resource. To enable certificate autogeneration, place here your cert-manager annotations. | `{}`                     |
| `ingress.tls`                           | Enable TLS configuration for the host defined at `ingress.hostname` parameter                                                    | `false`                  |
| `ingress.selfSigned`                    | Create a TLS secret for this ingress record using self-signed certificates generated by Helm                                     | `false`                  |
| `ingress.extraHosts`                    | An array with additional hostname(s) to be covered with the ingress record                                                       | `[]`                     |
| `ingress.extraPaths`                    | An array with additional arbitrary paths that may need to be added to the ingress under the main host                            | `[]`                     |
| `ingress.extraTls`                      | TLS configuration for additional hostname(s) to be covered with this ingress record                                              | `[]`                     |
| `ingress.secrets`                       | Custom TLS certificates as secrets                                                                                               | `[]`                     |
| `ingress.ingressClassName`              | IngressClass that will be be used to implement the Ingress (Kubernetes 1.18+)                                                    | `""`                     |
| `ingress.extraRules`                    | Additional rules to be covered with this ingress record                                                                          | `[]`                     |
