#!/bin/bash
# =============================================================================
# Build ocio RPM manually using rpmbuild (No CPack)
#
# Usage: build-rpm.sh --raylib-tarball <path> [rpmbuild options] [-p|--pause]
#
# Arguments:
#   --raylib-tarball <path>
#       (Mandatory) Path to pre-staged raylib source tarball (e.g. raylib-5.5.tar.gz).
#       - Inside the builder container: pass '/raylib_vendoring/raylib-5.5.tar.gz'
#       - On a local host: pre-download the tarball first:
#           curl -sLo /path/to/raylib-5.5.tar.gz \
#             https://github.com/raysan5/raylib/archive/refs/tags/5.5.tar.gz
#           ./packaging/rpm/build-rpm.sh --raylib-tarball /path/to/raylib-5.5.tar.gz
#   -p, --pause
#       Pause and wait for [Enter] before executing each step
#   All other arguments are passed through to rpmbuild.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/pause.sh"

VERSION="0.1.0"
NAME="ocio"
# Must match raylib_version in ocio.spec
RAYLIB_VERSION="5.5"
RPM_TOPDIR="${RPM_TOPDIR:-/tmp/rpmbuild}"

RAYLIB_TARBALL=""
export PAUSE_MODE=false
BUILD_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --raylib-tarball)
            if [ $# -lt 2 ]; then
                echo "Error: --raylib-tarball requires a path argument" >&2
                exit 1
            fi
            RAYLIB_TARBALL="$2"
            shift 2
            ;;
        -p|--pause) PAUSE_MODE=true; shift ;;
        -h|--help)
            sed -n '4,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) BUILD_ARGS+=("$1"); shift ;;
    esac
done

if [ -z "${RAYLIB_TARBALL}" ]; then
    echo "Error: --raylib-tarball <path> is mandatory." >&2
    echo "Usage: $0 --raylib-tarball <path/to/raylib-${RAYLIB_VERSION}.tar.gz> [options]" >&2
    exit 1
fi

if [ ! -f "${RAYLIB_TARBALL}" ]; then
    echo "Error: raylib source tarball not found at '${RAYLIB_TARBALL}'" >&2
    exit 1
fi

pause_prompt "==> Setting up clean RPM build tree in ${RPM_TOPDIR}... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Setting up clean RPM build tree in ${RPM_TOPDIR}..."
say "rpmbuild expects a standard top-level directory with BUILD/, SOURCES/, SPECS/, RPMS/, SRPMS/, and BUILDROOT/ subdirectories. We create a clean one so no stale artifacts interfere."
rm -rf "${RPM_TOPDIR}"
mkdir -p "${RPM_TOPDIR}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

pause_prompt "==> Creating source tarball ${NAME}-${VERSION}.tar.gz... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Creating source tarball ${NAME}-${VERSION}.tar.gz..."
say "rpmbuild unpacks the source tarball into BUILD/ during the %prep phase. The tarball must be named <name>-<version>.tar.gz and contain the project at its top level."
tar --exclude='.git' \
    --exclude='build*' \
    --exclude='dist' \
    --transform="s,^\.,${NAME}-${VERSION}," \
    -czf "${RPM_TOPDIR}/SOURCES/${NAME}-${VERSION}.tar.gz" \
    -C "${REPO_ROOT}" .

pause_prompt "==> Copying spec file... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Copying spec file..."
say "The spec file is the recipe: it tells rpmbuild how to unpack, configure, build, and install the package, and declares metadata (name, version, dependencies, file list)."
cp "${SCRIPT_DIR}/ocio.spec" "${RPM_TOPDIR}/SPECS/"

# Stage raylib source tarball if vendored raylib is requested, or if the system
# raylib-devel is missing or not the version the spec requires (raylib_version)
SYSTEM_RAYLIB="$(pkg-config --modversion raylib 2>/dev/null || true)"
if [[ "${BUILD_ARGS[*]:-}" == *"--with vendored_raylib"* ]] || \
   [[ "${SYSTEM_RAYLIB}" != "${RAYLIB_VERSION}" && "${SYSTEM_RAYLIB}" != "${RAYLIB_VERSION}".* ]]; then
    echo "==> Staging raylib-${RAYLIB_VERSION} source tarball from ${RAYLIB_TARBALL}..."
    cp "${RAYLIB_TARBALL}" "${RPM_TOPDIR}/SOURCES/raylib-${RAYLIB_VERSION}.tar.gz"
    if [[ "${BUILD_ARGS[*]:-}" != *"--with vendored_raylib"* ]]; then
        echo "==> System raylib is '${SYSTEM_RAYLIB:-not installed}', spec needs ${RAYLIB_VERSION}: building with vendored raylib"
        BUILD_ARGS+=("--with" "vendored_raylib")
    fi
fi

pause_prompt "==> Running rpmbuild (Binary & Source RPMs)... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Running rpmbuild (Binary & Source RPMs)..."
say "rpmbuild -ba runs the full build: %prep (unpack), %build (compile), %install (stage into BUILDROOT), then packages the binary RPM and source RPM. It auto-detects shared library dependencies from the ELF binary."
rpmbuild -ba \
    --define "_topdir ${RPM_TOPDIR}" \
    "${BUILD_ARGS[@]}" \
    "${RPM_TOPDIR}/SPECS/ocio.spec"

pause_prompt "==> Collecting generated RPMs into dist/... Press [Enter] to continue (or Ctrl+C to stop)... "
echo "==> Collecting generated RPMs into dist/..."
say "rpmbuild places output in RPMS/<arch>/ and SRPMS/. We copy them to dist/ for easy access."
mkdir -p "${REPO_ROOT}/dist"
cp -f "${RPM_TOPDIR}/RPMS"/*/*.rpm "${REPO_ROOT}/dist/"
cp -f "${RPM_TOPDIR}/SRPMS"/*.src.rpm "${REPO_ROOT}/dist/"

echo "==> Generated RPM packages in dist/:"
ls -lh "${REPO_ROOT}/dist/"*.rpm
