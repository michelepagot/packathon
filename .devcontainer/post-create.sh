#!/usr/bin/env bash
# =============================================================================
# Packathon DevContainer - Post-Create Setup Script
# =============================================================================
set -euo pipefail

echo "==> Updating package indices..."
sudo apt-get update

echo "==> Installing packaging toolchains and binary inspection utilities..."
sudo apt-get install -y \
    build-essential \
    cmake \
    rpm \
    rpm2cpio \
    cpio \
    dpkg-dev \
    binutils \
    file \
    tree \
    libarchive-tools \
    squashfs-tools \
    zsync \
    curl \
    flatpak \
    flatpak-builder \
    podman \
    podman-docker \
    fuse-overlayfs \
    uidmap \
    strace \
    ttyd

echo "==> Installing pre-extracted appimagetool..."
APPIMAGE_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
if curl -sLo /tmp/appimagetool "${APPIMAGE_URL}"; then
    chmod +x /tmp/appimagetool
    (
        cd /tmp
        ./appimagetool --appimage-extract
        sudo rm -rf /usr/lib/appimagetool
        sudo mv squashfs-root /usr/lib/appimagetool
        sudo ln -sf /usr/lib/appimagetool/AppRun /usr/local/bin/appimagetool
        rm -f /tmp/appimagetool
    ) || echo "==> Warning: Failed to extract appimagetool"
else
    echo "==> Warning: Failed to download appimagetool"
fi

echo "==> Pre-pulling openSUSE Tumbleweed container image with Podman..."
podman pull registry.opensuse.org/opensuse/tumbleweed:latest || true

echo "==> Pre-pulling official Packathon runtime images from GHCR..."
podman pull ghcr.io/michelepagot/packathon/opensuse:latest || true
podman pull ghcr.io/michelepagot/packathon/debian:latest || true

echo "==> DevContainer post-create setup complete."
