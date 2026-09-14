#!/usr/bin/env bash
set -euo pipefail

# Build AppImage for ocio (Packathon project)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APPDIR="${BUILD_DIR}/AppDir"
OUTPUT_DIR="${ROOT_DIR}/dist"

mkdir -p "${OUTPUT_DIR}"

echo "=== 1. Building ocio with CMake ==="
cmake -B "${BUILD_DIR}" -S "${ROOT_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" --config Release -j"$(nproc)"

echo "=== 2. Installing to AppDir ==="
rm -rf "${APPDIR}"
DESTDIR="${APPDIR}" cmake --install "${BUILD_DIR}"

echo "=== 3. Fetching linuxdeploy if needed ==="
LINUXDEPLOY="${BUILD_DIR}/linuxdeploy-x86_64.AppImage"
if [ ! -f "${LINUXDEPLOY}" ]; then
    curl -sLo "${LINUXDEPLOY}" https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
    chmod +x "${LINUXDEPLOY}"
fi

echo "=== 4. Packaging AppImage ==="
export ARCH=x86_64
export OUTPUT="${OUTPUT_DIR}/ocio-x86_64.AppImage"

EXTRA_FLAGS=""
if [ -n "${GITHUB_ACTIONS:-}" ] || ! "${LINUXDEPLOY}" --version >/dev/null 2>&1; then
    EXTRA_FLAGS="--appimage-extract-and-run"
fi

"${LINUXDEPLOY}" ${EXTRA_FLAGS} \
    --appdir "${APPDIR}" \
    --desktop-file "${ROOT_DIR}/packaging/ocio.desktop" \
    --icon-file "${ROOT_DIR}/packaging/icons/ocio.png" \
    --output appimage

if [ -f ocio-*.AppImage ]; then
    mv ocio-*.AppImage "${OUTPUT_DIR}/"
fi

echo "=== AppImage build complete! Output in ${OUTPUT_DIR}/ ==="
