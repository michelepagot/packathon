#!/bin/sh
set -e

# Configurable CMake options (with defaults)
RAYLIB_MODE="${RAYLIB_MODE:-FETCH}"
RAYLIB_SHARED="${RAYLIB_SHARED:-OFF}"

# CPack generator passed as first argument, or auto-detected by distro
GENERATOR="${1:-}"
if [ -z "$GENERATOR" ]; then
    if [ -f /etc/debian_version ]; then
        GENERATOR="TGZ;DEB"
    else
        GENERATOR="TGZ;RPM"
    fi
fi

echo "==> Building ocio with:"
echo "    RAYLIB_MODE=${RAYLIB_MODE}"
echo "    RAYLIB_SHARED=${RAYLIB_SHARED}"
echo "    CPACK_GENERATOR=${GENERATOR}"

# Isolated build in scratch space
rm -rf /tmp/build
cmake -S /src -B /tmp/build \
    -DCMAKE_BUILD_TYPE=Release \
    -DRAYLIB_MODE="${RAYLIB_MODE}" \
    -DRAYLIB_SHARED="${RAYLIB_SHARED}"

cmake --build /tmp/build --config Release -j"$(nproc)"

cd /tmp/build
cpack -G "${GENERATOR}"

mkdir -p /src/dist
cp -f *.tar.gz *.rpm *.deb /src/dist/ 2>/dev/null || true
cp -f bin/ocio /src/dist/ 2>/dev/null || true

echo "==> Generated artifacts in dist/:"
ls -lh /src/dist/
