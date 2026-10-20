#!/bin/sh
set -e

# Configurable CMake options (with defaults)
RAYLIB_MODE="${RAYLIB_MODE:-FETCH}"
RAYLIB_SHARED="${RAYLIB_SHARED:-OFF}"
RAYLIB_LOCAL="${RAYLIB_LOCAL:-}"
DIST_DIR="${DIST_DIR:-/src/dist}"

# CPack generator passed as first argument, or auto-detected by distro.
# --no-cpack skips CPack entirely (binary-only build).
GENERATOR=""
NO_CPACK=false
for arg in "$@"; do
    case "$arg" in
        --no-cpack) NO_CPACK=true ;;
        *)          GENERATOR="$arg" ;;
    esac
done
if [ "$NO_CPACK" = false ] && [ -z "$GENERATOR" ]; then
    if [ -f /etc/debian_version ]; then
        GENERATOR="TGZ;DEB"
    else
        GENERATOR="TGZ;RPM"
    fi
fi

echo "==> Building ocio with:"
echo "    RAYLIB_MODE=${RAYLIB_MODE}"
echo "    RAYLIB_SHARED=${RAYLIB_SHARED}"
if [ -n "${RAYLIB_LOCAL}" ]; then
    echo "    RAYLIB_LOCAL=${RAYLIB_LOCAL}"
fi
if [ "$NO_CPACK" = true ]; then
    echo "    CPACK=off"
else
    echo "    CPACK_GENERATOR=${GENERATOR}"
fi

# Isolated build in scratch space. RelWithDebInfo gives CPack the symbols for
# the ocio-debuginfo / ocio-dbgsym packages. CPack RPM rewrites debug source
# paths in place, so it needs source and build paths of at least 25 characters:
# build through a symlink instead of the short /src mount point
WORK_DIR=/var/tmp/ocio-build
SRC_DIR="${WORK_DIR}/source"
BUILD_DIR="${WORK_DIR}/build"
rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
ln -s /src "${SRC_DIR}"
cmake -S "${SRC_DIR}" -B "${BUILD_DIR}" \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DRAYLIB_MODE="${RAYLIB_MODE}" \
    -DRAYLIB_SHARED="${RAYLIB_SHARED}" \
    ${RAYLIB_LOCAL:+-DRAYLIB_LOCAL="${RAYLIB_LOCAL}"}

cmake --build "${BUILD_DIR}" --config RelWithDebInfo -j"$(nproc)"

cd "${BUILD_DIR}"
if [ "$NO_CPACK" = false ]; then
    cpack -G "${GENERATOR}" || echo "WARNING: CPack failed (rc=$?), continuing to copy binary"
fi

mkdir -p "${DIST_DIR}"
cp -f -- *.tar.gz *.rpm *.deb *.ddeb "${DIST_DIR}/" 2>/dev/null || true
cp -f bin/ocio "${DIST_DIR}/" 2>/dev/null || true

echo "==> Generated artifacts in ${DIST_DIR}:"
ls -lh "${DIST_DIR}/"
