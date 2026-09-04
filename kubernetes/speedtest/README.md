# speedtest-helm

Helm chart for deploying the SVTECH Centralized Speedtester stack on Kubernetes (Django backend, React frontend, Nginx, Go/LibreSpeed server, EMQX, MQTT logger, scheduler/worker, Redis).

## Features
- Deploys all core components: Django backend, React frontend, Nginx, Go/LibreSpeed server, EMQX, MQTT logger, scheduler/worker, Redis
- Ingress with configurable TLS and path prefixes
- PVC-backed storage for static/media/frontend dist, MQTT logs, Redis, backups
- Dynamic environment and secret management via values overrides
- Customizable admin/user portal paths and MQTT endpoints
- Database backup automation
- External MariaDB, Grafana, and Chromium endpoints are configured through `values.yaml`

## Prerequisites
- Kubernetes cluster (v1.21+ recommended)
- Helm 3.x
- EMQX Operator
- Ingress controller
- Persistent storage class SeaweedFS (for PVCs)

### Install Prerequisites

Before installing the chart, ensure the following components are installed and configured in your Kubernetes cluster:

1. **EMQX Operator** (for MQTT management)
   - Docs: https://docs.emqx.com/en/emqx-operator/latest/getting-started/getting-started.html

2. **SeaweedFS StorageClass** (for PVCs)
   - Example install: https://github.com/seaweedfs/seaweedfs
   - Ensure your cluster has a `seaweedfs-storage` StorageClass and the SeaweedFS CSI driver installed.

After installing these prerequisites, proceed with the chart installation steps below.

## Installation

1. Clone the repository and navigate to the chart directory:
   ```sh
   git clone <your-repo-url>
   cd speedtest-helm
   ```

2. Review and edit `values.yaml` to fit your environment:
   - Set `global.frontendVip` for Ingress
   - Set `global.enableHttps` to `true` to enable HTTPS
   - Update database and MQTT settings as needed
   - Adjust image registry, repository, and tags for each component

3. Install the chart:
   ```sh
   helm install speedtest .
   # or upgrade
   helm upgrade --install speedtest .
   ```

4. Check deployment status:
   ```sh
   kubectl get pods,svc,ingress,pvc
   ```

## Configuration

All configuration is managed via `values.yaml`. Key sections:

- `global.frontendVip`: IP/DNS for ingress/LoadBalancer; 
- `global.enableHttps`: Enable HTTPS for Nginx and frontend
- `global.imageRegistry`: Optional registry override applied to all component images through the common chart image helper.
- `commonLabels` / `commonAnnotations`: Extra resource metadata rendered through the common chart template helper.
- `podLabels` / `podAnnotations`: Extra pod template metadata rendered through the common chart template helper.
- `replicaCounts`: Scale settings rendered through the common chart replica helper.
- `image`: Image settings for django, frontend, nginx, mqtt logger, scheduler, worker, tester server, and redis. Each image is configured as `registry`, `repository`, and `tag`; public Docker Hub images can use `registry: ""`.
- `pvc`: StorageClass/size for static, media, frontend dist, MQTT logs, Redis, backups.
- `db`: External MariaDB connection (host, port, user, password, name) and rendered Django DB secret name.
- `grafana`: External Grafana URLs and database settings consumed by the app.
- `chromium`: Optional external Chromium CDP URL for report screenshots.
- `mqtt`: Broker host/port/path and credentials (`brokerHost`, `brokerPort`, `brokerPath`, `username`, `password`).
- `vite`: Frontend MQTT client settings (`mqttBrokerProtocol`, `mqttBrokerHost`, `mqttBrokerPort`, `mqttBrokerPath`).
- `django`: Admin user, allowed hosts, static/media roots, CSRF trusted origins.
- `paths`: Service paths (default prefix `/speedtest`):
   - `staticDjango`: Static files path (default: /speedtest/static)
   - `mediaDjango`: Uploaded files path (default: /speedtest/media)
   - `adminPortal`: Django admin portal (default: /speedtest/admin/)
   - `backendApi`: REST API endpoint (default: /speedtest/api/)
   - `backendGraphQl`: GraphQL endpoint (default: /speedtest/graphql/)
   - `userPortal`: Frontend application (default: /speedtest/)
   - `speedtestServer`: LibreSpeed server (default: /speedtest/server)
   - `emqxDashboard`: EMQX dashboard (default: /speedtest/emqx/)

## Enabling HTTPS
Set `global.enableHttps: true` and ensure your Nginx/Ingress is configured for TLS. Update `vite.mqttBrokerProtocol` to `wss` and `mqtt.brokerPort` to `443` if using secure WebSockets.

## Backups
MariaDB backups are stored in the PVC defined in `pvc.backupDb`. Backup jobs can be scheduled via CronJob or run manually.

## Running the Init Data Job

To generate and execute only the Django initial data job (for admin/user setup and test data), change `global.runInitDataJob` to `true` in your `values.yaml`, then:

```sh
helm template . -s templates/init-data-job.yaml | kubectl apply -f -
```

This will render the `init-data-job.yaml` template with your current values and immediately create the job in your cluster. Make sure `global.runInitDataJob` is set to `true` in your `values.yaml`.

To check the job status:
```sh
kubectl get jobs
kubectl logs job/init-data-job
```

To re-run the job, you may need to delete the previous job first:
```sh
kubectl delete job init-data-job
```

You should delete the job after completed

## Upgrading
Update your `values.yaml` and run:
```sh
helm upgrade speedtest .
```

## Uninstall
```sh
helm uninstall speedtest
```

## Troubleshooting
- Check pod logs: `kubectl logs <pod-name>`
- Check service endpoints: `kubectl get svc`
- Ensure PVCs are bound: `kubectl get pvc`

## License
MIT
