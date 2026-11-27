# Grafana Helm chart

This chart deploys Grafana and initializes organization-specific dashboards,
datasources, and library panels from `grafana-entities`.

Grafana login and database access use separate accounts. Set the admin username
through `global.authenUsers.grafana.user` or `grafanaConfig.auth.username`.

## Admin credentials

| Choice | `grafanaConfig.auth` |
| --- | --- |
| Generate a password on first install | Leave `password` and `existingSecret` empty. The chart creates `<fullname>-admin`. |
| Supply an initial password | Set `password` and leave `existingSecret` empty. |
| Use an existing Secret | Set `existingSecret` and `existingSecretPasswordKey` to a Secret and key in the release namespace. |

An external Secret takes precedence over `password`. For a managed Secret, an
existing password is preserved on cluster-backed upgrades, even if values
contain a different password. Offline `helm template` cannot read that stored
value. The admin username must be nonempty; an empty managed password is
generated as 32 characters on first install. Grafana startup settings do not
change the password of an account already stored in its database. When using an
existing Grafana database, supply that account's current password.

## Database credentials

Set the connection under `grafanaConfig.database`, including `mysqlHost`,
`mysqlPort`, and `mysqlDB`. Set `grafanaConfig.database.auth.username` and either
`auth.existingSecret` with `auth.existingSecretPasswordKey`, or `auth.password`
matching the existing database user. The chart does not create the SQL account
or schema. An empty password without an external Secret fails rendering.

Without an external DB Secret, the password is stored in `<fullname>-admin`
under `grafanaConfig.database.auth.existingSecretPasswordKey` (default
`DB_PASSWORD`). Grafana reads it using `secretKeyRef`. Cluster-backed upgrades
preserve the stored password; changing values does not rotate the SQL account.
Admin and database keys must differ when both are chart-managed. External
Secrets are referenced, not modified.

## Configuration

| Key | Purpose |
| --- | --- |
| `gitsync.enabled` | Enables the Grafana init Job. |
| `gitsync.mode` | `git` uses git-http; `github` reads GitHub directly. |
| `gitsync.git.url` | Destination Git URL in `git` mode. |
| `gitsync.git.auth` | Existing git-http Secret and its username/password keys. |
| `gitsync.github.url` | GitHub source URL; also used when a branch is missing on git-http. |
| `gitsync.<mode>.organizations[]` | `org`, `branch`, `path[]`, and optional `write`. |
| `gitsync.secureFiles` | Shared initial datasource credentials, keyed by datasource name. |
| `grafanaEntities.image` | Entities image; must contain `git` and `yq` v4. |
| `grafanaConfig.auth` | Grafana admin username/password or existing Secret. |
| `grafanaConfig.database` | MariaDB/MySQL connection and credentials. |
| `global.github.fg_token` | GitHub source access and GitHub-mode Git Sync token. |

The chart accepts legacy `global.adminUser` and `global.adminPassword`.
For username and initial password independently, a nonempty
`global.authenUsers.grafana.*` takes precedence, followed by a nonempty legacy
`global.admin*`, then `grafanaConfig.auth.*`. Existing managed passwords and
external Secret references take precedence over initial password values.
Remove legacy keys when moving to local auth values. If switching from an
external to a managed admin Secret against an initialized Grafana database,
provide the account's current password; generating a new Secret does not
change its password in SQL.

Example:

```yaml
gitsync:
  enabled: true
  mode: git
  git:
    url: http://git-http:8080/git/grafana-entities.git
    auth:
      existingSecret: git-http-auth
      usernameKey: username
      passwordKey: password
    organizations:
      - org: Main
        branch: main
        path: [nmaa, itim]
        write: true
  github:
    url: https://github.com/example/grafana-entities.git
    organizations: []
  secureFiles:
    audit-config:
      user: example-user
      password: example-password
```

Keep credential values in a private values overlay. The chart renders
`secureFiles` into a Kubernetes Secret, and only `datasource-init` imports its
keys through `envFrom`. A Job rendered alone without `secureFiles` can still
consume an existing datasource Secret; if the Secret is absent, the Job starts
without credential variables. A full Helm upgrade without `secureFiles` removes
the chart-managed Secret. Datasource YAML may use
`$__env{GF_DS_AUDIT_CONFIG_PASSWORD}`. The Job
resolves the placeholder before calling Grafana's API. Missing credential
variables produce an unauthenticated datasource and a warning; a plugin that
requires credentials may still reject it.

## Local and external rendering services

`renderer.enabled` and `chrome.enabled` control their local containers and
Services. `renderer.url` and `chrome.url` independently configure the endpoints
used by Grafana. To use shared services, disable the local containers and set
reachable URLs. To disable an integration, also clear its URL:

```yaml
renderer:
  enabled: false
  url: ""
chrome:
  enabled: false
  url: ""
```

Leaving a default URL while disabling its local container requires another
service at that address. `chrome.resources` configures the local Chrome
container.

The current chart sets Grafana's `GF_RENDERING_RENDERER_TOKEN` and the local
renderer sidecar's `AUTH_TOKEN` from the configured Grafana admin password
Secret key. It does not support the separate `renderer.auth.*` values described
in older chart revisions. If using an external renderer, configure its token to
match this value.

## Init flow

1. In `git` mode, missing git-http `main` is seeded once from the entities image.
   Existing `main` is retained. A missing organization branch is fetched from
   GitHub and pushed to git-http under the same name. A branch missing from both
   sources fails the Job. GitHub mode fetches each branch directly and never
   pushes to git-http. No branch is promoted to `main` or `upstream`.
2. The entities initContainer exports the selected commit for each organization
   into a separate directory on a shared `emptyDir` volume, then converts its
   datasource YAML files to JSON with `yq` for the API worker.
3. The organizations initContainer ensures each Grafana organization exists.
4. Three Job containers run concurrently. `gitsync-init` configures dashboard
   Git Sync for `<path>/dashboards`; `datasource-init` creates missing
   datasources from `<path>/datasources/*.yaml` via Grafana API; `library-init`
   reconciles `<path>/libraryelements/**/*.json` through Grafana API.

Datasource files contain a YAML list with one or more entries. The Job selects
existing datasources by UID or name and never updates them, so UI edits and
credentials remain intact on reruns. Credential changes in `secureFiles` apply
only to newly created datasources in a new Job Pod. Multiple new organizations
share the same `secureFiles` values; credentials can then be edited separately
in Grafana. The Job creates the first datasource declared with `isDefault: true`
before the others so Grafana does not select a different initial default. If
multiple files declare defaults, later ones are created as non-default and the
Job logs this choice. If a different default already exists, the Job leaves it
unchanged and logs the conflict. Without an explicit default, Grafana may
select the first datasource created in a new organization. After processing
each organization, the Job reads Grafana's API and logs its actual default.

## Upgrade notes

- For a fresh installation, set an admin username and database credentials.
  An existing release can retain its values with `helm upgrade --reuse-values`.
- The previous datasource Job published a ConfigMap containing `prune: true`.
  Inventory provisioned datasources and plan their migration before upgrading
  an existing Grafana installation to API-managed datasources. Removing that
  provisioning file can delete those datasources.
- The current `gitsync-init` skips Repository resources that already exist.
  Changing an existing organization's branch or mode requires updating that
  Repository separately until reconciliation is added.
- Grafana no longer mounts a datasource ConfigMap. New organizations can be
  initialized without a Grafana Deployment rollout when no other Deployment
  fields change.
- `helm template | kubectl apply` updates the datasource Secret but does not
  rerun an existing Job. Apply the Secret first, then recreate only the Job.

## Standalone values

For a Grafana installation without Git Sync, save a private values overlay.
Replace the database Secret reference with one that exists in the release
namespace:

```yaml
grafanaConfig:
  auth:
    username: admin
    password: "" # Generate on first install, or supply the existing account password.
  database:
    mysqlHost: mariadb
    mysqlPort: 3306
    mysqlDB: grafana
    auth:
      username: grafana
      existingSecret: database-auth
      existingSecretPasswordKey: grafana-password
  subPath: /grafana
gitsync:
  enabled: false
```

From the charts repository, run `helm upgrade --install grafana
./kubernetes/grafana -n <namespace> -f <private-values.yaml>`.

## Verify

```bash
helm lint --strict . --set global.authenUsers.grafana.user=example-admin
helm template nmaa . --set global.authenUsers.grafana.user=example-admin
kubectl logs job/grafana-init -c grafana-entities
kubectl logs job/grafana-init -c datasource-init
kubectl logs job/grafana-init -c library-init
```
