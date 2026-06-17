# SVTECH Repository Security Template

This template installs local BetterLeaks hooks for SVTECH repositories.

GitHub Actions security checks are enforced separately by the centralized `.github` repository ruleset.

## Case 1: New Repository From This Template

After cloning the new repository, run only this command:

```bash
# --global is for every repositories on the machine, remove it to apply for only current repo
git config --global core.hooksPath .githooks 
```

Verify the setup:

```bash
git config --get core.hooksPath
```

Expected output:

```text
.githooks
```

## Case 2: Existing Repository

Existing repositories that were not created from this template must run the setup script to download `.githooks` from the template repository.

The template repository is private, so provide a GitHub token with read access to `svtechnmaa/template-repository`.

Token permissions:

```text
Classic PAT:      repo
Fine-grained PAT: Repository access to svtechnmaa/template-repository, Contents: Read-only
```

The token is only used to download files from the template repository.

```bash
export GITHUB_TOKEN="ghp_xxx"

curl -fsSL \
  -H "Authorization: token ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github.v3.raw" \
  "https://api.github.com/repos/svtechnmaa/template-repository/contents/.githooks/setup_security_scan.bash?ref=main" \
  | GITHUB_TOKEN="${GITHUB_TOKEN}" bash -s -- -y
```

The script will:

```text
download .githooks/*
chmod +x .githooks/*
git config core.hooksPath .githooks
```

Then commit the installed files to the existing repository:

```bash
git add .githooks
git commit -m "chore: install security scan hooks"
```

## How It Works

The local hook appends the `betterleaks-Scan: passed` trailer. The centralized `.github` ruleset validates the required security workflow for pull requests.
