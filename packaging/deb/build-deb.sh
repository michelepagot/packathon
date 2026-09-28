#!/usr/bin/env bash
# =============================================================================
# Build ocio DEB package using dpkg-deb (Frugal & Minimalist, No CPack)
#
# Must run on the Debian release it targets: dpkg-shlibdeps resolves every
# DT_NEEDED library to the package that owns it (dpkg -S) and reads that
# package's symbols file, so names and minimum versions come from this system.
# On a non-Debian host the script re-runs itself in the Debian builder image.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION="0.1.0"
PACKAGE_NAME="ocio"
DEB_BUILDER_IMAGE="${DEB_BUILDER_IMAGE:-localhost/packathon-debian:builder}"

if ! command -v dpkg-shlibdeps >/dev/null 2>&1; then
    if command -v podman >/dev/null 2>&1; then
        echo "==> dpkg-shlibdeps not found: re-running inside ${DEB_BUILDER_IMAGE}..."
        exec podman run --rm \
            -v "${REPO_ROOT}:/src:Z" -w /src \
            -e BUILD_DIR=/tmp/build-deb -e DIST_DIR=/src/dist \
            "${DEB_BUILDER_IMAGE}" packaging/deb/build-deb.sh
    fi
    echo "Error: run on Debian/Ubuntu with dpkg-dev installed, or install podman." >&2
    exit 1
fi

ARCH="$(dpkg --print-architecture)"
DEB_FILENAME="${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

# Separate from the host's build/: a binary compiled on another distro would be
# analyzed against this system's symbols files and produce a meaningless Depends.
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build-debian}"
DIST_DIR="${DIST_DIR:-${REPO_ROOT}/dist}"

# dpkg-shlibdeps expects the source-package layout: debian/control plus the
# binary package tree in debian/<package>/ (found by walking up to DEBIAN/).
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT
STAGE_DIR="${WORK_DIR}/debian/${PACKAGE_NAME}"

echo "==> Step 1: Ensuring binary is compiled..."
if [ ! -f "${BUILD_DIR}/bin/ocio" ]; then
    echo "    Compiling ocio binary via CMake..."
    cmake -S "${REPO_ROOT}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release
    cmake --build "${BUILD_DIR}" --config Release -j"$(nproc)"
fi

echo "==> Step 2: Assembling minimal Debian directory layout in ${STAGE_DIR}..."
mkdir -p "${STAGE_DIR}/DEBIAN"
mkdir -p "${STAGE_DIR}/usr/bin"
mkdir -p "${STAGE_DIR}/usr/share/applications"
mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps"
mkdir -p "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${STAGE_DIR}/usr/share/metainfo"

# Binary payload
cp "${BUILD_DIR}/bin/ocio" "${STAGE_DIR}/usr/bin/ocio"
chmod 755 "${STAGE_DIR}/usr/bin/ocio"

# XDG Desktop integration
cp "${REPO_ROOT}/packaging/ocio.desktop" "${STAGE_DIR}/usr/share/applications/"
cp "${REPO_ROOT}/packaging/icons/ocio.png" "${STAGE_DIR}/usr/share/icons/hicolor/256x256/apps/"
cp "${REPO_ROOT}/packaging/icons/ocio.svg" "${STAGE_DIR}/usr/share/icons/hicolor/scalable/apps/"
cp "${REPO_ROOT}/packaging/org.packathon.ocio.metainfo.xml" "${STAGE_DIR}/usr/share/metainfo/"

echo "==> Step 3: Computing shared library dependencies with dpkg-shlibdeps..."
printf 'Source: %s\n\nPackage: %s\nArchitecture: any\n' "${PACKAGE_NAME}" "${PACKAGE_NAME}" \
    > "${WORK_DIR}/debian/control"
SHLIBS_DEPENDS="$(cd "${WORK_DIR}" && dpkg-shlibdeps -O "debian/${PACKAGE_NAME}/usr/bin/ocio" \
                  | sed -n 's/^shlibs:Depends=//p')"
echo "    shlibs:Depends=${SHLIBS_DEPENDS}"

# dpkg-deb computes neither of these (dpkg-gencontrol and dh_md5sums normally do);
# md5sums is what debsums checks installed files against.
INSTALLED_SIZE="$(du -sk --exclude=DEBIAN "${STAGE_DIR}" | cut -f1)"
(cd "${STAGE_DIR}" && find usr -type f -print0 | sort -z | xargs -0 md5sum > DEBIAN/md5sums)

# Control metadata: render the template, dropping its comment lines
sed -e '/^#/d' \
    -e "s|\${version}|${VERSION}|" \
    -e "s|\${arch}|${ARCH}|" \
    -e "s|\${installed:Size}|${INSTALLED_SIZE}|" \
    -e "s|\${shlibs:Depends}|${SHLIBS_DEPENDS}|" \
    "${SCRIPT_DIR}/control" > "${STAGE_DIR}/DEBIAN/control"

echo "==> Step 4: Packaging DEB archive with dpkg-deb..."
mkdir -p "${DIST_DIR}"
OUTPUT_DEB="${DIST_DIR}/${DEB_FILENAME}"
dpkg-deb --build --root-owner-group "${STAGE_DIR}" "${OUTPUT_DEB}"

echo "==> Generated DEB package in dist/:"
ls -lh "${OUTPUT_DEB}"

echo "==> DEB archive anatomy (ar t):"
ar t "${OUTPUT_DEB}"

echo "==> DEB control metadata (dpkg-deb -I):"
dpkg-deb -I "${OUTPUT_DEB}"
