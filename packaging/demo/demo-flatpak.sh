#!/usr/bin/env bash
# =============================================================================
# Demo: Flatpak Sandbox Inspection & Permission Tax
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

BUNDLE_FILE="$(find "${REPO_ROOT}/dist" -name "ocio.flatpak" -o -name "ocio-*.flatpak" 2>/dev/null | head -n1 || true)"

if [ -z "${BUNDLE_FILE}" ] || [ ! -f "${BUNDLE_FILE}" ]; then
    echo "Error: Flatpak bundle not found in dist/. Please run packaging/flatpak/build-flatpak.sh first." >&2
    exit 1
fi

echo "======================================================================="
echo " Live Demo: Flatpak Sandbox Dissection & The Permission Tax"
echo " Bundle: $(basename "${BUNDLE_FILE}")"
echo "======================================================================="

echo "-----------------------------------------------------------------------"
echo "[1] Inspecting Flatpak Bundle Metadata..."
echo "-----------------------------------------------------------------------"
flatpak info --bundle "${BUNDLE_FILE}" || true
echo ""

echo "-----------------------------------------------------------------------"
echo "[2] Installing Flatpak bundle into user scope..."
echo "-----------------------------------------------------------------------"
flatpak install --user -y --noninteractive "${BUNDLE_FILE}"
echo ""

echo "-----------------------------------------------------------------------"
echo "[3] Interactive Sandbox Dissection (/app vs /usr)..."
echo "-----------------------------------------------------------------------"
echo "--> Inside the sandbox, dynamic libraries resolve against Freedesktop runtime:"
flatpak run --command=ldd org.packathon.ocio /app/bin/ocio || true
echo ""

echo "-----------------------------------------------------------------------"
echo "[4] Demonstrating The Permission Tax (Namespace Isolation):"
echo "-----------------------------------------------------------------------"
echo "--> Permissions declared in manifest finish-args: --socket=x11, --device=dri"
echo "--> You can run an interactive shell inside the sandbox with:"
echo "    flatpak run --command=sh org.packathon.ocio"
echo "--> You can simulate hardware permission revocation with:"
echo "    flatpak run --nodevice=dri --nosocket=x11 org.packathon.ocio"
