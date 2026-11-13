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

## Values example

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
5. Three containers run:
   - `gitsync-init`: creates or updates Repository resources.
   - `datasource-init`: combines datasources, updates the ConfigMap, and reloads Grafana.
   - `library-init`: creates, updates, skips, and deletes library panels based on source files.

## Deploy and verify

Render before deployment:

```bash
helm lint --strict . \
  --set global.authenUsers.grafana.user=thrukadmin

helm template nmaa . \
  --set global.authenUsers.grafana.user=thrukadmin \
  --set gitsync.remote_branch=main
```

Deploy:

```bash
helm upgrade --install nmaa . -n nmaa --create-namespace \
  -f values-private.yaml
```

Verify:

```bash
kubectl get pods,job -n nmaa
kubectl logs -n nmaa job/grafana-init -c grafana-entities
kubectl logs -n nmaa job/grafana-init -c datasource-init
kubectl logs -n nmaa job/grafana-init -c library-init
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
