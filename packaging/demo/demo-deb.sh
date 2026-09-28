#!/usr/bin/env bash
# =============================================================================
# Demo: DEB Inspection in Vanilla Debian Slim Container
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

DEB_FILE="$(find "${REPO_ROOT}/dist" -name "ocio_*.deb" -o -name "ocio-*.deb" 2>/dev/null | head -n1 || true)"

if [ -z "${DEB_FILE}" ] || [ ! -f "${DEB_FILE}" ]; then
    echo "Error: DEB artifact not found in dist/. Please run packaging/deb/build-deb.sh first." >&2
    exit 1
fi

echo "======================================================================="
echo " Live Demo: DEB Anatomy & Dependency Resolution in Vanilla Debian Slim"
echo " Package: $(basename "${DEB_FILE}")"
echo "======================================================================="

podman run --rm -it \
    -v "${DEB_FILE}:/tmp/ocio.deb:ro,Z" \
    debian:bookworm-slim \
    bash -c '
set -e
echo "-----------------------------------------------------------------------"
echo "[1] Dissecting Unix ar archive members..."
echo "-----------------------------------------------------------------------"
ar t /tmp/ocio.deb
echo ""

echo "-----------------------------------------------------------------------"
echo "[2] Reading control metadata (dpkg-deb -I)..."
echo "-----------------------------------------------------------------------"
dpkg-deb -I /tmp/ocio.deb | grep -E "Package:|Version:|Depends:|Recommends:|Architecture:"
echo "--> libc6 (>= ...) is computed by dpkg-shlibdeps; libglx0 and libx11-6 are declared by hand."
echo ""

echo "-----------------------------------------------------------------------"
echo "[3] Proof of Failure: Direct dpkg -i without package manager solver..."
echo "-----------------------------------------------------------------------"
set +e
dpkg -i /tmp/ocio.deb
DPKG_EXIT=$?
set -e
echo "--> dpkg exited with status: ${DPKG_EXIT}"
echo "--> Notice: dpkg unpacks the payload but cannot resolve missing dependencies."
echo ""

echo "-----------------------------------------------------------------------"
echo "[4] Resolving dependencies via APT package manager..."
echo "-----------------------------------------------------------------------"
apt-get update -qq
apt-get install -y -qq /tmp/ocio.deb >/dev/null
echo "--> Package installed successfully via APT."
echo ""

echo "-----------------------------------------------------------------------"
echo "[5] Inspecting installed binary dynamic links with ldd:"
echo "-----------------------------------------------------------------------"
ldd /usr/bin/ocio
echo "--> Only libc/libm: GLFW loads libX11 and libGLX with dlopen() at runtime."
echo "    ldd and dpkg-shlibdeps cannot see them; the hand-written Depends covers them:"
for lib in libX11.so.6 libGLX.so.0; do
    dpkg -S "$(readlink -f "/usr/lib/x86_64-linux-gnu/${lib}")"
done
echo ""

echo "-----------------------------------------------------------------------"
echo "[6] Auditing installed files against DEBIAN/md5sums:"
echo "-----------------------------------------------------------------------"
dpkg --verify ocio && echo "--> dpkg --verify: clean"
'
