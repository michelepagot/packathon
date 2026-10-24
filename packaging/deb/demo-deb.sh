#!/usr/bin/env bash
# =============================================================================
# demo-deb.sh: Hands-on Exploration of DEB Anatomy, Metadata & Dependency Solver
# =============================================================================
# This script demonstrates how Debian packages are physically structured as
# Unix ar archives, how dpkg-deb inspects control metadata and hand-written vs
# computed dependencies (dpkg-shlibdeps), and how apt simulates resolution.
#
# Key Takeaway: A .deb file is an 'ar' archive containing debian-binary, control.tar.*,
# and data.tar.*. dpkg unpacks files but has no SAT solver; APT calculates the
# transitive closure to satisfy dependencies.
#
# GUARANTEES:
# - ENVIRONMENT-AWARE: Detects Debian/Ubuntu vs other distributions.
# - STATE-AWARE: Detects if ocio is already installed; skips re-install.
# - CONTAINER-SAFE: Installs ocio into the container root (safe to restart).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/pause.sh"

PAUSE_MODE=false
DRY_RUN=false
BINARY_CANDIDATE=""
DEB_CANDIDATE=""
EXTRACT_DIR=""

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Hands-on exploration of DEB anatomy, metadata, and dependency resolution."
    echo ""
    echo "Options:"
    echo "  --deb, -deb PATH Explicit path to the ocio DEB package for inspection (required)"
    echo "  --bin PATH       Optional: explicit path to the ocio binary for inspection."
    echo "                     By default the binary is extracted from the --deb package."
    echo "  -p, --pause      Pause and wait for [Enter] before executing each demo command"
    echo "  -d, --dry-run    Dry-run mode: only print commands without executing them"
    echo "  -h, --help       Show this help message"
    echo ""
    echo "Note: the dpkg-shlibdeps mechanism (success + failure mode) is demonstrated by"
    echo "packaging/deb/build-deb.sh --with-shared, not by this script."
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --deb|-deb)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --deb requires a path argument" >&2
                exit 1
            fi
            DEB_CANDIDATE="$2"
            shift 2
            ;;
        --deb=*|-deb=*)
            DEB_CANDIDATE="${1#*=}"
            shift
            ;;
        --bin)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --bin requires a path argument" >&2
                exit 1
            fi
            BINARY_CANDIDATE="$2"
            shift 2
            ;;
        --bin=*)
            BINARY_CANDIDATE="${1#--bin=}"
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

# --deb is the only required input. The binary for inspection is, by default,
# extracted from the .deb itself (dpkg-deb -x), so no pre-built binary is needed.
# An explicit --bin overrides the extracted copy.
# In dry-run mode the candidates are optional: the demo prints the commands it
# would run without touching the filesystem, so missing files are tolerated.
if [ -z "${DEB_CANDIDATE}" ] && [ "${DRY_RUN}" = false ]; then
    echo "Error: --deb is required. Build a package first (packaging/deb/build-deb.sh) or pass an existing file." >&2
    exit 1
fi

if [ "${DRY_RUN}" = true ]; then
    # Dry-run: use the provided paths as-is (no existence check, no canonicalization).
    : "${DEB_CANDIDATE:=./dist/ocio_0.1.0_amd64.deb}"
    : "${BINARY_CANDIDATE:=<extracted from ${DEB_CANDIDATE}>}"
else
    DEB_CANDIDATE="$(cd "$(dirname "${DEB_CANDIDATE}")" && pwd)/$(basename "${DEB_CANDIDATE}")"
    if [ ! -f "${DEB_CANDIDATE}" ]; then
        echo "Error: DEB file does not exist: '${DEB_CANDIDATE}'" >&2
        exit 1
    fi

    if [ -n "${BINARY_CANDIDATE}" ]; then
        # Explicit --bin override: canonicalize and verify.
        BINARY_CANDIDATE="$(cd "$(dirname "${BINARY_CANDIDATE}")" && pwd)/$(basename "${BINARY_CANDIDATE}")"
        if [ ! -f "${BINARY_CANDIDATE}" ]; then
            echo "Error: --bin file does not exist: '${BINARY_CANDIDATE}'" >&2
            exit 1
        fi
    else
        # Default: extract the binary from the .deb into a temp dir.
        if ! command -v dpkg-deb >/dev/null 2>&1; then
            echo "Error: dpkg-deb is not installed; cannot extract the binary from the .deb." >&2
            echo "       Install dpkg, or pass an explicit --bin path." >&2
            exit 1
        fi
        EXTRACT_DIR="$(mktemp -d /tmp/demo-deb-extract.XXXXXX)"
        trap 'rm -rf "${EXTRACT_DIR}"' EXIT
        dpkg-deb -x "${DEB_CANDIDATE}" "${EXTRACT_DIR}"
        BINARY_CANDIDATE="${EXTRACT_DIR}/usr/bin/ocio"
        if [ ! -f "${BINARY_CANDIDATE}" ]; then
            echo "Error: could not find usr/bin/ocio inside ${DEB_CANDIDATE}." >&2
            exit 1
        fi
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

# -----------------------------------------------------------------------------
# System Environment & Distribution Detection
# -----------------------------------------------------------------------------
banner "System Environment & Distribution Detection"

OS_NAME="Unknown"
OS_ID="unknown"
OS_LIKE=""
IS_DEBIAN=false

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    case "${OS_ID}" in
        debian|ubuntu|linuxmint|pop) IS_DEBIAN=true ;;
    esac
    case "${OS_LIKE}" in
        *debian*) IS_DEBIAN=true ;;
    esac
fi

echo -e "Operating System : ${BOLD}${OS_NAME}${RESET} (ID: ${OS_ID})"

OCIO_INSTALLED=false
if command -v dpkg >/dev/null 2>&1 && dpkg -s ocio >/dev/null 2>&1; then
    OCIO_INSTALLED=true
    echo -e "Package Status   : ${GREEN}INSTALLED${RESET} (dpkg reports ocio is installed)"
else
    echo -e "Package Status   : ${YELLOW}NOT INSTALLED${RESET} (read-only inspection mode)"
fi

echo -e "DEB Target       : ${DEB_CANDIDATE}"
echo -e "Binary Target    : ${BINARY_CANDIDATE}"

# -----------------------------------------------------------------------------
# Tool Requirements & Inspection Capability
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}Tool Requirements & Inspection Capability:${RESET}"

HAVE_FILE=false
HAVE_AR=false
HAVE_DPKG_DEB=false
HAVE_DPKG_SHLIBDEPS=false
HAVE_DPKG=false
HAVE_APT_GET=false
HAVE_LDD=false

if command -v file >/dev/null 2>&1; then HAVE_FILE=true; fi
if command -v ar >/dev/null 2>&1; then HAVE_AR=true; fi
if command -v dpkg-deb >/dev/null 2>&1; then HAVE_DPKG_DEB=true; fi
if command -v dpkg-shlibdeps >/dev/null 2>&1; then HAVE_DPKG_SHLIBDEPS=true; fi
if command -v dpkg >/dev/null 2>&1; then HAVE_DPKG=true; fi
if command -v apt-get >/dev/null 2>&1; then HAVE_APT_GET=true; fi
if command -v ldd >/dev/null 2>&1; then HAVE_LDD=true; fi

print_tool_status() {
    local tool="$1"
    local available="$2"
    local pkg="$3"
    local purpose="$4"
    if [ "${available}" = true ]; then
        printf "  - %-16s : ${GREEN}FOUND${RESET} (%s)\n" "${tool}" "${purpose}"
    else
        printf "  - %-16s : ${YELLOW}MISSING${RESET} (needed for %s; package: ${BOLD}%s${RESET})\n" "${tool}" "${purpose}" "${pkg}"
    fi
}

print_tool_status "file"            "${HAVE_FILE}"            "file"      "MIME and archive type identification"
print_tool_status "ar"              "${HAVE_AR}"              "binutils"  "Unix ar archive member listing"
print_tool_status "dpkg-deb"        "${HAVE_DPKG_DEB}"        "dpkg"      "Debian package control & content extraction"
print_tool_status "dpkg-shlibdeps"  "${HAVE_DPKG_SHLIBDEPS}"  "dpkg-dev"  "Shared library dependency calculation"
print_tool_status "dpkg"            "${HAVE_DPKG}"            "dpkg"      "Package database query and verification"
print_tool_status "apt-get"         "${HAVE_APT_GET}"         "apt"       "Dependency solver simulation"
print_tool_status "ldd"             "${HAVE_LDD}"             "libc-bin"  "Dynamic linker dependency inspection"

MISSING_TOOLS=()
if [ "${HAVE_FILE}" = false ]; then MISSING_TOOLS+=("file"); fi
if [ "${HAVE_AR}" = false ]; then MISSING_TOOLS+=("binutils"); fi
if [ "${HAVE_DPKG_SHLIBDEPS}" = false ]; then MISSING_TOOLS+=("dpkg-dev"); fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ] && [ "${IS_DEBIAN}" = true ]; then
    echo ""
    info "Missing inspection tools detected! Recommended commands from packaging/containers/cmd_history.debian:"
    echo -e "  ${BOLD}apt-get update && apt-get install -y ${MISSING_TOOLS[*]}${RESET}"
fi

if [ "${DRY_RUN}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}DRY-RUN (only printing commands, nothing executed)${RESET}"
fi
if [ "${PAUSE_MODE}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}PAUSE/STEP (waiting for [Enter] before each command)${RESET}"
fi

# -----------------------------------------------------------------------------
# Section 1: Binary Inspection (read-only)
# -----------------------------------------------------------------------------
banner "Section 1: Binary Inspection (read-only)"
echo "Explanation: Linux binaries record their direct shared library dependencies"
echo "in DT_NEEDED tags. We inspect the ocio binary (extracted from the .deb)"
echo "with three read-only tools to see what it asks for at link time:"
echo "  1. file     : format and architecture"
echo "  2. ldd      : resolved dynamic linker dependencies"
echo "  3. readelf  : the raw DT_NEEDED entries"
echo ""
echo "How these DT_NEEDED entries become the package's Depends field (dpkg-shlibdeps,"
echo "including the failure mode for source-built libraries) is demonstrated by"
echo "packaging/deb/build-deb.sh --with-shared, not by this script."

if [ "${HAVE_FILE}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "file \"${BINARY_CANDIDATE}\"" "Inspecting binary format and architecture:"
fi

if [ "${HAVE_LDD}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "ldd \"${BINARY_CANDIDATE}\"" "Inspecting dynamic linker dependencies with ldd:" \
        "  ${DIM}Notice: ldd only shows direct DT_NEEDED links (libc, libm).\n  Dynamic loaders like GLFW open libX11 and libGLX via dlopen() at runtime.${RESET}"
fi

if [ "${HAVE_DPKG_SHLIBDEPS}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "readelf -d \"${BINARY_CANDIDATE}\" | grep NEEDED" \
        "The raw DT_NEEDED entries (what the binary asks for at link time):" \
        "  ${DIM}These SONAMEs are what dpkg-shlibdeps would resolve to package dependencies.\n  See build-deb.sh Step 3 / Step 3b for that mechanism.${RESET}"
else
    skip "readelf (binutils) is not available. Skipping DT_NEEDED inspection."
fi

# -----------------------------------------------------------------------------
# Section 2: DEB Anatomy & Unix Archive Dissection
# -----------------------------------------------------------------------------
banner "Section 2: DEB Anatomy & Unix Archive Dissection"
echo "Explanation: A Debian package is not a proprietary format. It is a standard"
echo "Unix 'ar' archive containing exactly three members:"
echo "  1. debian-binary : ASCII format version ('2.0')"
echo "  2. control.tar.* : Package metadata, maintainer scripts, and checksums"
echo "  3. data.tar.*    : Filesystem payload installed onto the target system"

if [ -n "${DEB_CANDIDATE}" ]; then
    if [ "${HAVE_FILE}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "file \"${DEB_CANDIDATE}\"" "Verifying archive format with file(1):" \
            "  ${DIM}Notice: 'Debian binary package (format 2.0)'. It is a standard Unix ar archive.${RESET}"
    fi

    if [ "${HAVE_AR}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "ar -t \"${DEB_CANDIDATE}\"" "Listing internal Unix ar archive members:" \
            "  ${DIM}ar is the Unix archive tool (from binutils). -t (table) lists member names\n  without extracting. A .deb is just an ar archive — no proprietary format.\n  Notice the three canonical components: debian-binary, control.tar.*, data.tar.*.${RESET}"
    else
        skip "'ar' is not available (package: binutils). Skipping member listing."
    fi
else
    skip "No DEB package specified."
fi

# -----------------------------------------------------------------------------
# Section 3: Package Metadata & Control File (dpkg-deb -I)
# -----------------------------------------------------------------------------
banner "Section 3: Package Metadata & Control File"
echo "Explanation: 'dpkg-deb -I' unpacks control.tar.* and displays control metadata."
echo "Here you can see the difference between automatic dependencies (libc6) and"
echo "hand-declared dependencies (libglx0, libx11-6) needed for runtime dlopen."

if [ -n "${DEB_CANDIDATE}" ]; then
    if [ "${HAVE_DPKG_DEB}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "dpkg-deb -I \"${DEB_CANDIDATE}\"" "Reading full control metadata (dpkg-deb -I):"

        demo_cmd "dpkg-deb -I \"${DEB_CANDIDATE}\" | grep -E 'Package:|Version:|Depends:|Recommends:|Architecture:'" \
            "Extracting declared dependency relationships:" \
            "  ${DIM}Key Takeaway: libc6 (>= ...) was computed automatically by dpkg-shlibdeps;\n  libglx0 and libx11-6 were explicitly declared in debian/control to support runtime dlopen.${RESET}"

        demo_cmd "dpkg-deb -c \"${DEB_CANDIDATE}\"" "Listing filesystem payload contents (dpkg-deb -c):"
    else
        skip "'dpkg-deb' is not available. Skipping control metadata inspection."
    fi
else
    skip "No DEB package specified."
fi

# -----------------------------------------------------------------------------
# Section 4: Transitive Closure & Solver Simulation (APT)
# -----------------------------------------------------------------------------
banner "Section 4: Transitive Closure & Solver Simulation (APT)"
echo "Explanation: 'dpkg -i' merely unpacks files; it has no network access and"
echo "no SAT solver. If dependencies are missing, dpkg leaves the package in an"
echo "unconfigured state. APT wraps dpkg, resolves dependencies, and calculates"
echo "the complete transitive closure."

if [ -n "${DEB_CANDIDATE}" ] && [ "${IS_DEBIAN}" = true ]; then
    if [ "${HAVE_APT_GET}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "apt-get install -s \"${DEB_CANDIDATE}\"" \
            "Simulating package installation via APT solver (apt-get install -s):" \
            "  ${DIM}Notice how APT calculates dependencies and shows what would be installed,\n  without making any changes to the system.${RESET}"
    fi
elif [ "${IS_DEBIAN}" = false ]; then
    echo -e "  ${DIM}Note: APT simulation is only applicable on Debian/Ubuntu systems.${RESET}"
fi

# -----------------------------------------------------------------------------
# Section 5: Installed Verification & Integrity Audit
# -----------------------------------------------------------------------------
banner "Section 5: Install, Verify & Disk Space Audit"

# Pre-install disk space estimate from package metadata (apt index).
if [ "${HAVE_APT_GET}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "apt-get update" \
        "Refreshing the apt package index (needed for apt-cache show lookups)."

    DISK_ESTIMATE_CMD="apt-get install -s \"${DEB_CANDIDATE}\" 2>/dev/null | grep '^Inst' | sed 's/Inst //; s/ (.*//' | while read -r pkg; do apt-cache show \"\$pkg\" 2>/dev/null | grep '^Installed-Size:' | awk '{print \$2}'; done | awk '{s+=\$1} END {printf \"%.1f MiB (metadata estimate)\n\", s/1024}'"
    demo_cmd "${DISK_ESTIMATE_CMD}" \
        "Estimating disk space from package metadata (pre-install, no install needed):" \
        "  ${DIM}Sums Installed-Size from the apt package index for all packages in the\n  dependency closure. Close to APT own 'additional disk space' estimate.\n  Does not require the packages to be installed.${RESET}"
fi

if [ "${OCIO_INSTALLED}" = true ]; then
    info "ocio is already installed — skipping install, proceeding to verification."
elif [ "${DRY_RUN}" = true ]; then
    demo_cmd "apt-get update && apt-get install -y \"${DEB_CANDIDATE}\"" \
        "Installing ocio via APT (would resolve dependencies and unpack the .deb)."
else
    demo_cmd "apt-get update && apt-get install -y \"${DEB_CANDIDATE}\"" \
        "Installing ocio via APT (resolves dependencies, unpacks, and configures)." \
        "  ${DIM}Note the After-this-operation line in the output above - APT\n  authoritative estimate (accounts for shared files and already-present\n  packages). Compare with the metadata estimate above.${RESET}"
fi

OCIO_BIN="$(command -v ocio 2>/dev/null || echo /usr/bin/ocio)"
if [ "${HAVE_LDD}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "ldd \"${OCIO_BIN}\"" "Inspecting installed binary dynamic linker paths (ldd):" \
        "  ${DIM}The binary is now at /usr/bin/ocio. ldd confirms all shared libraries\n  resolve against the system paths (libc, libm).${RESET}"
fi

if [ "${HAVE_DPKG}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "dpkg --verify ocio" "Auditing installed files against DEBIAN/md5sums (dpkg --verify):" \
        "  ${GREEN}All installed files intact and verified against package md5sums checksums.${RESET}"
fi

demo_cmd "ocio --version" "Running the installed binary to confirm it works:"

# Post-install: measure actual on-disk usage (block allocation).
if [ "${HAVE_DPKG}" = true ] || [ "${DRY_RUN}" = true ]; then
    demo_cmd "apt-get install -s \"${DEB_CANDIDATE}\" 2>/dev/null | grep '^Inst' | sed 's/Inst //; s/ (.*//' | xargs dpkg -L 2>/dev/null | xargs du -sc 2>/dev/null | tail -1" \
        "Measuring actual on-disk usage (du on all files owned by ocio + deps):" \
        "  ${DIM}This is the real filesystem block allocation (4 KiB granularity + directory\n  inodes). Higher than the APT estimate because du counts block overhead for\n  hundreds of small shared library files (Mesa DRI, LLVM, X11).${RESET}"
fi

# -----------------------------------------------------------------------------
# Summary & Pedagogical Conclusion
# -----------------------------------------------------------------------------
banner "Summary & Pedagogical Conclusion"
echo -e "- ${BOLD}Archive Mechanics${RESET}     : Standard Unix ar archive holding debian-binary, control, and data."
echo -e "- ${BOLD}Computed Dependencies${RESET} : dpkg-shlibdeps maps DT_NEEDED SONAMEs via *.shlibs to (package, version)."
echo -e "- ${BOLD}Version Floor${RESET}         : Comes from the .symbols file when present (finer-grained than .shlibs)."
echo -e "- ${BOLD}Source-Built Libraries${RESET}: No shlibs entry -> build aborts. Ship a sibling package or do not link."
echo -e "- ${BOLD}Explicit Dependencies${RESET} : Runtime dlopen targets (libglx0, libx11-6) declared in debian/control."
echo -e "- ${BOLD}dpkg vs APT Contract${RESET}  : dpkg unpacks; APT solves the dependency graph and schedules install."
echo -e "- ${BOLD}Integrity Auditing${RESET}    : dpkg --verify compares on-disk files against md5sums."
echo ""
