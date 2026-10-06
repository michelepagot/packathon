#!/usr/bin/env bash
# =============================================================================
# Build ocio binary directly calling CMake and copy to dist/cmake/
# Optionally runs CPack to package the application.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build}"
DIST_DIR="${DIST_DIR:-${ROOT_DIR}/dist}"
CMAKE_DIST_DIR="${DIST_DIR}/cmake"

RUN_CPACK=false
CPACK_GENS=""
CMAKE_ARGS=()

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] [-- CMAKE_OPTIONS]

Build the ocio application using CMake and place artifacts into dist/cmake/.

Options:
  --cpack [GENERATORS]   Run CPack after building. Optionally provide semicolon- or
                         comma-separated generators (e.g. "tgz;rpm", "DEB;RPM").
  -h, --help             Show this help message.

Additional arguments (such as -DRAYLIB_MODE=LOCAL) are forwarded directly to cmake.
EOF
    exit 0
}

# Normalize generator names (e.g. tgz -> TGZ, rpm -> RPM, deb -> DEB)
normalize_cpack_generators() {
    local input="$1"
    local IFS=';,'
    local gens=()
    read -ra raw_gens <<< "${input}"
    local normalized=()
    for gen in "${raw_gens[@]}"; do
        gen="$(echo "${gen}" | xargs)"
        [ -z "${gen}" ] && continue
        local upper="${gen^^}"
        case "${upper}" in
            TGZ|RPM|DEB|ZIP|TAR|TBZ2|TXZ|TZ|TZST|STGZ|7Z)
                normalized+=("${upper}")
                ;;
            APPIMAGE)
                normalized+=("AppImage")
                ;;
            NUGET)
                normalized+=("NuGet")
                ;;
            *)
                normalized+=("${gen}")
                ;;
        esac
    done
    local IFS=';'
    echo "${normalized[*]}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --cpack)
            RUN_CPACK=true
            if [ $# -gt 1 ] && [[ "$2" != -* ]]; then
                CPACK_GENS="$2"
                shift 2
            else
                shift
            fi
            ;;
        --cpack=*)
            RUN_CPACK=true
            CPACK_GENS="${1#--cpack=}"
            shift
            ;;
        -h|--help)
            usage
            ;;
        --)
            shift
            CMAKE_ARGS+=("$@")
            break
            ;;
        *)
            CMAKE_ARGS+=("$1")
            shift
            ;;
    esac
done

mkdir -p "${CMAKE_DIST_DIR}"
mkdir -p "${BUILD_DIR}"

echo "==> Configuring ocio with CMake..."
cmake -S "${ROOT_DIR}" -B "${BUILD_DIR}" -DCMAKE_BUILD_TYPE=Release "${CMAKE_ARGS[@]}"

echo "==> Building ocio binary..."
cmake --build "${BUILD_DIR}" --config Release --target ocio -j"$(nproc)"

BINARY_PATH=""
if [ -f "${BUILD_DIR}/bin/ocio" ]; then
    BINARY_PATH="${BUILD_DIR}/bin/ocio"
elif [ -f "${BUILD_DIR}/ocio" ]; then
    BINARY_PATH="${BUILD_DIR}/ocio"
else
    echo "Error: ocio binary not found in ${BUILD_DIR}/bin or ${BUILD_DIR}" >&2
    exit 1
fi

echo "==> Copying binary to ${CMAKE_DIST_DIR}/ocio..."
cp -f "${BINARY_PATH}" "${CMAKE_DIST_DIR}/ocio"
chmod +x "${CMAKE_DIST_DIR}/ocio"

if [ "${RUN_CPACK}" = true ]; then
    echo "==> Packaging with CPack..."
    CPACK_CMD=("cpack" "--config" "${BUILD_DIR}/CPackConfig.cmake" "-B" "${BUILD_DIR}")
    if [ -n "${CPACK_GENS}" ]; then
        NORMALIZED_GENS="$(normalize_cpack_generators "${CPACK_GENS}")"
        echo "==> CPack generator(s): ${NORMALIZED_GENS}"
        CPACK_CMD+=("-G" "${NORMALIZED_GENS}")
    fi
    "${CPACK_CMD[@]}"

    echo "==> Copying CPack output to ${CMAKE_DIST_DIR}..."
    find "${BUILD_DIR}" -maxdepth 1 -type f \( \
        -name "*.rpm" -o \
        -name "*.deb" -o \
        -name "*.tar.gz" -o \
        -name "*.tgz" -o \
        -name "*.tar.xz" -o \
        -name "*.zip" -o \
        -name "*.7z" -o \
        -name "*.sh" \
    \) -exec cp -f {} "${CMAKE_DIST_DIR}/" \;
fi

echo "==> Artifacts in ${CMAKE_DIST_DIR}:"
ls -lh "${CMAKE_DIST_DIR}"
