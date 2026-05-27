# 📦 MageAI Helm Chart

This Helm chart deploys the **Mage AI Stack** for building and managing data pipelines. It includes components such as the webserver, scheduler, Redis, Traefik, and optional services. It supports external PostgreSQL, shared volumes (e.g., SeaweedFS), scheduling, ingress, and custom volume mounts.

---

## 🚀 Prerequisites

- Helm v3 or newer  
- A running Kubernetes cluster  
- Network access to GitHub Container Registry (`ghcr.io`)  
- An existing **PostgreSQL** instance (required):  
  - We use this Helm chart to deploy PostgreSQL HA on Kubernetes:  
    https://github.com/svtechnmaa/charts/tree/feature/mage-ai/kubernetes/postgresql-ha  
- If MageAI runs on a VM, configure the VM’s CPU type as `host`  
- PersistentVolume (PV) and PersistentVolumeClaim (PVC) for MageAI must be provisioned using the provided values file and the `shared-volume` chart:  
  https://github.com/svtechnmaa/charts/tree/main/kubernetes/shared-volume
---

## ⚙️ Required Configuration

### 🔧 Global Settings

- Set `pullCode: true` to pull pipeline code from `https://github.com/svtechnmaa/netlogic_ETL_pipelines.git` into the shared volume.
- If `pullCode: false`, manually mount the pipeline code (e.g., for offline environments).
- Leaving `hostPath` empty may result in missing or overwritten pipeline code.
- Set `hostPathPV.enabled: true` to use hostPath volumes.
- Set `storageClass: seaweedfs-storage` to use SeaweedFS.
- Provide GitHub credentials (`user`, `token`) for private repo access.

```yaml
global:
  mageai:
    pullCode: true
    projectName: "NMAA_pipelines"

  github:
    user: ""
    token: ""
    fg_token: ""

  basePath: /opt/shared/
  sharedVolume:
    enabled: true

  hostPathPV:
    enabled: true

### 🔑 Image Pull Token

You **must provide** a secret to pull container images:

- In the full NMAA stack, this secret is already applied.

- If deploying this chart independently, manually create the pull secret and fill the secret name.

```yaml
imagePullSecrets:
  - name: "ghcr-pull-secret"
```

### External PostgreSQL configuration:
Set ```postgresqlExternalHost``` to match the service name of your PostgreSQL statefulset. Auth values must match the database credentials.
```yaml
postgresqlExternal:
  enabled: true
  postgresqlExternalHost: "postgresql-ha-pgpool" 
  auth:
    username: postgres
    password: ""
    database: "etl_nmaa"
```

## 🚀 Step to launch:
Step 1: Install postgresql-ha as external database for mageai: https://github.com/svtechnmaa/charts/tree/feature/mage-ai/kubernetes/postgresql-ha
       If redeploy the postgresql-ha and change the config of headless service, make sure you delete all pvc, pv and data to remove cache.
       
Step 2: Fill the value file according the above note.

Step 3: Install the shared volume using the Helm chart: https://github.com/svtechnmaa/charts/tree/main/kubernetes/shared-volume

Using value.yaml from the MageAI chart.
       
       helm install shared-volume . --values /opt/test/mage-ai/charts/kubernetes/mage-ai/values.yaml

Step 4: Ensure that if you're using hostPath, the pipeline folder mounted to the PV is synchronized using Syncthing.
       
Step 5: You can install MageAI in any namespace, but make sure that:

- The imagePullSecrets resource exists in the target namespace.
- If PostgreSQL is in a different namespace, update postgresqlExternalHost to the full service name (including the namespace).

Install mageai:

        helm install mageai . --values /opt/test/mage-ai/charts/kubernetes/mage-ai/values.yaml