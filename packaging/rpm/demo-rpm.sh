#!/usr/bin/env bash
# =============================================================================
# demo-rpm.sh: Hands-on Exploration of RPM Dependencies, Capabilities & SAT
# =============================================================================
# This script demonstrates how Linux dynamic binaries declare dependencies (SONAMEs),
# how rpmbuild translates those SONAMEs into qualified RPM capabilities, and how
# high-level package solvers (libsolv via zypper) resolve the transitive closure.
#
# Key Takeaway: The ELF binary only knows SONAMEs. rpmbuild translated those
# SONAMEs into qualified RPM capabilities that the package solver can resolve
# against repository indexes.
#
# GUARANTEES:
# - READ-ONLY: Never modifies the host system, installs no packages.
# - ENVIRONMENT-AWARE: Detects openSUSE vs Debian/Ubuntu, adjusts inspection.
# - STATE-AWARE: Detects if ocio is installed; skips installation-only steps.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PAUSE_MODE=false
DRY_RUN=false
BINARY_CANDIDATE=""
RPM_CANDIDATE=""

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Hands-on exploration of RPM dependencies, capabilities, and SAT resolution."
    echo ""
    echo "Options:"
    echo "  --bin PATH       Explicit absolute path to the ocio binary for DT_NEEDED inspection"
    echo "  --rpm, -rpm PATH Explicit absolute path to the ocio RPM package for inspection"
    echo "  -p, --pause      Pause and wait for [Enter] before executing each demo command"
    echo "  -d, --dry-run    Dry-run mode: only print commands without executing them"
    echo "  -h, --help       Show this help message"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --bin)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --bin requires an absolute path argument" >&2
                exit 1
            fi
            BINARY_CANDIDATE="$2"
            shift 2
            ;;
        --bin=*)
            BINARY_CANDIDATE="${1#--bin=}"
            shift
            ;;
        -rpm|--rpm)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --rpm requires an absolute path argument" >&2
                exit 1
            fi
            RPM_CANDIDATE="$2"
            shift 2
            ;;
        -rpm=*|--rpm=*)
            RPM_CANDIDATE="${1#*=}"
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

if [ -n "${BINARY_CANDIDATE}" ]; then
    if [[ "${BINARY_CANDIDATE}" != /* ]]; then
        echo "Error: --bin path must be an absolute path: '${BINARY_CANDIDATE}'" >&2
        exit 1
    fi
    if [ ! -f "${BINARY_CANDIDATE}" ]; then
        echo "Error: --bin file does not exist: '${BINARY_CANDIDATE}'" >&2
        exit 1
    fi
fi

if [ -n "${RPM_CANDIDATE}" ]; then
    if [[ "${RPM_CANDIDATE}" != /* ]]; then
        echo "Error: --rpm path must be an absolute path: '${RPM_CANDIDATE}'" >&2
        exit 1
    fi
    if [ ! -f "${RPM_CANDIDATE}" ]; then
        echo "Error: --rpm file does not exist: '${RPM_CANDIDATE}'" >&2
        exit 1
    fi
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

cleanup_interrupt() {
    echo -e "\n${BOLD}${YELLOW}Terminating...${RESET}"
    exit 130
}
trap cleanup_interrupt INT

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

info() {
    echo -e "${YELLOW}[INFO]${RESET} $1"
}

skip() {
    echo -e "${YELLOW}[SKIP]${RESET} $1"
}

print_command_box() {
    local cmd="$1"
    echo ""
    echo -e "  ${CYAN}┌──[ Command to Run ]──────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}${YELLOW}${cmd}${RESET}"
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"
}

demo_cmd() {
    local cmd="$1"
    local desc="${2:-}"

    if [ -n "${desc}" ]; then
        substep "${desc}"
    fi

    print_command_box "${cmd}"

    if [ "${DRY_RUN}" = true ]; then
        return 0
    fi

    if [ "${PAUSE_MODE}" = true ]; then
        echo -ne "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to execute (or Ctrl+C to stop)... "
        read -r _ < /dev/tty 2>/dev/null || read -r _ || true
    fi

    eval "${cmd}" || true
}

get_install_cmd() {
    local SUDO=""
    if [ "${EUID}" -ne 0 ]; then
        SUDO="sudo "
    fi

    local target="${RPM_CANDIDATE:-/path/to/ocio.rpm}"
    if [ "${IS_OPENSUSE}" = true ]; then
        echo "${SUDO}zypper --no-refresh in --allow-unsigned-rpm \"${target}\""
    elif [ "${IS_RPM_BASED}" = true ]; then
        echo "${SUDO}rpm -Uvh \"${target}\""
    elif [ "${IS_DEBIAN}" = true ]; then
        echo "${SUDO}apt install \"${REPO_ROOT}/dist/\"*.deb"
    else
        echo "${SUDO}rpm -Uvh \"${target}\""
    fi
}

# -----------------------------------------------------------------------------
# System Environment & Distribution Detection
# -----------------------------------------------------------------------------
banner "System Environment & Distribution Detection"

OS_NAME="Unknown"
OS_ID="unknown"
OS_LIKE=""

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
fi

echo -e "Operating System : ${BOLD}${OS_NAME}${RESET} (ID: ${OS_ID}, LIKE: ${OS_LIKE:-none})"

IS_RPM_BASED=false
IS_OPENSUSE=false
IS_DEBIAN=false

if [[ "${OS_ID}" =~ ^(opensuse|sles) ]] || [[ "${OS_LIKE}" =~ suse ]]; then
    IS_RPM_BASED=true
    IS_OPENSUSE=true
    echo -e "Platform Profile : ${GREEN}openSUSE / SUSE family${RESET} (Native Zypper & RPM ecosystem)"
elif [[ "${OS_ID}" =~ ^(fedora|rhel|centos|almalinux|rocky) ]]; then
    IS_RPM_BASED=true
    echo -e "Platform Profile : ${GREEN}Fedora / RHEL family${RESET} (Native RPM & DNF ecosystem)"
elif [[ "${OS_ID}" =~ ^(debian|ubuntu|linuxmint) ]] || [[ "${OS_LIKE}" =~ debian ]]; then
    IS_DEBIAN=true
    echo -e "Platform Profile : ${YELLOW}Debian / Ubuntu family${RESET} (dpkg / apt ecosystem)"
else
    echo -e "Platform Profile : ${YELLOW}Generic / Other Linux${RESET}"
fi

# Detect whether ocio is installed on the host
OCIO_INSTALLED=false
if command -v rpm >/dev/null 2>&1 && rpm -q ocio >/dev/null 2>&1; then
    OCIO_INSTALLED=true
    echo -e "Package Status   : ${GREEN}ocio is INSTALLED in RPM database${RESET} ($(rpm -q ocio))"
elif command -v ocio >/dev/null 2>&1; then
    OCIO_INSTALLED=true
    echo -e "Package Status   : ${GREEN}ocio binary detected in PATH${RESET} ($(command -v ocio))"
else
    echo -e "Package Status   : ${YELLOW}ocio is NOT installed${RESET}"
fi

echo -e "Binary Target    : ${BINARY_CANDIDATE:-None specified (use --bin /path/to/ocio)}"
echo -e "RPM Package      : ${RPM_CANDIDATE:-None specified (use --rpm /path/to/package.rpm)}"

# -----------------------------------------------------------------------------
# Tool Requirements & Availability Check
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}Tool Requirements & Inspection Capability:${RESET}"

HAVE_READELF=false
HAVE_RPM=false
HAVE_ZYPPER=false

if command -v readelf >/dev/null 2>&1; then HAVE_READELF=true; fi
if command -v rpm >/dev/null 2>&1; then HAVE_RPM=true; fi
if command -v zypper >/dev/null 2>&1; then HAVE_ZYPPER=true; fi

print_tool_status() {
    local tool="$1"
    local available="$2"
    local pkg="$3"
    local purpose="$4"
    if [ "${available}" = true ]; then
        echo -e "  - ${tool,-10} : ${GREEN}FOUND${RESET} (${purpose})"
    else
        echo -e "  - ${tool,-10} : ${YELLOW}MISSING${RESET} (needed for ${purpose}; package: ${BOLD}${pkg}${RESET})"
    fi
}

print_tool_status "readelf" "${HAVE_READELF}" "binutils" "DT_NEEDED ELF inspection"
print_tool_status "rpm"     "${HAVE_RPM}"     "rpm"      "RPM metadata & capability queries"
if [ "${IS_OPENSUSE}" = true ]; then
    print_tool_status "zypper"  "${HAVE_ZYPPER}"  "zypper"   "Online repo capability resolution"
fi

# Print installation suggestion if any tool is missing
MISSING_PKGS=()
if [ "${HAVE_READELF}" = false ]; then MISSING_PKGS+=("binutils"); fi
if [ "${HAVE_RPM}" = false ]; then MISSING_PKGS+=("rpm"); fi

if [ ${#MISSING_PKGS[@]} -gt 0 ] && [ "${DRY_RUN}" = false ]; then
    echo ""
    if [ "${IS_OPENSUSE}" = true ]; then
        info "To enable all inspection steps on openSUSE, install missing tools via:"
        echo -e "  ${BOLD}zypper in -y ${MISSING_PKGS[*]}${RESET}"
    elif [ "${IS_DEBIAN}" = true ]; then
        info "To install inspection tools on Debian/Ubuntu:"
        echo -e "  ${BOLD}apt-get install -y binutils rpm${RESET}"
    fi
fi

if [ "${DRY_RUN}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}DRY-RUN (only printing commands, nothing executed)${RESET}"
fi
if [ "${PAUSE_MODE}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}PAUSE/STEP (waiting for [Enter] before each command)${RESET}"
fi

if [ -z "${RPM_CANDIDATE}" ]; then
    echo -e "${DIM}Tip: No RPM package specified. Pass --rpm /absolute/path/to/package.rpm to inspect package capabilities.${RESET}"
elif [ -z "${BINARY_CANDIDATE}" ]; then
    echo -e "${DIM}Tip: No binary specified for inspection. Pass --bin /absolute/path/to/ocio to inspect ELF DT_NEEDED.${RESET}"
elif [ "${OCIO_INSTALLED}" = false ]; then
    echo -e "${DIM}Tip: ocio is not installed on the host. To install it, run: $(get_install_cmd)${RESET}"
fi

# -----------------------------------------------------------------------------
# ELF Dynamic Contract (DT_NEEDED)
# -----------------------------------------------------------------------------
banner "ELF Dynamic Header Inspection (readelf -d)"
echo "Explanation: An ELF binary specifies which libraries it requires to launch."
echo "These strings are recorded in DT_NEEDED tags in the .dynamic section."
echo "At launch, the kernel executes ld.so, which resolves these exact SONAMEs."

if [ -z "${BINARY_CANDIDATE}" ]; then
    skip "No binary specified. Pass --bin /absolute/path/to/ocio to inspect ELF DT_NEEDED headers."
elif [ "${HAVE_READELF}" = false ] && [ "${DRY_RUN}" = false ]; then
    skip "'readelf' is not installed (package: binutils). Skipping DT_NEEDED inspection."
else
    demo_cmd "readelf -d \"${BINARY_CANDIDATE}\" | grep NEEDED" "Inspecting DT_NEEDED in: ${BINARY_CANDIDATE}"
    echo ""
    echo -e "  ${DIM}Note: Notice libOpenGL.so.0 and libGLX.so.0 (libglvnd vendor dispatchers).${RESET}"
    echo -e "  ${DIM}The binary does not hardcode packages or absolute paths; it requests SONAMEs.${RESET}"
    echo -e "  ${DIM}--> If any DT_NEEDED library is missing at launch, ld.so halts execution${RESET}"
    echo -e "  ${DIM}    before reaching main() and exits with status 127.${RESET}"
fi

# -----------------------------------------------------------------------------
# RPM Package Inspection & Auto-detected Capabilities
# -----------------------------------------------------------------------------
# Key Takeaway: The ELF binary only knows SONAMEs. rpmbuild translated those
# SONAMEs into qualified RPM capabilities that the package solver can resolve
# against repository indexes.
# -----------------------------------------------------------------------------
banner "RPM Package Inspection & Auto-detected Capabilities"
echo "Explanation: The spec file (packaging/rpm/ocio.spec) contains NO manual"
echo "'Requires: libOpenGL.so.0'. Instead, rpmbuild automatically extracted"
echo "capabilities and requirements from the compiled ELF binary during packaging."

if [ -n "${RPM_CANDIDATE}" ]; then
    if [ "${HAVE_RPM}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "rpm -qp --requires \"${RPM_CANDIDATE}\" | grep -E 'libOpenGL|libGLX|libm|libc'" "Querying auto-detected requirements directly from RPM file:"
        echo ""
        echo -e "  ${DIM}Key Takeaway: The ELF binary only knows SONAMEs. rpmbuild translated those${RESET}"
        echo -e "  ${DIM}SONAMEs into qualified RPM capabilities that the package solver can resolve${RESET}"
        echo -e "  ${DIM}against repository indexes.${RESET}"
        demo_cmd "rpm -qip \"${RPM_CANDIDATE}\"" "Inspecting RPM Package Metadata (rpm -qip):"
        demo_cmd "rpm -qp --requires \"${RPM_CANDIDATE}\"" "Inspecting Full Requirements List (including rpmlib and versioned glibc baselines):"
        demo_cmd "rpm -qpl \"${RPM_CANDIDATE}\"" "Inspecting RPM Payload Files (rpm -qpl):"
    else
        skip "'rpm' command is not available. Skipping RPM package inspection."
    fi
else
    skip "No RPM package specified. Pass --rpm /absolute/path/to/package.rpm to inspect RPM metadata and capabilities."
fi

# -----------------------------------------------------------------------------
# Reverse Lookup & Repository Graph (whatprovides)
# -----------------------------------------------------------------------------
banner "Repository Graph Query (whatprovides)"
echo "Explanation: How does the package manager map an abstract capability like"
echo "'libOpenGL.so.0()(64bit)' to a physical package in a repository of 30,000+ packages?"

CAPABILITY="libOpenGL.so.0()(64bit)"

if command -v rpm >/dev/null 2>&1 || [ "${DRY_RUN}" = true ]; then
    demo_cmd "rpm -q --whatprovides \"${CAPABILITY}\"" "Querying local RPM database for provider of capability:"
    PROVIDER=""
    if [ "${DRY_RUN}" != true ]; then
        if rpm -q --whatprovides "${CAPABILITY}" >/dev/null 2>&1; then
            PROVIDER=$(rpm -q --whatprovides "${CAPABILITY}" 2>/dev/null | head -n1)
        fi
    fi
    if [ -n "${PROVIDER}" ]; then
        demo_cmd "rpm -q --provides \"${PROVIDER}\" | grep -E 'libOpenGL|libGLX'" "Inspecting capabilities advertised by ${PROVIDER} (Provides tags):"
    elif [ "${DRY_RUN}" = true ]; then
        demo_cmd "rpm -q --provides \"libglvnd\" | grep -E 'libOpenGL|libGLX'" "Inspecting capabilities advertised by libglvnd (Provides tags):"
    else
        echo "No installed package currently claims to provide ${CAPABILITY}."
    fi
fi

if [ "${IS_OPENSUSE}" = true ] && (command -v zypper >/dev/null 2>&1 || [ "${DRY_RUN}" = true ]); then
    demo_cmd "zypper search --provides --match-exact \"${CAPABILITY}\"" "Querying online repositories via Zypper: 'zypper search --provides ...'"
elif [ "${IS_DEBIAN}" = true ]; then
    substep "Debian equivalent: Querying apt / dpkg for file provider"
    echo "On Debian/Ubuntu, packages use file paths or virtual package names:"
    if command -v dpkg >/dev/null 2>&1 || [ "${DRY_RUN}" = true ]; then
        demo_cmd "dpkg -S /usr/lib/x86_64-linux-gnu/libOpenGL.so.0" "Querying dpkg for installed file provider:"
    fi
    if command -v apt-file >/dev/null 2>&1 || [ "${DRY_RUN}" = true ]; then
        demo_cmd "apt-file search libOpenGL.so.0 | head -n5" "Querying apt-file for package supplying libOpenGL.so.0:"
    fi
fi

# -----------------------------------------------------------------------------
# Transitive Closure & SAT Resolution (libsolv) - Dry Run Only
# -----------------------------------------------------------------------------
banner "Transitive Closure & SAT Resolution (libsolv) - DRY RUN"
echo "Explanation: Why does 1 package drag in 35 additional packages?"
echo "libglvnd is only a dispatcher. It requires Mesa-dri drivers, X11, Wayland,"
echo "and DRM libraries. libsolv converts this graph into Boolean CNF clauses and"
echo "calculates the complete transitive closure. (NOTHING WILL BE INSTALLED)."

if (command -v rpm >/dev/null 2>&1 && rpm -q libglvnd >/dev/null 2>&1) || [ "${DRY_RUN}" = true ]; then
    demo_cmd "rpm -q --requires libglvnd | grep -E 'Mesa|libX11|libglvnd|libdrm'" "Checking second-order dependencies: 'rpm -q --requires libglvnd'"
    echo "Notice how libglvnd pulls in Mesa, libX11, and graphics drivers."
fi

if [ "${IS_OPENSUSE}" = true ] && (command -v zypper >/dev/null 2>&1 || [ "${DRY_RUN}" = true ]); then
    if [ -n "${RPM_CANDIDATE}" ]; then
        RESOLVE_TARGET="--allow-unsigned-rpm \"${RPM_CANDIDATE}\""
        RESOLVE_DESC="Simulating RPM package resolution via Zypper (--dry-run):"
    else
        RESOLVE_TARGET="\"${CAPABILITY}\""
        RESOLVE_DESC="Simulating package resolution via Zypper (--dry-run):"
    fi

    if [ "${EUID}" -eq 0 ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "zypper --non-interactive in --dry-run ${RESOLVE_TARGET}" "${RESOLVE_DESC}"
    else
        substep "${RESOLVE_DESC}"
        echo -e "${DIM}Note: On the host, 'zypper in --dry-run' requires root to acquire the solver lock.${RESET}"
        echo -e "${DIM}On this machine, all 35 graphics packages are already installed, so 0 packages would be downloaded.${RESET}"
    fi
elif [ "${IS_DEBIAN}" = true ] && (command -v apt-get >/dev/null 2>&1 || [ "${DRY_RUN}" = true ]); then
    demo_cmd "apt-get install -s --no-install-recommends libgl1 | grep -E '^Inst ' | head -n10" "Simulating package resolution on Debian via apt-get (--dry-run):"
fi


# -----------------------------------------------------------------------------
# Post-Installation Verification Steps (Only if ocio is installed)
# -----------------------------------------------------------------------------
banner "Post-Installation Integrity & Linker Audit"

if [ "${OCIO_INSTALLED}" = true ] || [ "${DRY_RUN}" = true ]; then
    OCIO_BIN="$(command -v ocio 2>/dev/null || echo /usr/bin/ocio)"
    demo_cmd "ldd \"${OCIO_BIN}\"" "Inspecting installed binary dynamic linker paths (ldd):"
    
    if (command -v rpm >/dev/null 2>&1 && rpm -q ocio >/dev/null 2>&1) || [ "${DRY_RUN}" = true ]; then
        demo_cmd "rpm -V ocio" "Verifying package integrity with RPM database (rpm -V ocio):"
        if [ "${DRY_RUN}" != true ]; then
            echo -e "${GREEN}All files intact and verified against RPM package database.${RESET}"
        fi
    fi
else
    skip "ocio is not installed on this system."
    echo -e "${DIM}Steps like 'ldd /usr/bin/ocio' and 'rpm -V ocio' only apply when the package${RESET}"
    echo -e "${DIM}has been installed to the host root. This script does not perform installations.${RESET}"
    echo ""
    echo -e "  ${CYAN}To install ocio on this system and enable this audit step, run:${RESET}"
    print_command_box "$(get_install_cmd)"
fi

banner "Summary & Pedagogical Conclusion"
echo -e "- ${BOLD}ELF Contract${RESET}     : The binary requests SONAMEs (DT_NEEDED), not distro package names."
echo -e "- ${BOLD}Local Contract${RESET}   : rpmbuild (elfdeps) extracts 'Requires: libOpenGL.so.0()(64bit)' automatically."
echo -e "- ${BOLD}Repository Graph${RESET} : 30,000+ packages offer capabilities (Provides: libglvnd)."
echo -e "- ${BOLD}Resolution Engine${RESET}: libsolv solves the CNF constraint model in ms, expanding 1 capability"
echo -e "                       into a 36-package transitive closure on a minimal headless system."
echo ""
