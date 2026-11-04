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

If admin authentication uses an external Secret, that Secret is referenced
directly and is not modified. The chart-managed `<fullname>-admin` Secret is
still created for Git/CD credentials and, when not external, the database
password. Admin and DB keys must differ when both are stored in the managed
Secret.

Git/CD credentials (`token`, `signer_name`, and optional signing fields) are
stored in the same chart-managed `<fullname>-admin` Secret. Workloads reference
only the individual keys they require; the Grafana container does not import the
whole Secret with `envFrom`.

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
# Grafana Helm chart

This chart deploys Grafana together with Grafana native Git Sync, datasource
provisioning, and library-panel initialization. Grafana entities are packaged
in the `grafana-entities` image and copied into a shared `emptyDir` before the
initialization containers run.

## Entity repository layout

Each value in `gitsync.path` (or an organization-specific `path`) identifies a stack
directory in the entities repository:

```text
grafana-entities/
├── itim/
│   ├── dashboards/
│   ├── datasources/
│   │   ├── mysql.yaml
│   │   └── victoriametrics.yaml
│   └── libraryelements/
│       └── Network/
│           └── Library-Panels/
│               └── alarm-summary.json
└── nmaa/
    ├── dashboards/
    ├── datasources/
    └── libraryelements/
```

The three entity types are handled differently:

| Entity | Source | Import mechanism |
| --- | --- | --- |
| Dashboards and folders | `<path>/dashboards` | Grafana native Git Sync |
| Datasources | `<path>/datasources/*.yaml` | Grafana provisioning ConfigMap and reload API |
| Library panels | `<path>/libraryelements/**/*.json` | GDG library-element upload |

## CD configuration

`gitsync.url`, `gitsync.branch`, and `gitsync.path` are shared defaults. Every organization
must provide `org`; it may override `branch` and `path`. All organizations use
the same repository URL.

```yaml
global:
  github:
    user: "git-user"
    email: "git-user@example.com"
    fg_token: "replace-with-token"
    signing_key: |
      -----BEGIN PGP PRIVATE KEY BLOCK-----
      ...
      -----END PGP PRIVATE KEY BLOCK-----

cd:
  url: "http://git-http:8080/git/grafana-entities.git"
  branch: main
  path:
    - nmaa
    - itim

  organizations:
    - org: "Development"
      write: false

    - org: "Staging"
      write: true
      branch: staging
      path:
        - nmaa

    - org: "Production"
      write: false
      branch: main
      path: [nmaa, itim]

  commitMessageTemplate: "fix: {{action}} {{title}}"
```

Use YAML lists for `gitsync.organizations` and `path`. Comma-separated strings are
not supported.

### Organization fields

| Field | Required | Default | Meaning |
| --- | --- | --- | --- |
| `org` | Yes | None | Grafana organization name. Matching is case-insensitive. Missing organizations are created by the Git Sync initializer. `main` and `default` refer to organization ID `1`. |
| `write` | No | `false` | Enables Grafana's `write` workflow and direct commits to the synchronized branch. It does not create pull requests. |
| `branch` | No | `gitsync.branch` | Branch used by this organization's Git Sync repositories. |
| `path` | No | `gitsync.path` | Stack directories whose dashboards, datasources, and library panels are assigned to this organization. |

An organization with two paths receives the combined datasource and library
panel content from both paths. Git Sync creates one dashboard repository for
each path. For example, `path: [nmaa, itim]` synchronizes
`nmaa/dashboards` and `itim/dashboards` separately.

## Repository type and authentication

The repository type is inferred from `gitsync.url`:

- A URL containing `github` uses Grafana's `github` repository type and
  `global.github.fg_token`.
- Any other URL uses Grafana's generic `git` repository type. The current
  template uses `global.github.user` as `tokenUser` and
  `global.github.fg_token` as the `password/token`.

Writable GitHub repositories enable commit signing only when
`global.github.signing_key`, `global.github.user`, and `global.github.email` are
all nonempty. The signing method is `ssh` when the configured key contains
`SSH`; otherwise it is `gpg`. Missing signing values disable signing without
blocking repository creation. Generic Git repositories do not configure commit
signing.

Do not store production tokens, passwords, or private signing keys in a values
file committed to Git. Supply them through the deployment's secret-management
workflow.

## Initialization flow

The `grafana-datasource-init` Job is a Helm `post-install`/`post-upgrade` hook
and an Argo CD `PostSync` hook.

1. The `grafana-entities` init container copies the repository bundled in the
   image into the shared `/opt/grafana-entities` volume. If the configured
   `/opt/git-server` volume does not already contain `grafana-entities.git`, it
   also initializes the bare repository and pushes `main` and `upstream`.
2. After that init container completes, three regular containers run:
   `gitsync-init`, `datasource-init`, and `library-init`.
3. Each container waits for Grafana to become healthy and independently
   processes `gitsync.organizations`.
4. The Job uses the `*-cd` ServiceAccount. Its ConfigMap permissions are scoped
   to the runtime datasource ConfigMap.

The Job has a 900-second active deadline and is removed after successful hook
completion.

The three regular containers start concurrently. Only `gitsync-init` creates
missing organizations; datasource and library initialization expect their
organizations to exist when they resolve the organization list. For a newly
created organization, rerun the hook after Git Sync has created it.

## Dashboard and folder Git Sync

For every organization and configured path, `gitsync-init` creates a Grafana
`Repository` resource with:

- `sync.enabled: true`
- a 60-second synchronization interval
- `sync.target: folderless`
- repository path `<path>/dashboards`

When `write: false`, the repository is read-only. When `write: true`, the
resource contains the `write` workflow, which enables **push to the synchronized
branch**. The commit message template is enforced and defaults to:

```text
fix: {{action}} {{title}}
```

The initializer skips a repository that already exists in the target Grafana
organization. Changing its branch, path, credentials, or write setting
therefore requires deleting the existing Grafana repository resource before
rerunning the hook.

## Datasource provisioning

Datasource fragments are read from each configured
`<path>/datasources` directory in path and filename order. Files must:

- use the `.yaml` or `.yml` extension;
- be non-empty;
- begin with a datasource list item, `- name:`;
- contain one or more datasource list items;
- not contain the provisioning wrapper keys `apiVersion`, `prune`,
  `datasources`, or `deleteDatasources`.

Example fragment:

```yaml
- name: victoriametrics
  type: prometheus
  uid: victoriametrics
  access: proxy
  editable: true
  isDefault: true
  url: http://vmselect:8481/select/0/prometheus/
```

The initializer:

1. combines all fragments assigned to each organization;
2. removes source `id` and `orgId` properties;
3. injects the resolved target `orgId` into every datasource;
4. keeps only the first `isDefault: true` datasource for each organization and
   changes additional defaults to `false`;
5. publishes the generated provisioning file to the runtime
   `*-datasources` ConfigMap; and
6. calls `/api/admin/provisioning/datasources/reload`.

Datasource names must be unique across all paths assigned to the same
organization. Keep only datasource fragments in these directories; do not add
a complete Grafana provisioning document.

### Datasource credentials

Declare datasource credentials under `gitsync.secureFiles`:

```yaml
cd:
  secureFiles:
    victoriametrics:
      user: metrics-user
      password: replace-with-password
    elasticsearch:
      basicAuthPassword: replace-with-password
```

The chart converts each key into a `GF_DS_*` environment variable in the
`*-datasource-auth` Secret. Datasource YAML should reference the variable
instead of containing the secret value:

```yaml
secureJsonData:
  password: $__env{GF_DS_VICTORIAMETRICS_PASSWORD}
```

## Library-panel initialization

Library panels are discovered recursively below
`<path>/libraryelements`. Missing directories are skipped. The relative parent
directory becomes the GDG `NestedPath`; a JSON file directly under
`libraryelements` uses `General`.

Both of these source formats are accepted:

```json
{
  "uid": "panel-uid",
  "name": "Panel name",
  "model": {}
}
```

```json
{
  "Entity": {
    "uid": "panel-uid",
    "name": "Panel name",
    "model": {}
  },
  "NestedPath": "Network/Library-Panels"
}
```

The initializer normalizes every file to `{ "Entity": ..., "NestedPath":
... }` before upload. If two selected paths contain the same relative filename,
their normalized content must be identical; otherwise the Job fails with a
collision error.

Library panels from every path assigned to an organization are uploaded to
that organization. Assign only the intended paths to avoid copying one stack's
panels into another organization's dataset.

## Install and verify

Render the chart before installation:

```bash
helm template nmaa ./kubernetes/grafana -f values-production.yaml
```

Install or upgrade:

```bash
helm upgrade --install nmaa ./kubernetes/grafana \
  --namespace nmaa \
  --create-namespace \
  -f values-production.yaml
```

Inspect the initialization Job:

```bash
kubectl get jobs -n nmaa
kubectl logs -n nmaa job/grafana-datasource-init -c grafana-entities
kubectl logs -n nmaa job/grafana-datasource-init -c gitsync-init
kubectl logs -n nmaa job/grafana-datasource-init -c datasource-init
kubectl logs -n nmaa job/grafana-datasource-init -c library-init
```

Because successful hook Jobs are deleted automatically, use your GitOps
controller history or remove `hook-succeeded` temporarily when logs must be
retained for troubleshooting.

## Uninstall

```bash
helm uninstall nmaa --namespace nmaa
```
