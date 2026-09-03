#!/bin/bash
# Fedora: gum drives the installer's UI, so it has to be there before anything else runs.

if command -v gum &>/dev/null; then
  echo "[Omarchy] gum already installed."
  exit 0
fi

# Fedora ships gum, so ask dnf first. The GitHub release is only a fallback - and downloading from it
# first is exactly how this broke: the pinned 0.14.0 asset no longer exists, so every install started
# with a 404 and carried on with no UI.
echo "[Omarchy] Installing gum..."
if sudo dnf install -y gum; then
  exit 0
fi

echo "[Omarchy] gum is not in the enabled repositories, falling back to the GitHub release..."

GUM_VERSION="0.17.0"
ARCH=$(uname -m)
case "$ARCH" in
aarch64) ARCH="arm64" ;;
esac

GUM_URL="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_${ARCH}.rpm"
tmp_rpm="/tmp/gum_${GUM_VERSION}_Linux_${ARCH}.rpm"

if curl -fL "$GUM_URL" -o "$tmp_rpm"; then
  sudo dnf install -y "$tmp_rpm"
  rm -f "$tmp_rpm"
else
  echo "[WARNING] Could not install gum. The installer's UI will not render correctly."
fi
