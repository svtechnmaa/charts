# Git Hooks Setup

Configure Git to use the hooks in `.githooks` for every repository on your machine:

```bash
git config --global core.hooksPath .githooks
```

Run this command once after cloning the repository.

Verify the global configuration:

```bash
git config --global --get core.hooksPath
```

Expected output:

```text
.githooks
```
