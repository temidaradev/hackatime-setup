#!/bin/bash
set -euo pipefail

REPO="hackclub/hackatime-setup"
BINARY_NAME="hackatime_setup"

if [ $# -lt 1 ]; then
    echo "Usage: $0 <api-key> [api-url]"
    echo "  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | bash -s -- YOUR_API_KEY"
    exit 1
fi

API_KEY="$1"
API_URL="${2:-}"

OS="$(uname -s)"
case "$OS" in
    Linux*)  OS_NAME="linux" ;;
    Darwin*) OS_NAME="macos" ;;
    *)       echo "Unsupported OS: $OS"; exit 1 ;;
esac

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64|amd64)  ARCH_NAME="x86_64" ;;
    arm64|aarch64) ARCH_NAME="aarch64" ;;
    *)             echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

USE_MUSL="false"
if [ "$OS_NAME" = "linux" ]; then
    if grep -qsi "chromeos" /proc/version 2>/dev/null || \
       grep -qsi "chrome os" /proc/version 2>/dev/null || \
       [ -d /opt/google/cros-containers ] || \
       [ -f /dev/.cros_milestone ]; then
        USE_MUSL="true"
    elif ! ldd --version 2>&1 | grep -qi "gnu\|glibc" 2>/dev/null; then
        USE_MUSL="true"
    fi
fi

if [ "$USE_MUSL" = "true" ]; then
    ASSET_NAME="hackatime_setup-linux-musl-${ARCH_NAME}.tar.gz"
else
    ASSET_NAME="hackatime_setup-${OS_NAME}-${ARCH_NAME}.tar.gz"
fi

DOWNLOAD_URL=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep "browser_download_url.*${ASSET_NAME}" \
    | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not find release for $ASSET_NAME"
    exit 1
fi

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

curl -sL "$DOWNLOAD_URL" -o "$TEMP_DIR/$ASSET_NAME"
tar -xzf "$TEMP_DIR/$ASSET_NAME" -C "$TEMP_DIR"
chmod +x "$TEMP_DIR/$BINARY_NAME"

if [ -n "$API_URL" ]; then
    "$TEMP_DIR/$BINARY_NAME" --key "$API_KEY" --api-url "$API_URL"
else
    "$TEMP_DIR/$BINARY_NAME" --key "$API_KEY"
fi
