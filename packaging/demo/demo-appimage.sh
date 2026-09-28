#!/usr/bin/env bash
# =============================================================================
# Demo: AppImage Inspection in Vanilla Ubuntu Container
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

APPIMAGE_FILE="$(find "${REPO_ROOT}/dist" -name "ocio-*.AppImage" 2>/dev/null | head -n1 || true)"

if [ -z "${APPIMAGE_FILE}" ] || [ ! -f "${APPIMAGE_FILE}" ]; then
    echo "Error: AppImage artifact not found in dist/. Please run packaging/appimage/build-appimage.sh first." >&2
    exit 1
fi

echo "======================================================================="
echo " Live Demo: AppImage FUSE Catch & Dependency Leaks in Vanilla Ubuntu"
echo " Package: $(basename "${APPIMAGE_FILE}")"
echo "======================================================================="

podman run --rm -it \
    -v "${APPIMAGE_FILE}:/tmp/ocio.AppImage:ro,Z" \
    ubuntu:latest \
    bash -c '
set -e
echo "-----------------------------------------------------------------------"
echo "[1] Proof of Failure 1: Executing AppImage directly without FUSE..."
echo "-----------------------------------------------------------------------"
set +e
/tmp/ocio.AppImage
FUSE_EXIT=$?
set -e
echo "--> AppImage exited with status: ${FUSE_EXIT}"
echo "--> Rootless containers / minimal systems lack /dev/fuse or libfuse.so.2."
echo ""

echo "-----------------------------------------------------------------------"
echo "[2] Workaround: Running with --appimage-extract-and-run..."
echo "-----------------------------------------------------------------------"
set +e
/tmp/ocio.AppImage --appimage-extract-and-run
APP_EXIT=$?
set -e
echo "--> Executable exited with status: ${APP_EXIT}"
echo "--> Failure 2: Notice it fails on missing libOpenGL.so.0!"
echo "--> AppImage bundled raylib, but the host graphics stack was NOT bundled."
echo ""

echo "-----------------------------------------------------------------------"
echo "[3] Provenance Inspection: Extracting embedded glibc symbol baseline..."
echo "-----------------------------------------------------------------------"
strings /tmp/ocio.AppImage | grep -E "^GLIBC_2\." | sort -V | tail -n 5
echo "--> Notice the highest required GLIBC version above."
echo "--> Any Linux host with an older glibc will fail to execute this binary."
'
