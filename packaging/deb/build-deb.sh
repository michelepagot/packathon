#!/usr/bin/env bash
# =============================================================================
# Build ocio DEB package using dpkg-deb, cpack, or debhelper
#
# Low-level binary packaging workflow that bypasses heavy frameworks like
# debhelper and CPack by manually executing atomic steps:
#   1. Compile binary
#   2. Stage directory layout and metadata
#   3. Resolve ELF shared library dependencies via dpkg-shlibdeps
#   4. Compute installed size and md5 checksums
#   5. Assemble Debian package with dpkg-deb
#
# Usage: build-deb.sh [--mode frugal|cmake|debhelper] [--no-clean] [-p|--pause]
#   frugal       (default) low-level workflow staging files directly with cp
#                and assembling package with dpkg-deb
#   cmake        generates Debian package via CMake's CPack DEB generator
#   debhelper    canonical source package workflow using debhelper toolchain
#                (debian/rules, dh, dh_auto_configure, dh_auto_build,
#                dh_auto_install, dh_shlibdeps, dh_gencontrol, dpkg-buildpackage)
#   --no-clean   do not remove intermediate staging files on exit
#   -p, --pause  pause and wait for [Enter] before executing each command
#                (each command is shown in a "Command to Run" box)
#   -h, --help   show this help message
#
# Must run on the Debian release it targets: dpkg-shlibdeps resolves every
# DT_NEEDED library to the package that owns it (dpkg -S) and reads that
# package's symbols file, so names and minimum versions come from this system.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/pause.sh"

VERSION="0.1.0"
PACKAGE_NAME="ocio"

MODE="frugal"
export PAUSE_MODE=false
NO_CLEAN=false
usage() {
    sed -n '/^# Low-level binary packaging/,/^# ==\+/ { /^# ==\+/d; s/^# \{0,1\}//; p; }' "${BASH_SOURCE[0]}"
}
while [ $# -gt 0 ]; do
    case "$1" in
        --mode) MODE="${2:?--mode needs a value}"; shift 2 ;;
        --mode=*) MODE="${1#--mode=}"; shift ;;
        --no-clean) NO_CLEAN=true; shift ;;
        -p|--pause) PAUSE_MODE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done
case "${MODE}" in
    frugal|cmake|debhelper) ;;
    *) echo "Unknown mode: ${MODE}" >&2; usage >&2; exit 1 ;;
esac

if [ "${MODE}" = "debhelper" ]; then
    if ! command -v dpkg-buildpackage >/dev/null 2>&1; then
        echo "Error: dpkg-buildpackage is not installed." >&2
        exit 1
    fi
    if ! command -v dh >/dev/null 2>&1; then
        echo "Error: debhelper (dh) is not installed." >&2
        exit 1
    fi
elif [ "${MODE}" = "cmake" ]; then
    if ! command -v cpack >/dev/null 2>&1; then
        echo "Error: cpack is not installed." >&2
        exit 1
    fi
    if ! command -v dpkg-shlibdeps >/dev/null 2>&1; then
        echo "Error: dpkg-shlibdeps is not installed." >&2
        exit 1
    fi
else
    if ! command -v dpkg-shlibdeps >/dev/null 2>&1; then
        echo "Error: dpkg-shlibdeps is not installed." >&2
        exit 1
    fi
fi

ARCH="$(dpkg --print-architecture)"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist}"

# -----------------------------------------------------------------------------
# demo_cmd (from lib/pause.sh): print the command box, optionally wait for
# [Enter] (PAUSE_MODE), then execute. $1 = command, $2 = explanation.
# -----------------------------------------------------------------------------

if [ "${MODE}" = "debhelper" ]; then
    DEB_VERSION="$(dpkg-parsechangelog -l"${SCRIPT_DIR}/debian/changelog" -SVersion)"
    DEB_FILENAME="${PACKAGE_NAME}_${DEB_VERSION}_${ARCH}.deb"
    OUTPUT_DEB="${DIST_DIR}/${DEB_FILENAME}"

    echo "==> Debhelper mode: running canonical Debian source package build (dpkg-buildpackage)..."

    CLEANUP_DEBIAN_LINK=false
    if [ ! -e "${REPO_ROOT}/debian" ]; then
        demo_cmd "ln -sfn \"${SCRIPT_DIR}/debian\" \"${REPO_ROOT}/debian\"" \
            "Linking packaging/deb/debian into the repository root so dpkg-buildpackage and debhelper find the Debian control directory."
        CLEANUP_DEBIAN_LINK=true
    fi

    cleanup_debhelper() {
        if [ "${CLEANUP_DEBIAN_LINK}" = true ]; then
            rm -f "${REPO_ROOT}/debian"
        fi
    }
    trap cleanup_debhelper EXIT

    CLEAN_FLAG="-tc"
    if [ "${NO_CLEAN}" = true ]; then
        CLEAN_FLAG=""
    fi
    demo_cmd "(cd \"${REPO_ROOT}\" && dpkg-buildpackage -us -uc -b -d ${CLEAN_FLAG})" \
        "Invoking dpkg-buildpackage (-us: unsigned source, -uc: unsigned changes, -b: binary-only, -d: skip build-essential check${CLEAN_FLAG:+, -tc: clean source tree after build}). This runs debian/rules via dh (dh_auto_configure, dh_auto_build, dh_auto_install, dh_shlibdeps, dh_gencontrol, dh_md5sums, dh_builddeb)."

    demo_cmd "mkdir -p \"${DIST_DIR}\"" \
        "Ensuring the dist/ output directory exists."

    # dpkg-buildpackage places output in parent directory (${REPO_ROOT}/..)
    BUILT_DEB="${REPO_ROOT}/../${DEB_FILENAME}"
    if [ ! -f "${BUILT_DEB}" ]; then
        BUILT_DEB="$(find "${REPO_ROOT}/.." -maxdepth 1 -name "${PACKAGE_NAME}_*_${ARCH}.deb" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n 1 | cut -d' ' -f2- || true)"
    fi

    if [ -f "${BUILT_DEB}" ]; then
        demo_cmd "cp -f \"${BUILT_DEB}\" \"${OUTPUT_DEB}\"" \
            "Copying generated Debian package from build parent directory to ${OUTPUT_DEB}."
        rm -f "${REPO_ROOT}/../${PACKAGE_NAME}_${DEB_VERSION}"* 2>/dev/null || true
    else
        echo "Error: expected build artifact ${BUILT_DEB} not found." >&2
        exit 1
    fi
elif [ "${MODE}" = "cmake" ]; then
    # --- CMake / CPack Mode ---
    DEB_FILENAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    OUTPUT_DEB="${DIST_DIR}/${DEB_FILENAME}"
    BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build-debian}"

    echo "==> Step 1: Ensuring binary is compiled..."
    if [ ! -f "${BUILD_DIR}/bin/ocio" ]; then
        demo_cmd "cmake -S \"${REPO_ROOT}\" -B \"${BUILD_DIR}\" -DCMAKE_BUILD_TYPE=Release" \
            "Configuring CMake build (Release) in ${BUILD_DIR}."
        demo_cmd "cmake --build \"${BUILD_DIR}\" --config Release -j\"\$(nproc)\"" \
            "Building the ocio binary with all available cores."
    else
        echo "    Binary already exists at ${BUILD_DIR}/bin/ocio, skipping compile."
    fi

    echo "==> Step 2: Packaging DEB archive with CPack..."
    demo_cmd "mkdir -p \"${DIST_DIR}\"" \
        "Ensuring the dist/ output directory exists."

    demo_cmd "(cd \"${BUILD_DIR}\" && cpack -G DEB)" \
        "Running CPack with the DEB generator. CPack stages the ocio component, runs dpkg-shlibdeps for ELF shared library dependencies, generates DEBIAN/control and md5sums, and builds the .deb package."

    CPACK_DEB="${BUILD_DIR}/${DEB_FILENAME}"
    if [ -f "${CPACK_DEB}" ]; then
        demo_cmd "cp -f \"${CPACK_DEB}\" \"${OUTPUT_DEB}\"" \
            "Copying generated CPack package to ${OUTPUT_DEB}."
    else
        echo "Error: expected CPack artifact ${CPACK_DEB} not found." >&2
        exit 1
    fi

    if [ "${NO_CLEAN}" = false ]; then
        rm -rf "${BUILD_DIR}/_CPack_Packages"
        rm -f "${CPACK_DEB}"
    fi
else
    # --- Frugal Mode (Manual low-level binary packaging) ---
    DEB_FILENAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"
    OUTPUT_DEB="${DIST_DIR}/${DEB_FILENAME}"

    # Separate from the host's build/: a binary compiled on another distro would be
    # analyzed against this system's symbols files and produce a meaningless Depends.
    BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build-debian}"

    # dpkg-shlibdeps expects the source-package layout: debian/control plus the
    # binary package tree in debian/<package>/ (found by walking up to DEBIAN/).
    # With --no-clean the tree is kept (no trap) so you can inspect it afterwards.
    if [ "${NO_CLEAN}" = true ]; then
        WORK_DIR="${REPO_ROOT}/build-deb-staging"
        rm -rf "${WORK_DIR}"
        mkdir -p "${WORK_DIR}"
    else
        WORK_DIR="$(mktemp -d)"
        trap 'rm -rf "${WORK_DIR}"' EXIT
    fi
    STAGE_DIR="${WORK_DIR}/debian/${PACKAGE_NAME}"

    # -----------------------------------------------------------------------------
    # Step 1: Ensure binary is compiled
    # -----------------------------------------------------------------------------
    echo "==> Step 1: Ensuring binary is compiled..."
    if [ ! -f "${BUILD_DIR}/bin/ocio" ]; then
        demo_cmd "cmake -S \"${REPO_ROOT}\" -B \"${BUILD_DIR}\" -DCMAKE_BUILD_TYPE=Release" \
            "Configuring CMake build (Release) in ${BUILD_DIR}."
        demo_cmd "cmake --build \"${BUILD_DIR}\" --config Release -j\"\$(nproc)\"" \
            "Building the ocio binary with all available cores."
    else
        echo "    Binary already exists at ${BUILD_DIR}/bin/ocio, skipping compile."
    fi

    # -----------------------------------------------------------------------------
    # Step 2: Stage the payload into the Debian directory layout
    # -----------------------------------------------------------------------------
    echo "==> Step 2: Assembling minimal Debian directory layout in ${STAGE_DIR} (mode: frugal)..."

    demo_cmd "mkdir -p \"${STAGE_DIR}\"" \
        "Creating the staging root directory."
    demo_cmd "cp -r \"${SCRIPT_DIR}/skeleton/.\" \"${STAGE_DIR}/\" && mkdir -p \"${STAGE_DIR}/usr/bin\" && cp \"${BUILD_DIR}/bin/ocio\" \"${STAGE_DIR}/usr/bin/ocio\" && chmod 755 \"${STAGE_DIR}/usr/bin/ocio\" && cp \"${REPO_ROOT}/packaging/ocio.desktop\" \"${STAGE_DIR}/usr/share/applications/\" && cp \"${REPO_ROOT}/packaging/icons/ocio.png\" \"${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps/\" && cp \"${REPO_ROOT}/packaging/icons/ocio.svg\" \"${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps/\" && cp \"${REPO_ROOT}/packaging/org.packathon.ocio.metainfo.xml\" \"${STAGE_DIR}/usr/share/metainfo/\"" \
        "Copying the Debian directory skeleton and all payload files into the staging tree: the compiled ocio binary (usr/bin/), the XDG .desktop file (usr/share/applications/), the PNG and SVG icons (usr/share/icons/hicolor/), and the AppStream metainfo (usr/share/metainfo/). DEBIAN/ holds package metadata read by dpkg-deb at build time; the usr/ tree is the FHS payload installed onto the target system."

    # -----------------------------------------------------------------------------
    # Step 3: Compute shared library dependencies with dpkg-shlibdeps
    # -----------------------------------------------------------------------------
    echo "==> Step 3: Computing shared library dependencies with dpkg-shlibdeps..."

    demo_cmd "cp \"${STAGE_DIR}/DEBIAN/control\" \"${WORK_DIR}/debian/control\" && SHLIBS_DEPENDS=\$(cd \"${WORK_DIR}\" && dpkg-shlibdeps -O \"debian/${PACKAGE_NAME}/usr/bin/ocio\" | sed -n 's/^shlibs:Depends=//p')" \
        "Copying the control template to debian/control (where dpkg-shlibdeps expects it), then running dpkg-shlibdeps. It inspects the binary's DT_NEEDED entries, maps each SONAME to the Debian package that owns it (dpkg -S), and reads that package's symbols file to determine the minimum version. The -O flag prints the result as shlibs:Depends=... which we capture into SHLIBS_DEPENDS."

    echo "    shlibs:Depends=${SHLIBS_DEPENDS}"

    # -----------------------------------------------------------------------------
    # Step 4: md5sums + control metadata
    # -----------------------------------------------------------------------------
    echo "==> Step 4: Generating md5sums and rendering control metadata..."

    demo_cmd "INSTALLED_SIZE=\$(du -sk --exclude=DEBIAN \"${STAGE_DIR}\" | cut -f1)" \
        "Calculating the installed size in KiB (excluding DEBIAN/ metadata, which is not installed). This value goes into the Installed-Size field of the control file."

    demo_cmd "(cd \"${STAGE_DIR}\" && find usr -type f -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums)" \
        "Computing md5 checksums for every file in the payload. This is what debsums checks installed files against (dpkg --verify). dpkg-deb does not compute this; normally dh_md5sums does."

    demo_cmd "sed -i -e '/^#/d' -e \"s|\\\${version}|${VERSION}|\" -e \"s|\\\${arch}|${ARCH}|\" -e \"s|\\\${installed:Size}|${INSTALLED_SIZE}|\" -e \"s|\\\${shlibs:Depends}|${SHLIBS_DEPENDS}|\" \"${STAGE_DIR}/DEBIAN/control\"" \
        "Rendering the control template in place: strips comment lines, substitutes version, architecture, installed size, and the computed shlibdeps. The result is the final DEBIAN/control file that dpkg-deb will embed in the package."

    # -----------------------------------------------------------------------------
    # Step 5: Package the DEB archive
    # -----------------------------------------------------------------------------
    echo "==> Step 5: Packaging DEB archive with dpkg-deb..."

    demo_cmd "mkdir -p \"${DIST_DIR}\"" \
        "Ensuring the dist/ output directory exists."

    demo_cmd "dpkg-deb --build --root-owner-group \"${STAGE_DIR}\" \"${OUTPUT_DEB}\"" \
        "Building the .deb archive. dpkg-deb assembles a Unix ar archive with three members: debian-binary (format version), control.tar.* (metadata), and data.tar.* (file payload). --root-owner-group forces root:root ownership without needing root."
fi

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------
echo "==> Generated DEB package in dist/:"
ls -lh "${OUTPUT_DEB}"

echo "==> DEB archive anatomy (ar t):"
ar t "${OUTPUT_DEB}"

echo "==> DEB control metadata (dpkg-deb -I):"
dpkg-deb -I "${OUTPUT_DEB}"

if [ "${NO_CLEAN}" = true ]; then
    echo ""
    if [ "${MODE}" = "debhelper" ]; then
        echo "==> Build artifacts left in debian/ and obj-*/ for inspection (--no-clean)."
    elif [ "${MODE}" = "cmake" ]; then
        echo "==> CPack staging tree left in ${BUILD_DIR}/_CPack_Packages/ for inspection (--no-clean)."
    else
        echo "==> Staging tree left in ${STAGE_DIR} for inspection (--no-clean)."
    fi
fi
