# git-http

Lightweight authenticated Git Smart HTTP backend for Grafana Git Sync.

The chart serves bare repositories from `/srv/git`. An init container creates
missing repositories listed in `repositories` and reapplies their required Git
server settings on every pod start. Repository content seeding remains outside
this chart.

```yaml
repositories:
  - grafana-entities.git
  - another-repository.git
```

## Authentication

The generated `git-http-auth` Secret uses `auth.username` and
`auth.password`. When either value is empty, it falls back to
`global.adminUser` and `global.adminPassword` respectively.

## Repository storage

The default values mount the current host directory
`/tmp/grafana-entities` at `/srv/git`. For shared storage, clear `volumes`
and `volumeMounts`, enable `global.sharedVolume.enabled`, and add an entry to
`global.sharedPersistenceVolume` whose `shareFor` contains `git-http` and
whose `path` is `/srv/git`.

Example:

```yaml
global:
  sharedVolume:
    enabled: true
  sharedPersistenceVolume:
    - volumeName: git-repository
      pvcName: grafana-entities
      path: /srv/git
      shareFor:
        - git-http

volumes: []
volumeMounts: []
nodeSelector: {}
```

The repository directory must be writable by UID/GID `10001`.
Repositories created by another UID are trusted through Git's
`safe.directory` setting. By default, this applies only to direct children of
`apache.repositoryRoot`; set `apache.safeDirectory` to an exact repository
path to narrow it further.

The default hostPath configuration is pinned to `nms-01`, where
`/tmp/grafana-entities` currently exists. Clear or replace `nodeSelector`
when using shared storage or different node names.
