#!/bin/bash
# =============================================================================
# Build ocio RPM manually using rpmbuild (No CPack)
#
# Usage: build-rpm.sh [rpmbuild options] [-p|--pause]
#   -p, --pause  Pause and wait for [Enter] before executing each step
#   All other arguments are passed through to rpmbuild.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION="0.1.0"
NAME="ocio"
# Must match raylib_version in ocio.spec
RAYLIB_VERSION="5.5"
RPM_TOPDIR="${RPM_TOPDIR:-/tmp/rpmbuild}"

PAUSE_MODE=false
BUILD_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        -p|--pause) PAUSE_MODE=true; shift ;;
        -h|--help)
            sed -n '4,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) BUILD_ARGS+=("$1"); shift ;;
    esac
done

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

pause_prompt "==> Setting up clean RPM build tree in ${RPM_TOPDIR}... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Setting up clean RPM build tree in ${RPM_TOPDIR}..."
rm -rf "${RPM_TOPDIR}"
mkdir -p "${RPM_TOPDIR}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

pause_prompt "==> Creating source tarball ${NAME}-${VERSION}.tar.gz... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Creating source tarball ${NAME}-${VERSION}.tar.gz..."
tar --exclude='.git' \
    --exclude='build*' \
    --exclude='dist' \
    --transform="s,^\.,${NAME}-${VERSION}," \
    -czf "${RPM_TOPDIR}/SOURCES/${NAME}-${VERSION}.tar.gz" \
    -C "${REPO_ROOT}" .

pause_prompt "==> Copying spec file... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Copying spec file..."
cp "${SCRIPT_DIR}/ocio.spec" "${RPM_TOPDIR}/SPECS/"

# Stage raylib source tarball if vendored raylib is requested, or if the system
# raylib-devel is missing or not the version the spec requires (raylib_version)
SYSTEM_RAYLIB="$(pkg-config --modversion raylib 2>/dev/null || true)"
if [[ "${BUILD_ARGS[*]:-}" == *"--with vendored_raylib"* ]] || \
   [[ "${SYSTEM_RAYLIB}" != "${RAYLIB_VERSION}" && "${SYSTEM_RAYLIB}" != "${RAYLIB_VERSION}".* ]]; then
    RAYLIB_SRC="${RPM_TOPDIR}/SOURCES/raylib-${RAYLIB_VERSION}.tar.gz"
    if [ ! -f "${RAYLIB_SRC}" ]; then
        echo "==> Staging raylib-${RAYLIB_VERSION} source tarball for hermetic/vendored build..."
        curl -sLo "${RAYLIB_SRC}" "https://github.com/raysan5/raylib/archive/refs/tags/${RAYLIB_VERSION}.tar.gz"
    fi
    if [[ "${BUILD_ARGS[*]:-}" != *"--with vendored_raylib"* ]]; then
        echo "==> System raylib is '${SYSTEM_RAYLIB:-not installed}', spec needs ${RAYLIB_VERSION}: building with vendored raylib"
        BUILD_ARGS+=("--with" "vendored_raylib")
    fi
fi

pause_prompt "==> Running rpmbuild (Binary & Source RPMs)... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Running rpmbuild (Binary & Source RPMs)..."
rpmbuild -ba \
    --define "_topdir ${RPM_TOPDIR}" \
    "${BUILD_ARGS[@]}" \
    "${RPM_TOPDIR}/SPECS/ocio.spec"

pause_prompt "==> Collecting generated RPMs into dist/... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Collecting generated RPMs into dist/..."
mkdir -p "${REPO_ROOT}/dist"
cp -f "${RPM_TOPDIR}/RPMS"/*/*.rpm "${REPO_ROOT}/dist/"
cp -f "${RPM_TOPDIR}/SRPMS"/*.src.rpm "${REPO_ROOT}/dist/"

echo "==> Generated RPM packages in dist/:"
ls -lh "${REPO_ROOT}/dist/"*.rpm
