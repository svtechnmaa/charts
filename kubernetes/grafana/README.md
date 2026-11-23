# Grafana

This chart deploys Grafana and an optional GDG import Job. Configure application
login and the database connection separately; they are different accounts.

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
both passwords are external, `<fullname>-admin` still holds the renderer token unless
`renderer.auth.existingSecret` is set or rendering is off. Only then is no managed
auth Secret created. Admin and DB keys must differ when both are stored in the managed Secret.

The connection keys are under `grafanaConfig.database`, including `mysqlHost`,
`mysqlPort`, and `mysqlDB`.

## GDG initialization

`gdgConfig.runInitDataJob` enables import using the configured GDG context/content.
The Deployment and GDG Job read the same admin Secret. The importer file has an
empty password; the Job supplies `GDG_CONTEXTS__MAIN__PASSWORD` and
`GDG_CONTEXTS__MAIN__USER_NAME` from the configured credentials.

## Compatibility and upgrade notes

Legacy `global.adminUser` / `global.adminPassword` remain accepted temporarily.
For username and initial password independently, precedence is nonempty
`global.authenUsers.grafana.*`, then nonempty legacy `global.admin*`, then local
`grafanaConfig.auth.*`. Remove legacy keys when moving to local auth fields.
External Secret references and already stored managed passwords take priority
for passwords. Supply the credentials of the account already stored in an
existing Grafana database; changing values alone does not rotate that account.

A managed Secret containing only the DB key can gain an admin key: the chart uses
the configured password, or generates 32 characters when empty. An existing empty
admin key fails explicitly rather than silently deploying an empty password.
If the Grafana database is already initialized, supply its current password when
switching from external to managed auth; generating a Secret does not change the
account stored in SQL. GDG uses that same credential.

## Local and external rendering services

`renderer.enabled` and `chrome.enabled` control deployment of local containers.
Their `url` settings independently select the service used by Grafana. Set
`enabled: false` and supply a reachable URL to use a shared/external service.
To disable an integration entirely, also clear its URL:

```yaml
renderer:
  enabled: false
  url: ""
chrome:
  enabled: false
  url: ""
```

Leaving the default URL while disabling the local component requires another
service at that address. Beside that, `chrome.resources` configures the local Chrome container.

## Renderer token

Grafana 13+ refuses to start with the default `[rendering] renderer_token`. The
chart sets `GF_RENDERING_RENDERER_TOKEN` on Grafana and `AUTH_TOKEN` on the
renderer sidecar. Both read one key, `renderer.auth.existingSecretTokenKey` (default `GF_RENDERING_RENDERER_TOKEN`).

By default the key lives in `<fullname>-admin`, next to the admin and database
passwords. On first install the chart uses `renderer.auth.token` or generates 64
random characters. Upgrades keep the stored value, so changing `renderer.auth.token`
later has no effect. To change the token on an existing release, use
`renderer.auth.existingSecret`.

| Choice | Values |
| --- | --- |
| Auto-generate | Defaults. Stores a random 64-character token in `<fullname>-admin`. |
| Supply a token on first install | `renderer.auth.token`. |
| Reference a Secret | `renderer.auth.existingSecret` (same namespace). The managed token key is not created. |

`renderer.auth.existingSecret` must name a Secret you manage, not `<fullname>-admin`.
The render fails otherwise. The token key must differ from the admin and database
password keys.

Offline `helm template` (for example, GitOps tools) can't look up the stored token, so set `renderer.auth.token` or `renderer.auth.existingSecret` there. After editing the Secret named in `renderer.auth.existingSecret` in place, restart the Deployment so every container reads the new token.

For an external renderer (`renderer.enabled: false` with a `renderer.url`), set
`renderer.auth.token` on first install, or `renderer.auth.existingSecret`, to the
token that renderer uses. For an existing release, use `renderer.auth.existingSecret`.

## GDG config mount

The init Job mounts the same GDG config at both `/etc/gdg/importer.yml` and
`/etc/gdg/gdg.yml`: gdg 0.9 reads `gdg.yml` first, gdg 0.7 reads only `importer.yml`.
Caution: gdg 0.9 images ship an example `/etc/gdg/gdg.yml` pointing at
staging.grafana.com, so running gdg by hand in the Grafana pod without the chart's
config targets the wrong Grafana.

The init Job also wraps library element files in `{"Entity": ..., "NestedPath": ...}`
before uploading when the image's gdg is 0.9 or newer. Files exported by gdg 0.7 are
flat and make gdg 0.9 panic; with gdg 0.7 the files are left untouched.

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