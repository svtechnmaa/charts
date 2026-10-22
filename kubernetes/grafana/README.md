# Grafana

This chart deploys Grafana and an optional GDG import Job. Configure application
login and the database connection separately; they are different accounts.

## Standalone values

Save this as a private overlay and replace the DB Secret with your own:

```yaml
grafanaConfig:
  auth:
    username: admin
    password: "" # Initial login: generate if empty, or supply a password.
    existingSecret: ""
    existingSecretPasswordKey: GF_SECURITY_ADMIN_PASSWORD
  database:
    mysqlHost: mariadb
    mysqlPort: 3306
    mysqlDB: grafana
    auth:
      username: grafana
      password: ""
      existingSecret: database-auth
      existingSecretPasswordKey: grafana-password
  subPath: /grafana
gdgConfig:
  runInitDataJob: false # Enable after configuring the desired import content.
```

Run from the charts repository:

```sh
helm upgrade --install grafana .
kubectl get pods,svc
```

Set `image`, `service`, `ingress`, persistence, and `grafanaConfig.subPath` to
match your deployment. When `global.mariadb-galera.enabled` is true, Grafana
uses `mysqlDB` directly. Otherwise it uses `<namespace>_<mysqlDB>`; the external
Ansible provisioning flow must create the matching database.

## Admin password choices

| Choice | `grafanaConfig.auth` |
| --- | --- |
| Auto-generate on first install | Empty `password` and `existingSecret`; creates `<fullname>-admin`. |
| Supply initial password | Nonempty `password`, empty `existingSecret`. |
| Reference a Secret | Nonempty `existingSecret`, with `existingSecretPasswordKey` matching its key. |

External references take precedence over password input. Managed Secrets reuse
stored passwords on cluster-backed upgrades, even when a new password is supplied.
Offline `helm template` cannot look up that stored value. Secret references must
exist in the same namespace. For an existing Grafana database, use its current
admin password: startup settings do not rotate an account already stored in SQL.

## Database credentials

Use `grafanaConfig.database.auth.existingSecret` for a pre-created DB credential.
Alternatively clear that reference and supply `database.auth.password` matching
the existing DB user. This does not create the SQL account or schema, and does
not provide the admin-password auto-generation workflow for database users.
Without a DB Secret reference, the supplied password is stored as `DB_PASSWORD`
(or `database.auth.existingSecretPasswordKey`) in the same chart-managed
`<fullname>-admin` Secret as the admin credential. Pods always use `secretKeyRef`.
An empty DB password without a Secret reference fails rendering. Existing stored
DB passwords are reused; changing values alone does not rotate the DB account.

If admin authentication uses an external Secret, the chart-managed Secret holds
only the fallback DB password; the external admin Secret is not modified. If
both credentials use external Secrets, no local auth Secret is created. Admin
and DB keys must differ when both are stored in the managed Secret.

The connection keys are under `grafanaConfig.database`, including `mysqlHost`,
`mysqlPort`, and `mysqlDB`.

## GDG initialization

`gdgConfig.runInitDataJob` enables import using the configured GDG context/content.
The Deployment and GDG Job read the same admin Secret. The importer file has an
empty password; the Job supplies `GDG_CONTEXTS__MAIN__PASSWORD` and
`GDG_CONTEXTS__MAIN__USER_NAME` from the configured credentials.
