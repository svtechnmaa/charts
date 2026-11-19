# Grafana Helm chart

This chart deploys Grafana with Git Sync, datasource provisioning, and library
panel initialization.

## Components

| Component | Source | Synchronization |
| --- | --- | --- |
| Dashboards/folders | `<path>/dashboards` | Grafana Git Sync |
| Datasources | `<path>/datasources/*.yaml` | ConfigMap + Grafana reload API |
| Library panels | `<path>/libraryelements/**/*.json` | Grafana Library Element API |

## Main configuration

| Key | Required | Purpose |
| --- | --- | --- |
| `grafanaConfig.auth` | Yes | Grafana username/password or external Secret |
| `grafanaConfig.database` | Yes | MariaDB/MySQL connection |
| `gitsync.url` | Yes | GitHub or git-http repository |
| `gitsync.remote_branch` | Yes | Branch used for datasource/library initialization and promotion |
| `gitsync.path` | Yes | Default entity paths |
| `gitsync.organizations` | Yes | Organization, write access, branch, and paths |
| `gitsync.forcePush` | No | Allows replacing `main/upstream` when ahead/diverged; default `false` |
| `global.github.user` | For GitHub | Git username |
| `global.github.fg_token` | For GitHub source access | Fine-grained token; `token` is always created in the Grafana Secret |

## Git credentials

When `gitsync.url` points to git-http, Grafana references the Secret owned by
git-http:

```yaml
gitsync:
  gitHttp:
    auth:
      existingSecret: git-http-auth
      usernameKey: username
      passwordKey: password
```

When `gitsync.url` points to GitHub, Grafana uses `token` and `signer_name` from
the Grafana Secret. When the destination is git-http and the selected branch is
missing, the init Job uses `token` to fetch the branch from GitHub and uses
`git-http-auth` to push to the destination.

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

### Organization fields

| Field | Default | Purpose |
| --- | --- | --- |
| `org` | None | Grafana organization name; lookup is case-insensitive |
| `write` | `false` | Enable the dashboard write workflow |
| `branch` | None | Git Sync branch for the organization |
| `path` | `gitsync.path` | Stack directories assigned to the organization |

## Repository layout

```text
grafana-entities/
├── nmaa/
│   ├── dashboards/
│   ├── datasources/
│   └── libraryelements/
└── itim/
    ├── dashboards/
    ├── datasources/
    └── libraryelements/
```

Datasource files must start with one or more `- name:` list items. Library panel
JSON must contain `uid`, `name`, and `model`.

## Deployment flow

1. The `grafana-entities` init container checks out `gitsync.remote_branch`.
2. GitHub mode fetches the branch read-only.
3. git-http mode prefers the destination branch; a missing branch can be fetched
   from the image source remote.
4. `main` and `upstream` are created or fast-forwarded. If they are ahead or
   diverged, the Job stops when `forcePush=false`; force-with-lease is used only
   when it is explicitly enabled.
5. The `grafana-organizations` initContainer creates or resolves all configured organizations.
6. Three provisioning containers run:
   - `gitsync-init`: creates or updates Repository resources.
   - `datasource-init`: combines datasources, updates the ConfigMap, and retries Grafana reload until the expected datasources are visible through the API. ConfigMap projection into the Job and Grafana Pods can finish at different times.
   - `library-init`: creates, updates, skips, and deletes library panels based on source files.

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
    password: ""
    existingSecret: ""
    existingSecretPasswordKey: GF_SECURITY_ADMIN_PASSWORD
  database:
    mysqlHost: mariadb
    mysqlPort: 3306
    mysqlDB: grafana
    auth:
      username: grafana
      existingSecret: grafana-db-auth
      existingSecretPasswordKey: password

gitsync:
  url: "http://git-http:8080/git/grafana-entities.git"
  remote_branch: main
  forcePush: false
  path: [nmaa, itim]
  organizations:
    - org: Main
      write: true
      branch: main
      path: [nmaa, itim]
    - org: Upstream
      write: false
      branch: upstream
      path: [nmaa, itim]
```


## Deploy and verify

Render before deployment:

```bash
helm lint --strict . \
  --set global.authenUsers.grafana.user=thrukadmin

helm template grafana . \
  --set global.authenUsers.grafana.user=thrukadmin \
  --set gitsync.remote_branch=main
```

Deploy:

```bash
helm upgrade --install grafana . \
  -f values-private.yaml
```

Verify:

```bash
kubectl get pods,job
kubectl logs job/grafana-init -c grafana-entities
kubectl logs job/grafana-init -c datasource-init
kubectl logs job/grafana-init -c library-init
```

The init Job is a Helm `post-install`/`post-upgrade` hook with a 900-second
active deadline.

## Promotion policy

| Selected branch relation | `forcePush=false` | `forcePush=true` |
| --- | --- | --- |
| Missing | Create branch | Create branch |
| Equal | Skip | Skip |
| Behind | Fast-forward | Fast-forward |
| Ahead | Stop the Job | Force-with-lease |
| Diverged | Stop the Job | Force-with-lease |

## Operational notes

- Existing Grafana Repository resources are skipped by `gitsync-init`; changing
  branch, path, or credentials requires updating the resource in Grafana.
- `forcePush=true` can remove commits that exist only on `main` or `upstream`;
  export or reconcile them first.
- `gitsync.path` and `organizations[].path` must be YAML lists, not comma-separated strings.
- Do not commit tokens, passwords, or private signing keys to values files.
