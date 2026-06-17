#!/bin/sh
set -e
if [ -f "$INSTALL_DIR/betterleaks" ] ; then
  echo "[INFO] betterleaks already installed"
  exit 0
fi

echo "[INFO] Installing betterleaks..."

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
  Linux) OS="linux"; EXT="tar.gz" ;;
  Darwin) OS="darwin"; EXT="tar.gz" ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows"; EXT="zip" ;;
  *) echo "Unsupported OS"; exit 1 ;;
esac

case "$ARCH" in
  x86_64|amd64) ARCH="x64" ;;
  arm64|aarch64) ARCH="arm64" ;;
  *) echo "Unsupported ARCH"; exit 1 ;;
esac

VERSION="1.1.2"
FILE="betterleaks_${VERSION}_${OS}_${ARCH}.${EXT}"
URL="https://github.com/betterleaks/betterleaks/releases/download/v${VERSION}/${FILE}"

echo "[INFO] Downloading betterleaks from $URL"

curl -fsSL "$URL" -o "$FILE"

if [ "$EXT" = "zip" ]; then
  unzip -q "$FILE" betterleaks.exe -d "$INSTALL_DIR"
  mv "$INSTALL_DIR/betterleaks.exe" "$INSTALL_DIR/betterleaks"
else
  tar -xzf "$FILE" -C "$INSTALL_DIR" betterleaks
fi

rm -f "$FILE"

chmod +x "$INSTALL_DIR"/betterleaks

echo "[INFO] Installed betterleaks"
