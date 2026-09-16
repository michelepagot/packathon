#!/usr/bin/env bash
set -euo pipefail

# Build AppImage for ocio (Packathon project)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build}"
APPDIR="${BUILD_DIR}/AppDir"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}"

echo "=== 1. Building ocio with CMake ==="
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" --config Release -j"$(nproc)"

echo "=== 2. Assembling AppDir ==="
rm -rf "${APPDIR}"
DESTDIR="${APPDIR}" cmake --install "${BUILD_DIR}"
cp "${ROOT_DIR}/packaging/ocio.desktop" "${APPDIR}/"
cp "${ROOT_DIR}/packaging/icons/ocio.png" "${APPDIR}/"
ln -sf usr/local/bin/ocio "${APPDIR}/AppRun"

echo "=== 3. Packaging AppImage with appimagetool ==="
export ARCH=x86_64
APPIMAGE_BIN="${OUTPUT_DIR}/ocio-x86_64.AppImage"

if command -v appimagetool >/dev/null 2>&1; then
    appimagetool "${APPDIR}" "${APPIMAGE_BIN}"
else
    TOOL="${BUILD_DIR}/appimagetool"
    if [ ! -f "${TOOL}" ]; then
        curl -sLo "${TOOL}" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
        chmod +x "${TOOL}"
    fi
    "${TOOL}" --appimage-extract-and-run "${APPDIR}" "${APPIMAGE_BIN}"
fi

echo "=== AppImage build complete! Output: ${APPIMAGE_BIN} ==="
