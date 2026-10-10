#!/usr/bin/env bash
# =============================================================================
# demo-appimage.sh: Hands-on Exploration of AppImage Anatomy, Header Magic & Mount Lifecycle
# =============================================================================
# This script demonstrates how AppImage packages are physically structured,
# how the ELF runtime stub uses the EI_PAD header trick for O(1) identification,
# how the embedded SquashFS payload is detected and inspected at its exact byte offset,
# and how the ephemeral FUSE mount lifecycle functions at runtime.
#
# Key Takeaway: An AppImage is not an archive with an installer. It is a composite
# binary consisting of an ELF static-pie launcher prepended to a compressed SquashFS
# filesystem image. The host kernel executes the stub, which mounts the payload via
# FUSE to /tmp/.mount_* and hands execution to AppRun.
#
# GUARANTEES:
# - READ-ONLY: Never modifies the host system, installs no packages.
# - ENVIRONMENT-AWARE: Detects host OS, checks FUSE (/dev/fuse, fusermount3).
# - ARTIFACT-AWARE: Auto-detects dist/ocio-x86_64.AppImage or accepts --appimage.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

PAUSE_MODE=false
DRY_RUN=false
BINARY_CANDIDATE=""
APPIMAGE_CANDIDATE=""

usage() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Hands-on exploration of AppImage anatomy, header magic, and mount lifecycle."
    echo ""
    echo "Options:"
    echo "  --appimage, -appimage PATH Explicit path to the ocio AppImage package for inspection"
    echo "  --bin PATH                 Explicit path to the ocio binary for comparison"
    echo "  -p, --pause                Pause and wait for [Enter] before executing each demo command"
    echo "  -d, --dry-run              Dry-run mode: only print commands without executing them"
    echo "  -h, --help                 Show this help message"
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        --appimage|-appimage)
            if [ $# -lt 2 ] || [ -z "$2" ]; then
                echo "Error: --appimage requires a path argument" >&2
                exit 1
            fi
            APPIMAGE_CANDIDATE="$2"
            shift 2
            ;;
        --appimage=*|-appimage=*)
            APPIMAGE_CANDIDATE="${1#*=}"
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

# Resolve AppImage candidate if not explicitly provided
if [ -z "${APPIMAGE_CANDIDATE}" ]; then
    for candidate in "${REPO_ROOT}/dist/ocio-x86_64.AppImage" "${REPO_ROOT}/dist/"ocio-*.AppImage; do
        if [ -f "${candidate}" ]; then
            APPIMAGE_CANDIDATE="${candidate}"
            break
        fi
    done
fi

if [ -n "${APPIMAGE_CANDIDATE}" ]; then
    APPIMAGE_CANDIDATE="$(cd "$(dirname "${APPIMAGE_CANDIDATE}")" && pwd)/$(basename "${APPIMAGE_CANDIDATE}")"
    if [ ! -f "${APPIMAGE_CANDIDATE}" ]; then
        echo "Error: AppImage file does not exist: '${APPIMAGE_CANDIDATE}'" >&2
        exit 1
    fi
fi

if [ -n "${BINARY_CANDIDATE}" ]; then
    BINARY_CANDIDATE="$(cd "$(dirname "${BINARY_CANDIDATE}")" && pwd)/$(basename "${BINARY_CANDIDATE}")"
    if [ ! -f "${BINARY_CANDIDATE}" ]; then
        echo "Error: --bin file does not exist: '${BINARY_CANDIDATE}'" >&2
        exit 1
    fi
fi

# Formatting helpers
if [ -t 1 ]; then
    BOLD="\033[1m"
    GREEN="\033[1;32m"
    BLUE="\033[1;34m"
    YELLOW="\033[1;33m"
    RED="\033[1;31m"
    CYAN="\033[1;36m"
    DIM="\033[2m"
    RESET="\033[0m"
else
    BOLD="" GREEN="" BLUE="" YELLOW="" RED="" CYAN="" DIM="" RESET=""
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

pause_prompt() {
    local prompt_msg="${1:-}"
    if [ "${PAUSE_MODE}" = true ]; then
        echo -ne "${prompt_msg}"
        if [ -c /dev/tty ] && [ -r /dev/tty ]; then
            read -s -r _ < /dev/tty 2>/dev/null || read -s -r _ 2>/dev/null || true
        else
            read -s -r _ 2>/dev/null || read -r _ 2>/dev/null || true
        fi
        printf "\r\033[2K"
    fi
}

demo_cmd() {
    local cmd="$1"
    local desc="${2:-}"
    local comment="${3:-}"

    if [ -n "${desc}" ]; then
        substep "${desc}"
    fi

    echo ""
    echo -e "  ${CYAN}┌──[ Command to Run ]──────────────────────────────────────────────────${RESET}"
    echo -e "  ${BOLD}${YELLOW}${cmd}${RESET}"

    if [ "${DRY_RUN}" = true ]; then
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"
        if [ -n "${comment}" ]; then
            echo -e "${comment}"
        fi
        return 0
    fi

    echo -e "  ${CYAN}├──[ Output ]──────────────────────────────────────────────────────────${RESET}"
    pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to execute (or Ctrl+C to stop)... "
    eval "${cmd}" || true
    echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"

    if [ -n "${comment}" ]; then
        echo -e "${comment}"
    fi

    pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to continue (or Ctrl+C to stop)... "
}

# -----------------------------------------------------------------------------
# System Environment & Distribution Detection
# -----------------------------------------------------------------------------
banner "System Environment & Distribution Detection"

OS_NAME="Unknown"
OS_ID="unknown"
OS_LIKE=""
IS_DEBIAN=false
IS_OPENSUSE=false
IS_FEDORA=false

if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_NAME="${PRETTY_NAME:-$NAME}"
    OS_ID="${ID:-unknown}"
    OS_LIKE="${ID_LIKE:-}"
    case "${OS_ID}" in
        debian|ubuntu|linuxmint|pop) IS_DEBIAN=true ;;
        opensuse*|sles)             IS_OPENSUSE=true ;;
        fedora|rhel|centos|rocky)   IS_FEDORA=true ;;
    esac
    case "${OS_LIKE}" in
        *debian*)        IS_DEBIAN=true ;;
        *suse*)          IS_OPENSUSE=true ;;
        *fedora*|*rhel*) IS_FEDORA=true ;;
    esac
fi

echo -e "Operating System : ${BOLD}${OS_NAME}${RESET} (ID: ${OS_ID}, LIKE: ${OS_LIKE:-none})"

# Check FUSE availability & fusermount binary on PATH
HAVE_DEV_FUSE=false
DEV_FUSE_WRITABLE=false
HAVE_FUSERMOUNT=false
HAVE_FUSERMOUNT3=false
FUSERMOUNT_BIN=""
FUSERMOUNT_VERSION=""
FUSE_CAPABILITIES=""

if [ -e /dev/fuse ]; then
    HAVE_DEV_FUSE=true
    if [ -w /dev/fuse ]; then
        DEV_FUSE_WRITABLE=true
    fi
fi

if command -v fusermount3 >/dev/null 2>&1; then
    HAVE_FUSERMOUNT3=true
    FUSERMOUNT_BIN="$(command -v fusermount3)"
elif command -v fusermount >/dev/null 2>&1; then
    HAVE_FUSERMOUNT=true
    FUSERMOUNT_BIN="$(command -v fusermount)"
fi

if [ -n "${FUSERMOUNT_BIN}" ]; then
    FUSERMOUNT_VERSION="$("${FUSERMOUNT_BIN}" -V 2>&1 | tr -d '\r' || true)"
    if [ -u "${FUSERMOUNT_BIN}" ]; then
        FUSE_CAPABILITIES="setuid-root"
    elif [ -x "${FUSERMOUNT_BIN}" ]; then
        FUSE_CAPABILITIES="executable"
    fi
fi

IS_CONTAINER=false
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    IS_CONTAINER=true
fi

if [ "${HAVE_DEV_FUSE}" = true ] && [ "${DEV_FUSE_WRITABLE}" = true ] && [ -n "${FUSERMOUNT_BIN}" ]; then
    echo -e "FUSE Subsystem   : ${GREEN}READY${RESET} (/dev/fuse rw, ${FUSERMOUNT_BIN##*/} available)"
    echo -e "FUSE Binary      : ${BOLD}${FUSERMOUNT_BIN}${RESET} (${FUSERMOUNT_VERSION:-version unknown}, mode: ${FUSE_CAPABILITIES:-standard})"
elif [ -z "${FUSERMOUNT_BIN}" ]; then
    echo -e "FUSE Subsystem   : ${RED}NOT READY${RESET} (fusermount missing on \$PATH)"
    echo -e "  ${RED}--> Error: No suitable fusermount binary found on the \$PATH${RESET}"
    echo -e "  ${DIM}AppImage runtime relies on fusermount/fusermount3 to mount SquashFS without root.${RESET}"
    if [ "${HAVE_DEV_FUSE}" = false ]; then
        echo -e "  ${DIM}Additionally, /dev/fuse is missing (pass --device /dev/fuse in containers).${RESET}"
    fi
    if [ "${IS_DEBIAN}" = true ]; then
        echo -e "  ${YELLOW}Notice:${RESET} Required command from packaging/containers/cmd_history.debian:"
        echo -e "    ${BOLD}apt-get install -y fuse3${RESET}"
    fi
elif [ "${HAVE_DEV_FUSE}" = false ]; then
    echo -e "FUSE Subsystem   : ${RED}NOT READY${RESET} (/dev/fuse missing)"
    echo -e "  ${RED}--> Cannot mount AppImage, please check your FUSE setup.${RESET}"
    if [ "${IS_CONTAINER}" = true ]; then
        echo -e "  ${DIM}Container environment detected. Start container with: --device /dev/fuse (and --privileged or --cap-add SYS_ADMIN).${RESET}"
    fi
elif [ "${DEV_FUSE_WRITABLE}" = false ]; then
    echo -e "FUSE Subsystem   : ${RED}NOT READY${RESET} (/dev/fuse is not writable by current user)"
    echo -e "  ${RED}--> Cannot mount AppImage, please check your FUSE setup.${RESET}"
fi

echo -e "AppImage Target  : ${APPIMAGE_CANDIDATE:-None detected (run packaging/appimage/build-appimage.sh or use --appimage)}"
echo -e "Binary Target    : ${BINARY_CANDIDATE:-None specified (use --bin /path/to/binary)}"

# -----------------------------------------------------------------------------
# Tool Requirements & Inspection Capability
# -----------------------------------------------------------------------------
echo -e "\n${BOLD}Tool Requirements & Inspection Capability:${RESET}"

HAVE_FILE=false
HAVE_XXD=false
HAVE_HEXDUMP=false
HAVE_UNSQUASHFS=false
HAVE_READELF=false
HAVE_STRINGS=false
HAVE_DF=false
HAVE_ANY_FUSERMOUNT=false
if [ -n "${FUSERMOUNT_BIN}" ]; then HAVE_ANY_FUSERMOUNT=true; fi

if command -v file >/dev/null 2>&1; then HAVE_FILE=true; fi
if command -v xxd >/dev/null 2>&1; then HAVE_XXD=true; fi
if command -v hexdump >/dev/null 2>&1; then HAVE_HEXDUMP=true; fi
if command -v unsquashfs >/dev/null 2>&1; then HAVE_UNSQUASHFS=true; fi
if command -v readelf >/dev/null 2>&1; then HAVE_READELF=true; fi
if command -v strings >/dev/null 2>&1; then HAVE_STRINGS=true; fi
if command -v df >/dev/null 2>&1; then HAVE_DF=true; fi

print_tool_status() {
    local tool="$1"
    local available="$2"
    local pkg="$3"
    local purpose="$4"
    if [ "${available}" = true ]; then
        printf "  - %-12s : ${GREEN}FOUND${RESET} (%s)\n" "${tool}" "${purpose}"
    else
        printf "  - %-12s : ${YELLOW}MISSING${RESET} (needed for %s; package: ${BOLD}%s${RESET})\n" "${tool}" "${purpose}" "${pkg}"
    fi
}

print_tool_status "file"        "${HAVE_FILE}"        "file"                      "ELF type and PIE identification"
print_tool_status "xxd"         "${HAVE_XXD}"         "xxd"                       "Byte forensics & EI_PAD inspection"
print_tool_status "unsquashfs"  "${HAVE_UNSQUASHFS}"  "squashfs-tools / squashfs" "SquashFS superblock & tree inspection"
print_tool_status "readelf"     "${HAVE_READELF}"     "binutils"                  "Static-pie header & DT_NEEDED audit"
print_tool_status "strings"     "${HAVE_STRINGS}"     "binutils"                  "GLIBC symbol baseline extraction"
print_tool_status "fusermount"  "${HAVE_ANY_FUSERMOUNT}" "fuse3 / fuse"           "FUSE userspace mount helper"
print_tool_status "df"          "${HAVE_DF}"          "coreutils"                 "Mounted virtual filesystem metrics"

# Calculate missing packages per distribution
MISSING_DEB=()
MISSING_RPM=()

if [ "${HAVE_FILE}" = false ]; then
    MISSING_DEB+=("file")
    MISSING_RPM+=("file")
fi
if [ "${HAVE_XXD}" = false ] && [ "${HAVE_HEXDUMP}" = false ]; then
    MISSING_DEB+=("xxd")
    MISSING_RPM+=("xxd")
fi
if [ "${HAVE_UNSQUASHFS}" = false ]; then
    MISSING_DEB+=("squashfs-tools")
    MISSING_RPM+=("squashfs")
fi
if [ "${HAVE_READELF}" = false ] || [ "${HAVE_STRINGS}" = false ]; then
    MISSING_DEB+=("binutils")
    MISSING_RPM+=("binutils")
fi
if [ "${HAVE_ANY_FUSERMOUNT}" = false ]; then
    MISSING_DEB+=("fuse3")
    MISSING_RPM+=("fuse3")
fi

if [ ${#MISSING_DEB[@]} -gt 0 ]; then
    echo ""
    info "Missing inspection/runtime tools detected! Recommended commands from packaging/containers/cmd_history.debian:"
    if [ "${IS_DEBIAN}" = true ]; then
        echo -e "  ${BOLD}apt-get update${RESET}"
        echo -e "  ${BOLD}apt-get install file xxd squashfs-tools binutils${RESET}"
        echo -e "  ${BOLD}apt-get install -y fuse3${RESET}"
    elif [ "${IS_OPENSUSE}" = true ]; then
        info "Missing inspection/runtime tools detected! Recommended commands from packaging/containers/cmd_history.opensuse:"
        echo -e "  ${BOLD}zypper in -y binutils rpm squashfs fuse3${RESET}"
    else
        echo -e "  ${BOLD}apt-get install file xxd squashfs-tools binutils fuse3${RESET}"
    fi

    if [ "${HAVE_ANY_FUSERMOUNT}" = false ]; then
        echo ""
        echo -e "  ${RED}${BOLD}Error: No suitable fusermount binary found on the \$PATH${RESET}"
        echo -e "  ${DIM}AppImage runtime relies on fusermount/fusermount3 to mount SquashFS without root.${RESET}"
        if [ "${IS_DEBIAN}" = true ]; then
            echo -e "  ${YELLOW}Fix:${RESET} Install fuse3 with: ${BOLD}apt-get install -y fuse3${RESET}"
        fi
    fi
fi

if [ "${DRY_RUN}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}DRY-RUN (only printing commands, nothing executed)${RESET}"
fi
if [ "${PAUSE_MODE}" = true ]; then
    echo -e "Execution Mode   : ${YELLOW}PAUSE/STEP (waiting for [Enter] before each command)${RESET}"
fi

if [ -z "${APPIMAGE_CANDIDATE}" ]; then
    echo ""
    info "No AppImage package found. Please build one first with:"
    echo -e "  ${BOLD}packaging/appimage/build-appimage.sh${RESET}"
    echo -e "  or pass an existing file with: ${BOLD}--appimage /path/to/file.AppImage${RESET}"
fi

# -----------------------------------------------------------------------------
# Section 1: ELF Static-PIE Runtime Stub & EI_PAD Header Magic
# -----------------------------------------------------------------------------
banner "Section 1: ELF Static-PIE Runtime Stub & EI_PAD Header Magic"
echo "Explanation: Every AppImage begins with an ELF executable runtime stub."
echo "The stub is a self-sufficient static-pie binary (compiled with musl libc"
echo "and squashfuse) responsible for mounting the payload and launching AppRun."
echo "To allow instant format detection without parsing megabytes of SquashFS,"
echo "AppImage Type 2 embeds 'AI\\x02' into the unused EI_PAD field of the ELF header."

if [ -n "${APPIMAGE_CANDIDATE}" ]; then
    if [ "${HAVE_FILE}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "file \"${APPIMAGE_CANDIDATE}\"" \
            "Inspecting binary file type with file(1):" \
            "  ${DIM}Notice: 'ELF 64-bit LSB pie executable, static-pie linked'.\n  The file is directly executable by the Linux kernel without helper scripts.${RESET}"
    else
        skip "'file' command is not available. Skipping file type inspection."
    fi

    HEX_COMMENT="  ${BOLD}Header Anatomy (16-byte e_ident array):${RESET}\n  ┌──────────┬─────────────────────┬──────────────┬──────────────────┐\n  │  00..03  │        04..07       │    08..0A    │      0B..0F      │\n  ├──────────┼─────────────────────┼──────────────┼──────────────────┤\n  │  \\\\x7fELF │  x86_64 / System V  │   ${GREEN}AI\\\\x02${RESET}     │  padding (0x00)  │\n  └──────────┴─────────────────────┴──────────────┴──────────────────┘\n  ${DIM}Why this is brilliant:\n  1. Zero execution penalty: Linux kernel loader ignores EI_PAD padding.\n  2. Instant O(1) detection: desktop managers detect AppImage by checking 11 bytes.\n  3. Clean versioning: AI\\\\x01 = Type 1 (ISO 9660), AI\\\\x02 = Type 2 (SquashFS).${RESET}"

    if [ "${HAVE_XXD}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "xxd -l 96 -d \"${APPIMAGE_CANDIDATE}\"" "Hex dump of the first 96 bytes (e_ident & ELF header):" "${HEX_COMMENT}"
    elif [ "${HAVE_HEXDUMP}" = true ]; then
        demo_cmd "hexdump -C -n 96 \"${APPIMAGE_CANDIDATE}\"" "Hex dump of the first 96 bytes (hexdump fallback):" "${HEX_COMMENT}"
    else
        skip "'xxd' and 'hexdump' are not available. Skipping header hex dump."
    fi

    if [ "${HAVE_READELF}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "readelf -d \"${APPIMAGE_CANDIDATE}\"" \
            "Auditing dynamic section of runtime stub (readelf -d):" \
            "  ${DIM}Notice: 0 DT_NEEDED entries! The runtime stub is static-pie linked with musl libc.\n  It requires no shared libraries from the host just to start and mount the image.${RESET}"
    fi
else
    skip "No AppImage specified. Pass --appimage /path/to/ocio.AppImage to inspect."
fi

# -----------------------------------------------------------------------------
# Section 2: The Two-Part Seam & Offset Detection
# -----------------------------------------------------------------------------
banner "Section 2: The Two-Part Seam & Offset Detection"
echo "Explanation: An AppImage is a composite binary with two distinct parts:"
echo "1. Bytes 0 to (offset - 1)  : ELF static-pie runtime stub (~944 KiB)"
echo "2. Bytes offset to EOF      : Compressed SquashFS filesystem payload (~461 KiB)"
echo "The runtime stub supports the '--appimage-offset' flag to print this exact seam."

OFFSET="944632"
if [ -n "${APPIMAGE_CANDIDATE}" ]; then
    demo_cmd "\"${APPIMAGE_CANDIDATE}\" --appimage-offset" "Querying byte offset of the embedded SquashFS payload:"
    if [ "${DRY_RUN}" != true ]; then
        DETECTED_OFFSET="$("${APPIMAGE_CANDIDATE}" --appimage-offset 2>/dev/null || echo "")"
        if [ -n "${DETECTED_OFFSET}" ]; then
            OFFSET="${DETECTED_OFFSET}"
        fi
    fi

    SEAM_COMMENT="  ${DIM}Dividing Seam Breakdown:\n  - Stub size    : 0 .. $((OFFSET - 1)) ($((OFFSET / 1024)) KiB)\n  - Payload size : ${OFFSET} .. EOF\n  - Total size   : fits comfortably on a physical 1.44 MB floppy disk prop!${RESET}"
    demo_cmd "ls -lh \"${APPIMAGE_CANDIDATE}\"" "Total binary size on disk:" "${SEAM_COMMENT}"
else
    skip "No AppImage specified."
fi

# -----------------------------------------------------------------------------
# Section 3: SquashFS Payload Forensics (unsquashfs at Offset)
# -----------------------------------------------------------------------------
banner "Section 3: SquashFS Payload Forensics (unsquashfs at Offset)"
echo "Explanation: Because the payload is a standard SquashFS filesystem image,"
echo "forensic tools like 'unsquashfs' can inspect its superblock and directory tree"
echo "directly at the byte offset, without root privileges and without mounting."

if [ -n "${APPIMAGE_CANDIDATE}" ]; then
    if [ "${HAVE_UNSQUASHFS}" = true ] || [ "${DRY_RUN}" = true ]; then
        demo_cmd "unsquashfs -s -offset ${OFFSET} \"${APPIMAGE_CANDIDATE}\"" \
            "Reading SquashFS 4.0 superblock directly from file offset:" \
            "  ${DIM}Notice the compression algorithm (zstd), block size, and inode count.${RESET}"

        demo_cmd "unsquashfs -l -offset ${OFFSET} \"${APPIMAGE_CANDIDATE}\" | head -n 25" \
            "Listing internal payload hierarchy without extraction:" \
            "  ${DIM}Notice the FHS layout: AppRun, ocio.desktop, ocio.svg, and usr/bin/ocio.${RESET}"
    else
        skip "'unsquashfs' is not available (package: squashfs or squashfs-tools). Skipping."
    fi
else
    skip "No AppImage specified."
fi

# -----------------------------------------------------------------------------
# Section 4: Mount Lifecycle & Live Inspection (--appimage-mount)
# -----------------------------------------------------------------------------
banner "Section 4: Mount Lifecycle & Live Inspection (--appimage-mount)"
echo "Explanation: During standard launch, the stub creates /tmp/.mount_XXXXXX,"
echo "mounts the SquashFS payload using FUSE, executes AppRun, and unmounts upon exit."
echo "Instead of trying to capture this ephemeral mount with watch loops during game play,"
echo "AppImage provides '--appimage-mount' to mount, print the path, and stay open."

if [ -n "${APPIMAGE_CANDIDATE}" ]; then
    if [ "${DRY_RUN}" = true ]; then
        demo_cmd "\"${APPIMAGE_CANDIDATE}\" --appimage-mount &" \
            "Simulating mount lifecycle and live filesystem inspection:"
        demo_cmd "df -h | grep /tmp/.mount" \
            "Inspecting mounted virtual filesystem metrics (df -h):"
        demo_cmd "ls -la /tmp/.mount_*/" \
            "Inspecting mount root directory contents:"
        demo_cmd "readelf -d /tmp/.mount_*/usr/bin/ocio | grep NEEDED" \
            "Inspecting inner application dependencies (DT_NEEDED):" \
            "  ${DIM}Notice the difference: The outer stub had 0 NEEDED entries, but the\n  inner application binary depends on libc.so.6 and libm.so.6!${RESET}"
        demo_cmd "strings /tmp/.mount_*/usr/bin/ocio | grep -E '^GLIBC_2\.' | sort -V | tail -n 5" \
            "Extracting required GLIBC symbol baseline of inner binary:" \
            "  ${DIM}This is the ABI floor: hosts with glibc older than this version cannot run the app.${RESET}"
        demo_cmd "kill %1" \
            "Cleaning up background FUSE mount:" \
            "  ${GREEN}Mount cleanly unmounted and ephemeral directory removed.${RESET}"
    elif [ -z "${FUSERMOUNT_BIN}" ]; then
        skip "No suitable fusermount binary found on the \$PATH. Cannot perform live FUSE mount."
        echo -e "  ${RED}${BOLD}Error: No suitable fusermount binary found on the \$PATH${RESET}"
        if [ "${IS_DEBIAN}" = true ]; then
            echo -e "  ${YELLOW}Remedy:${RESET} Install fuse3 with: ${BOLD}apt-get install -y fuse3${RESET} (see packaging/containers/cmd_history.debian)"
        fi
    elif [ "${HAVE_DEV_FUSE}" = false ]; then
        skip "FUSE is not available on this host (/dev/fuse missing). Cannot perform live FUSE mount."
        echo -e "  ${RED}${BOLD}Cannot mount AppImage, please check your FUSE setup.${RESET}"
        echo -e "  ${YELLOW}Remedy:${RESET} In container environments, pass --device /dev/fuse (and --privileged or --cap-add SYS_ADMIN)."
    else
        substep "Executing live background mount with --appimage-mount:"
        MOUNT_TMP_OUT="$(mktemp)"

        echo ""
        echo -e "  ${CYAN}┌──[ Command to Run ]──────────────────────────────────────────────────${RESET}"
        echo -e "  ${BOLD}${YELLOW}\"${APPIMAGE_CANDIDATE}\" --appimage-mount &${RESET}"
        echo -e "  ${CYAN}├──[ Output ]──────────────────────────────────────────────────────────${RESET}"
        pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to execute (or Ctrl+C to stop)... "

        "${APPIMAGE_CANDIDATE}" --appimage-mount > "${MOUNT_TMP_OUT}" 2>&1 &
        MOUNT_PID=$!

        # Wait briefly for mount path to appear
        sleep 0.5
        MOUNT_POINT="$(head -n 1 "${MOUNT_TMP_OUT}" || echo "")"
        cat "${MOUNT_TMP_OUT}"
        echo -e "  ${CYAN}└──────────────────────────────────────────────────────────────────────${RESET}"

        if [ -n "${MOUNT_POINT}" ] && [ -d "${MOUNT_POINT}" ]; then
            echo -e "  ${GREEN}Active Mount Point:${RESET} ${BOLD}${MOUNT_POINT}${RESET} (PID: ${MOUNT_PID})"
            pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to continue (or Ctrl+C to stop)... "

            demo_cmd "df -h \"${MOUNT_POINT}\"" "Inspecting mounted virtual filesystem metrics (df -h):"
            demo_cmd "ls -la \"${MOUNT_POINT}\"" "Inspecting mount root directory contents:"

            if [ -f "${MOUNT_POINT}/usr/bin/ocio" ]; then
                demo_cmd "readelf -d \"${MOUNT_POINT}/usr/bin/ocio\" | grep NEEDED" \
                    "Inspecting inner application dependencies (DT_NEEDED):" \
                    "  ${DIM}Notice the difference: The outer stub had 0 NEEDED entries, but the\n  inner application binary depends on libc.so.6 and libm.so.6!${RESET}"

                demo_cmd "strings \"${MOUNT_POINT}/usr/bin/ocio\" | grep -E '^GLIBC_2\.' | sort -V | tail -n 5" \
                    "Extracting required GLIBC symbol baseline of inner binary:" \
                    "  ${DIM}This is the ABI floor: hosts with glibc older than this version cannot run the app.${RESET}"
            fi

            demo_cmd "kill ${MOUNT_PID}" \
                "Cleaning up background FUSE mount:" \
                "  ${GREEN}Mount cleanly unmounted and ephemeral directory removed.${RESET}"
            wait "${MOUNT_PID}" 2>/dev/null || true
        else
            echo -e "  ${YELLOW}Failed to establish live FUSE mount. Log:${RESET}"
            echo -e "  ${RED}${BOLD}Cannot mount AppImage, please check your FUSE setup.${RESET}"
            kill "${MOUNT_PID}" 2>/dev/null || true
            pause_prompt "  ${BOLD}${GREEN}[PAUSE]${RESET} Press ${BOLD}[Enter]${RESET} to continue (or Ctrl+C to stop)... "
        fi
        rm -f "${MOUNT_TMP_OUT}"
    fi
else
    skip "No AppImage specified."
fi

# -----------------------------------------------------------------------------
# Section 5: The Portability Boundary & Container Fallback
# -----------------------------------------------------------------------------
banner "Section 5: The Portability Boundary & Container Fallback"
echo "Explanation: Where is the boundary of the 'box'?"
echo "AppImage bundles application files and custom libraries (e.g. raylib),"
echo "but intentionally leaves the host graphics stack and C library unbundled:"
echo "- Bundled inside AppImage : ocio binary, assets, raylib (when shared)"
echo "- Delegated to Host       : Linux kernel, glibc, libglvnd / libOpenGL.so.0, GPU drivers"

substep "FUSE Troubleshooting & Payload Extraction:"
echo "When running inside a container (Docker/Podman) or minimal environment without FUSE:"
echo "1. Ensure /dev/fuse is passed to the container (--device /dev/fuse) and fuse3 is installed."
echo "2. Payload Extraction (inspect files directly without FUSE):"
print_command_box "./dist/ocio-x86_64.AppImage --appimage-extract && ./squashfs-root/AppRun"

# -----------------------------------------------------------------------------
# Summary & Pedagogical Conclusion
# -----------------------------------------------------------------------------
banner "Summary & Pedagogical Conclusion"
echo -e "- ${BOLD}Runtime Stub Contract${RESET} : Static-pie binary at offset 0, zero DT_NEEDED, fully self-contained."
echo -e "- ${BOLD}Header Magic (EI_PAD)${RESET}  : Overwrites reserved padding with 'AI\\x02' for instant O(1) detection."
echo -e "- ${BOLD}Two-Part Seam${RESET}          : Offset dividing line cleanly separates executable stub from SquashFS payload."
echo -e "- ${BOLD}FUSE Mount Lifecycle${RESET}   : Mounts to /tmp/.mount_* on demand, runs AppRun, unmounts on exit."
echo -e "- ${BOLD}Portability Boundary${RESET}   : Ships userland app; delegates glibc, kernel, and graphics dispatch to host."
echo ""
