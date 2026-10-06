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

echo "=== Building ocio with CMake ==="
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
cmake --build "${BUILD_DIR}" --config Release -j"$(nproc)"

echo "=== Assembling AppDir ==="
rm -rf "${APPDIR}"
# Only the ocio component: the default install also contains raylib's dev files
DESTDIR="${APPDIR}" cmake --install "${BUILD_DIR}" --component ocio
cp "${ROOT_DIR}/packaging/ocio.desktop" "${APPDIR}/"
cp "${ROOT_DIR}/packaging/icons/ocio.png" "${APPDIR}/"
ln -sf usr/local/bin/ocio "${APPDIR}/AppRun"

echo "=== Packaging AppImage with appimagetool ==="
export ARCH=x86_64
APPIMAGE_BIN="${OUTPUT_DIR}/ocio-x86_64.AppImage"

# appimagetool otherwise downloads the type2 runtime itself at every build,
# and can hang there: fetch it once and pass it explicitly.
RUNTIME_ARCH="x86_64"
if [ -f "/usr/lib/runtime-${RUNTIME_ARCH}" ]; then
    RUNTIME="/usr/lib/runtime-${RUNTIME_ARCH}"
elif [ -f "${BUILD_DIR}/runtime-${RUNTIME_ARCH}" ]; then
    RUNTIME="${BUILD_DIR}/runtime-${RUNTIME_ARCH}"
else
    RUNTIME="${BUILD_DIR}/runtime-${RUNTIME_ARCH}"
    echo "Runtime not found in /usr/lib or ${BUILD_DIR}; downloading..."
    curl -sSL --max-time 120 -o "${RUNTIME}" "https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-${RUNTIME_ARCH}"
fi

if command -v appimagetool >/dev/null 2>&1; then
    appimagetool --verbose --runtime-file "${RUNTIME}" "${APPDIR}" "${APPIMAGE_BIN}"
else
    TOOL="${BUILD_DIR}/appimagetool"
    if [ ! -f "${TOOL}" ]; then
        curl -sLo "${TOOL}" https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
        chmod +x "${TOOL}"
    fi
    "${TOOL}" --appimage-extract-and-run --runtime-file "${RUNTIME}" "${APPDIR}" "${APPIMAGE_BIN}" </dev/null
fi

echo "=== AppImage build complete! Output: ${APPIMAGE_BIN} ==="
