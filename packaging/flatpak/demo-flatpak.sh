#!/usr/bin/env bash
# =============================================================================
# Demo: Flatpak Sandbox Inspection & Permission Tax
# =============================================================================
# This script demonstrates how a Flatpak bundle is installed into the user
# scope, how the app's dynamic libraries resolve against the Freedesktop
# runtime, and how the manifest's finish-args impose a "permission tax"
# (namespace isolation) on the sandbox.
#
# Key Takeaway: A Flatpak app runs in a namespace where /app is the app and
# /usr is the runtime; every capability (X11, DRI, ...) must be explicitly
# granted via finish-args, and revoking one isolates the app from that device.
#
# GUARANTEES:
# - USER-SCOPE: Installs only into the user's Flatpak scope (flatpak --user).
# - STATE-AWARE: Auto-detects dist/ocio.flatpak or accepts --bundle.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/pause.sh"

PAUSE_MODE=false
DRY_RUN=false
BUNDLE_CANDIDATE=""

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Hands-on exploration of the Flatpak sandbox and its permission model."
    echo ""
    echo "Options:"
    echo "  --bundle PATH  Explicit path to the ocio Flatpak bundle for inspection"
    echo "  -p, --pause    Pause and wait for [Enter] before executing each demo command"
    echo "  -d, --dry-run  Dry-run mode: only print commands without executing them"
    echo "  -h, --help     Show this help message"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bundle)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --bundle requires a path argument" >&2
                exit 1
            fi
            BUNDLE_CANDIDATE="$2"
            shift 2
            ;;
        --bundle=*)
            BUNDLE_CANDIDATE="${1#*=}"
            shift
            ;;
        -p|--pause)
            PAUSE_MODE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -pd|-dp)
            PAUSE_MODE=true
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage
            ;;
    esac
done

# Resolve the bundle: explicit --bundle wins, otherwise auto-discover in dist/.
if [ -z "${BUNDLE_CANDIDATE}" ]; then
    BUNDLE_CANDIDATE="$(find "${REPO_ROOT}/dist" -name "ocio.flatpak" -o -name "ocio-*.flatpak" 2>/dev/null | head -n1 || true)"
fi

if [ "${DRY_RUN}" = true ]; then
    # Dry-run: tolerate a missing bundle; the demo prints the commands it would run.
    : "${BUNDLE_CANDIDATE:=${REPO_ROOT}/dist/ocio.flatpak}"
else
    if [ -z "${BUNDLE_CANDIDATE}" ] || [ ! -f "${BUNDLE_CANDIDATE}" ]; then
        echo "Error: Flatpak bundle not found in dist/. Please run packaging/flatpak/build-flatpak.sh first." >&2
        exit 1
    fi
    BUNDLE_CANDIDATE="$(cd "$(dirname "${BUNDLE_CANDIDATE}")" && pwd)/$(basename "${BUNDLE_CANDIDATE}")"
fi

# Formatting helpers
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[1;32m"
    BLUE="\033[1;34m"
    YELLOW="\033[1;33m"
    CYAN="\033[1;36m"
    DIM="\033[2m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" BLUE="" YELLOW="" CYAN="" DIM="" RESET=""
fi

banner() {
    echo -e "\n${BLUE}=======================================================================${RESET}"
    echo -e "${BOLD}${CYAN}$1${RESET}"
    echo -e "${BLUE}=======================================================================${RESET}"
}

substep() {
    echo -e "\n${BOLD}${GREEN}==> $1${RESET}"
    if [ -n "${2:-}" ]; then
        echo -e "${DIM}$2${RESET}"
    fi
}

banner "Flatpak Sandbox Dissection & The Permission Tax"
echo -e "Bundle: ${BOLD}${BUNDLE_CANDIDATE}${RESET}"

if [ "${DRY_RUN}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}DRY-RUN (only printing commands, nothing executed)${RESET}"
fi
if [ "${PAUSE_MODE}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}PAUSE/STEP (waiting for [Enter] before each command)${RESET}"
fi

# -----------------------------------------------------------------------------
# [1] Install the bundle into the user scope
# -----------------------------------------------------------------------------
banner "[1] Installing Flatpak bundle into user scope"
demo_cmd "flatpak install --user -y --noninteractive --no-deps --no-related \"${BUNDLE_CANDIDATE}\"" \
    "Installing the ocio bundle into the user's Flatpak scope (no system changes)."

# -----------------------------------------------------------------------------
# [2] Inspect installed application metadata
# -----------------------------------------------------------------------------
banner "[2] Inspecting Installed Application Metadata"
demo_cmd "flatpak info org.packathon.ocio" \
    "Reading the installed app's metadata (runtime, branch, permissions)."

# -----------------------------------------------------------------------------
# [3] Sandbox dissection: /app vs /usr
# -----------------------------------------------------------------------------
banner "[3] Interactive Sandbox Dissection (/app vs /usr)"
echo "--> Inside the sandbox, dynamic libraries resolve against the Freedesktop runtime:"
demo_cmd "flatpak run --command=ldd org.packathon.ocio /app/bin/ocio" \
    "Running ldd inside the sandbox: the app's DT_NEEDED entries resolve against the runtime's /usr."

# -----------------------------------------------------------------------------
# [4] The permission tax (namespace isolation)
# -----------------------------------------------------------------------------
banner "[4] Demonstrating The Permission Tax (Namespace Isolation)"
echo "--> Permissions declared in manifest finish-args: --socket=x11, --device=dri"
echo "--> You can run an interactive shell inside the sandbox with:"
print_command_box "flatpak run --command=sh org.packathon.ocio"
echo "--> You can simulate hardware permission revocation with:"
print_command_box "flatpak run --nodevice=dri --nosocket=x11 org.packathon.ocio"
