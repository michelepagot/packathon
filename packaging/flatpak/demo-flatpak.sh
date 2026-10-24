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

# -----------------------------------------------------------------------------
# System Environment & Tool Requirements
# -----------------------------------------------------------------------------
banner "System Environment & Tool Requirements"

OS_NAME="Unknown"
OS_ID="unknown"
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_ID="${ID:-unknown}"
fi
echo -e "Operating System : ${BOLD}${OS_NAME}${RESET} (ID: ${OS_ID})"

HAVE_FLATPAK=false
HAVE_FIND=false
if command -v flatpak >/dev/null 2>&1; then HAVE_FLATPAK=true; fi
if command -v find >/dev/null 2>&1; then HAVE_FIND=true; fi

print_tool_status() {
    local tool="$1" available="$2" pkg="$3" purpose="$4"
    if [ "${available}" = true ]; then
        echo -e "  - ${tool,-12} : ${GREEN}FOUND${RESET} (${purpose})"
    else
        echo -e "  - ${tool,-12} : ${YELLOW}MISSING${RESET} (needed for ${purpose}; package: ${BOLD}${pkg}${RESET})"
    fi
}

print_tool_status "flatpak" "${HAVE_FLATPAK}" "flatpak"   "Flatpak runtime & bundle installation"
print_tool_status "find"    "${HAVE_FIND}"    "findutils" "Bundle auto-discovery in dist/"

if [ "${HAVE_FLATPAK}" = false ] && [ "${DRY_RUN}" = false ]; then
    echo ""
    echo -e "${YELLOW}[ERROR]${RESET} 'flatpak' is required. Install it with:"
    if [[ "${OS_ID}" =~ ^(opensuse|sles) ]]; then
        echo -e "  ${BOLD}zypper in -y flatpak${RESET}"
    elif [[ "${OS_ID}" =~ ^(debian|ubuntu) ]]; then
        echo -e "  ${BOLD}apt-get install -y flatpak${RESET}"
    fi
    exit 1
fi

if [ "${HAVE_FIND}" = false ] && [ "${DRY_RUN}" = false ]; then
    echo ""
    echo -e "${YELLOW}[ERROR]${RESET} 'find' is required for bundle auto-discovery. Install it with:"
    if [[ "${OS_ID}" =~ ^(opensuse|sles) ]]; then
        echo -e "  ${BOLD}zypper in -y findutils${RESET}"
    elif [[ "${OS_ID}" =~ ^(debian|ubuntu) ]]; then
        echo -e "  ${BOLD}apt-get install -y findutils${RESET}"
    fi
    exit 1
fi

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

# First, demonstrate why a plain install fails: no remotes are configured.
demo_cmd "flatpak install --user -y --noninteractive \"${BUNDLE_CANDIDATE}\"" \
    "Attempting a plain install (expect failure: runtime dependency cannot be resolved)." \
    "  ${DIM}The app requires org.freedesktop.Platform//25.08, but no flatpak remote is configured\n  to pull it from. openSUSE's flatpak package ships /etc/flatpak/remotes.d as an empty\n  directory — unlike Fedora, which ships a default flathub remote.${RESET}"

# Prove the absence of remotes (openSUSE-specific: the package ships no default remote).
demo_cmd "flatpak remotes" \
    "Listing configured flatpak remotes (expect empty output on openSUSE)." \
    "  ${DIM}Empty output confirms no remote is available to resolve the runtime dependency.${RESET}"

if [[ "${OS_ID}" =~ ^(opensuse|sles) ]]; then
    demo_cmd "rpm -ql flatpak | grep -i remote" \
        "Inspecting the flatpak package for shipped remote files (openSUSE only)." \
        "  ${DIM}Only /etc/flatpak/remotes.d (an empty directory) and man pages — no .flatpakrepo files.\n  This is why flatpak cannot auto-resolve the runtime: it has no remote to pull from.${RESET}"
else
    demo_cmd "dpkg -L flatpak 2>/dev/null | grep -i remote || echo '(no remote files shipped by the flatpak package)'" \
        "Inspecting the flatpak package for shipped remote files (Debian/Ubuntu)." \
        "  ${DIM}Like openSUSE, the Debian flatpak package ships no default remote.\n  /etc/flatpak/remotes.d is empty — flatpak cannot auto-resolve the runtime.${RESET}"
fi

# Demonstrate the scope quirk: a system-scope remote is invisible to user-scope installs.
demo_cmd "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" \
    "Adding the Flathub remote to the SYSTEM scope (note: no --user flag)."

demo_cmd "flatpak remotes" \
    "Listing remotes: flathub appears under the system scope." \
    "  ${DIM}The remote is configured, but it is in the system scope.${RESET}"

demo_cmd "flatpak install --user -y --noninteractive \"${BUNDLE_CANDIDATE}\"" \
    "Attempting user-scope install (expect failure: system remote is invisible to user scope)." \
    "  ${DIM}Flatpak user-scope installs can only see user-scope remotes. The system-scope\n  flathub remote is invisible here, so the runtime dependency still cannot be resolved.\n  This is a common gotcha: remote scope must match install scope.${RESET}"

# Clean up the system-scope remote and add it to the user scope instead.
demo_cmd "flatpak remote-delete flathub" \
    "Removing the system-scope flathub remote."

demo_cmd "flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo" \
    "Adding the Flathub remote to the USER scope (matches the --user install scope)."

# Now install with dependency resolution (pulls the runtime from Flathub).
demo_cmd "flatpak install --user -y --noninteractive \"${BUNDLE_CANDIDATE}\"" \
    "Installing the ocio bundle with runtime dependency resolution." \
    "  ${DIM}Flatpak now pulls org.freedesktop.Platform//25.08 from the user-scope Flathub\n  remote, then installs the app.${RESET}"

# Show what got installed: name, app ID, and installed size.
demo_cmd "flatpak list --columns=name,application,size" \
    "Listing installed Flatpak apps (name, application ID, installed size)."

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
echo "--> Launching the app with its declared permissions (the GUI should appear):"
demo_cmd "flatpak run org.packathon.ocio" \
    "Running ocio with its full declared permissions (X11, DRI, pulseaudio)." \
    "  ${DIM}The app launches with the finish-args from the manifest. If the window does not\n  appear, check that a display (X11/Wayland) is available and that the DRI device\n  is accessible. Close the window to return to the demo.${RESET}"
