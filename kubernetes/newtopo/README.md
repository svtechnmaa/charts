# 📦 Newtopo Helm Chart

This Helm chart deploys the **Newtopo Stack**, including the Backend, Frontend, Redis, Traefik, and optional services such as AsynqMon and MySQL.

---

## 🚀 Prerequisites

- Helm v3 or higher
- A running Kubernetes cluster
- Network access to the GitHub Container Registry (`ghcr.io`), MariaDB and ArrangoDB
- This application uses **MariaDB** and **ArrangoDB**, so both databases must be installed beforehand.
- If you are using an **external MariaDB instance**, make sure of the following:
  - The `svtech` database has been created.
  - The user specified in `values.yaml` has the appropriate permissions to access the `svtech` database from Kubernetes nodes.
  - Example SQL statements to grant access to the user `backend`:

    ```sql
    CREATE DATABASE svtech;

    GRANT ALL PRIVILEGES ON svtech.* TO 'backend'@'localhost' IDENTIFIED BY 'backend';
    GRANT ALL PRIVILEGES ON svtech.* TO 'backend'@'127.0.0.1' IDENTIFIED BY 'backend';
    GRANT ALL PRIVILEGES ON svtech.* TO 'backend'@'%' IDENTIFIED BY 'backend';
    ```

- About **ArrangoDB**:
  - Create a collection named `topo_list` in the `_system` database:

    ```text
    _system → topo_list
    ```

---

## ⚙️ Required Configuration Values

Before deploying, you **must provide** the following values using a custom `values.yaml` file or the `--set` flag.

### 🔑 GitHub Credentials for Icon Resources

Used to access GitHub-hosted assets such as icons:

```yaml
global:
  github:
    user: ""
    token: ""
    fg_token: ""

```

### 🔑 Image Pull Token

You **must provide** a GitHub Container Registry pull token to pull private images:

```yaml
image:
  pullToken: "<your-ghcr-token>"
```

### Seed File Datasources
Configure datasource connections used by the backend:

```yaml
seed_file:
  datasources:
    redis:
      url: redis://redis:6379
      username: ""
      password: ""
    arangodb:
      url: http://arangodb:8529
      username: "<arangodb-username>"
      password: "<arangodb-password>"
      topo_schema: unitel
    grafana:
      url: http://grafana:3000/grafana/
      username: "<grafana-username>"
      password: "<grafana-username>"
    icinga_redis:
      url: redis://icinga2:6379
      username: ""
      password: ""
```

### Mariadb Connection
Configure Mariadb connection used by the backend:

```yaml
go_backend:
  ...
  configmap:
    data:
      ...
      DATABASE_URL: backend:backend@tcp(mariadb:3306)/svtech?parseTime=true
      ...
```

### Traefik config
Set value for traefik configuration:

```yaml
traefik:
  ...
  service:
    ...
    loadBalancerIP: "<loadBalancer-IP>"
  config_template:
    http:
      middlewares:
        dashboard_auth: "<dashboard_auth_for_traefik_middlewares>"
        grafana_auth: "<grafana_auth_for_traefik_middlewares>"
```
