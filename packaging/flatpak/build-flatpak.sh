#!/usr/bin/env bash
set -euo pipefail

# Build Flatpak bundle for ocio (Packathon project)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/flatpak-build}"
REPO_DIR="${REPO_DIR:-/tmp/flatpak-repo}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"
MANIFEST="${SCRIPT_DIR}/org.packathon.ocio.yml"
BUNDLE="${OUTPUT_DIR}/ocio.flatpak"

mkdir -p "${OUTPUT_DIR}"

echo "=== 1. Configuring Flathub remote and installing SDK/Runtime ==="
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --user --noninteractive flathub org.freedesktop.Platform//24.08 org.freedesktop.Sdk//24.08

echo "=== 2. Building application with flatpak-builder ==="
flatpak-builder --user --force-clean --repo="${REPO_DIR}" "${BUILD_DIR}" "${MANIFEST}"

echo "=== 3. Exporting single-file Flatpak bundle ==="
flatpak build-bundle "${REPO_DIR}" "${BUNDLE}" org.packathon.ocio

echo "=== Flatpak build complete! Output: ${BUNDLE} ==="
