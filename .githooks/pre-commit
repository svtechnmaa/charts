#!/usr/bin/env sh
#!/bin/sh


GITLEAKS_VERSION="8.21.2"
INSTALL_DIR="$HOME/.local/bin"

# Detect OS trước để biết tên binary
_OS_RAW=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$_OS_RAW" in
  mingw*|msys*|cygwin*) GITLEAKS_BIN="$INSTALL_DIR/gitleaks.exe" ;;
  *)                    GITLEAKS_BIN="$INSTALL_DIR/gitleaks" ;;
esac

install_gitleaks() {
  echo "⚙️  gitleaks not found. Installing v${GITLEAKS_VERSION}..."

  mkdir -p "$INSTALL_DIR"

  OS="$_OS_RAW"
  ARCH=$(uname -m)

  case "$OS" in
    mingw*|msys*|cygwin*) OS="windows" ;;
  esac

  case "$ARCH" in
    x86_64)  ARCH="x64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)
      echo "❌ Unsupported arch: $ARCH"
      exit 1
      ;;
  esac

  case "$OS" in
    linux)   EXT="tar.gz" ;;
    darwin)  EXT="tar.gz" ;;
    windows) EXT="zip" ;;
    *)
      echo "❌ Unsupported OS: $OS"
      exit 1
      ;;
  esac

  URL="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${OS}_${ARCH}.${EXT}"

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  if command -v curl > /dev/null 2>&1; then
    curl -sSL "$URL" -o "$TMP_DIR/gitleaks.$EXT"
  elif command -v wget > /dev/null 2>&1; then
    wget -q "$URL" -O "$TMP_DIR/gitleaks.$EXT"
  else
    echo "❌ Neither curl nor wget found."
    exit 1
  fi

  if [ "$EXT" = "zip" ]; then
    unzip -q "$TMP_DIR/gitleaks.zip" -d "$TMP_DIR"
    mv "$TMP_DIR/gitleaks.exe" "$GITLEAKS_BIN"
  else
    tar -xzf "$TMP_DIR/gitleaks.tar.gz" -C "$TMP_DIR"
    mv "$TMP_DIR/gitleaks" "$GITLEAKS_BIN"
  fi

  chmod +x "$GITLEAKS_BIN"
  echo "✅ gitleaks v${GITLEAKS_VERSION} installed at $GITLEAKS_BIN"
}

# ─── Resolve binary ───────────────────────────────────────────────────────────
if command -v gitleaks > /dev/null 2>&1; then
  GITLEAKS_CMD="gitleaks"
elif [ -x "$GITLEAKS_BIN" ]; then
  GITLEAKS_CMD="$GITLEAKS_BIN"
else
  install_gitleaks
  GITLEAKS_CMD="$GITLEAKS_BIN"
fi

# ─── Run scan ─────────────────────────────────────────────────────────────────
"$GITLEAKS_CMD" protect --staged --redact --no-banner
EXIT_CODE=$?

if [ $EXIT_CODE -eq 1 ]; then
  echo ""
  echo "❌ Secrets detected in staged files. Commit blocked."
  echo "   Fix the issue or add to allowlist in .gitleaks.toml"
  exit 1
fi

exit 0