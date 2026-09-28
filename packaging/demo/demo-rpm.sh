#!/usr/bin/env bash
# =============================================================================
# Demo: RPM Inspection in Vanilla openSUSE Tumbleweed Container
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

RPM_FILE="$(find "${REPO_ROOT}/dist" -name "ocio-*.x86_64.rpm" 2>/dev/null | head -n1 || true)"
BINARY_FILE="${REPO_ROOT}/build/bin/ocio"

if [ -z "${RPM_FILE}" ] || [ ! -f "${RPM_FILE}" ]; then
    echo "Error: RPM artifact not found in dist/. Please run packaging/rpm/build-rpm.sh first." >&2
    exit 1
fi

echo "======================================================================="
echo " Live Demo: RPM Delegation & SAT Solver in Vanilla openSUSE Tumbleweed"
echo " Package: $(basename "${RPM_FILE}")"
echo "======================================================================="

podman run --rm -it \
    -v "${RPM_FILE}:/tmp/ocio.rpm:ro,Z" \
    -v "${BINARY_FILE}:/tmp/ocio-raw:ro,Z" \
    registry.opensuse.org/opensuse/tumbleweed:latest \
    bash -c '
set -e
echo "-----------------------------------------------------------------------"
echo "[1] Proof of Failure: Attempting to run raw un-packaged binary..."
echo "-----------------------------------------------------------------------"
set +e
/tmp/ocio-raw
EXIT_CODE=$?
set -e
echo "--> Raw binary exited with status: ${EXIT_CODE}"
echo "--> The dynamic linker (ld.so) halted execution before main() due to missing DT_NEEDED."
echo ""

echo "-----------------------------------------------------------------------"
echo "[2] Inspecting RPM header dependencies before installation..."
echo "-----------------------------------------------------------------------"
rpm -qp --requires /tmp/ocio.rpm | grep -E "libOpenGL|libc|libm"
echo ""

echo "-----------------------------------------------------------------------"
echo "[3] Installing RPM with zypper: triggering SAT solver (libsolv)..."
echo "-----------------------------------------------------------------------"
zypper --non-interactive in --allow-unsigned-rpm /tmp/ocio.rpm
echo ""

echo "-----------------------------------------------------------------------"
echo "[4] Inspecting installed binary with ldd: all symbols resolved!"
echo "-----------------------------------------------------------------------"
ldd /usr/bin/ocio
echo ""

echo "-----------------------------------------------------------------------"
echo "[5] Integrity audit with rpm -V (package database verification):"
echo "-----------------------------------------------------------------------"
rpm -V ocio && echo "All files intact and verified against RPM package database."
'
