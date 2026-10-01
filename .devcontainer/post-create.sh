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

echo "==> Pre-pulling the vanilla images used by the walkthrough and the demos..."
podman pull registry.opensuse.org/opensuse/tumbleweed:latest || true
podman pull docker.io/library/debian:bookworm-slim || true
podman pull docker.io/library/ubuntu:latest || true

echo "==> Pulling the Packathon builder images from GHCR (tagged with the local names the scripts use)..."
for distro in opensuse debian; do
    if podman pull "ghcr.io/michelepagot/packathon/${distro}-builder:latest"; then
        podman tag "ghcr.io/michelepagot/packathon/${distro}-builder:latest" "localhost/packathon-${distro}:builder"
    fi
done

echo "==> DevContainer post-create setup complete."
