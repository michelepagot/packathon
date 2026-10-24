#!/usr/bin/env bash
set -euo pipefail

# Build AppImage for ocio (Packathon project)
#
# Usage: build-appimage.sh [--method linuxdeploy|appimagetool] [-p|--pause]
#
#   linuxdeploy  (default) linuxdeploy reads the ELF dependencies of ocio and
#                copies into AppDir/usr/lib every library that is not on the
#                AppImage excludelist (glibc, GL, X11, ... stay on the host),
#                sets RUNPATH=$ORIGIN/../lib and creates AppRun.
#                appimagetool then packs the AppDir.
#   appimagetool AppDir assembled by hand, packed by appimagetool. Nothing
#                checks the dependencies: a shared library that is not on the
#                host is simply missing (try it with RAYLIB_SHARED=ON).
#   -p, --pause  pause and wait for [Enter] before executing each command
#                (each command is shown in a "Command to Run" box)
#
# Environment: BUILD_DIR, OUTPUT_DIR, METHOD (same as --method),
#              RAYLIB_MODE and RAYLIB_SHARED (passed to CMake when set).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/pause.sh"
# Distro-specific build directory: a CMake cache created on one distro
# records absolute library paths (e.g. /usr/lib64/libOpenGL.so on openSUSE)
# that do not exist on the other (Debian uses /usr/lib/x86_64-linux-gnu/).
# Reusing the same build/ directory across distros makes gmake fail with
# "No rule to make target '/usr/lib64/libOpenGL.so'".
if [ -f /etc/debian_version ]; then
    BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build-debian}"
else
    BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/build-opensuse}"
fi
APPDIR="${BUILD_DIR}/AppDir"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"
METHOD="${METHOD:-linuxdeploy}"
export PAUSE_MODE=false

usage() {
    sed -n '4,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --method) METHOD="${2:?--method needs a value}"; shift 2 ;;
        --method=*) METHOD="${1#--method=}"; shift ;;
        -p|--pause) PAUSE_MODE=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

case "${METHOD}" in
    linuxdeploy|appimagetool) ;;
    *) echo "Unknown method: ${METHOD}" >&2; usage >&2; exit 1 ;;
esac

export ARCH=x86_64

# The tools are pre-installed in the Packathon builder images: check them
# before the build instead of downloading anything.
RUNTIME="/usr/lib/runtime-${ARCH}"
MISSING=""
command -v appimagetool >/dev/null 2>&1 || MISSING="${MISSING} appimagetool"
[ -f "${RUNTIME}" ] || MISSING="${MISSING} ${RUNTIME}"
if [ "${METHOD}" = "linuxdeploy" ]; then
    command -v linuxdeploy >/dev/null 2>&1 || MISSING="${MISSING} linuxdeploy"
fi
if [ -n "${MISSING}" ]; then
    cat >&2 <<EOF
Error: missing build tools:${MISSING}
They are pre-installed in the Packathon builder container images (see
packaging/containers/Containerfile.*). To install them on your host, extract
each AppImage and put it on the PATH, as the Containerfiles do:
  curl -Lo /tmp/appimagetool https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage
  curl -Lo /tmp/linuxdeploy https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${ARCH}.AppImage
  sudo curl -Lo ${RUNTIME} https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-${ARCH}
  # then for each tool: chmod +x, --appimage-extract, and link squashfs-root/AppRun into the PATH
  # (running the AppImages directly also works, but needs FUSE: /dev/fuse and fusermount3)
EOF
    exit 1
fi

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BUILD_DIR}"

echo "=== Building ocio with CMake (method: ${METHOD}) ==="
if [ ! -f "${BUILD_DIR}/bin/ocio" ]; then
    demo_cmd "cmake -S \"${ROOT_DIR}\" -B \"${BUILD_DIR}\" -DCMAKE_BUILD_TYPE=Release ${RAYLIB_MODE:+-DRAYLIB_MODE=\"${RAYLIB_MODE}\"} ${RAYLIB_SHARED:+-DRAYLIB_SHARED=\"${RAYLIB_SHARED}\"}" \
        "Configuring the CMake build (Release). RAYLIB_MODE / RAYLIB_SHARED are forwarded when set in the environment."
    demo_cmd "cmake --build \"${BUILD_DIR}\" --config Release -j\"\$(nproc)\"" \
        "Building the ocio binary with all available cores."
else
    echo "    Binary already exists at ${BUILD_DIR}/bin/ocio, skipping compile."
fi

echo "=== Assembling AppDir ==="
demo_cmd "rm -rf \"${APPDIR}\"" \
    "Removing any previous AppDir so the assembly starts from a clean tree."
if [ "${METHOD}" = "appimagetool" ]; then
    # Only the ocio component: the default install also contains raylib's dev files
    demo_cmd "DESTDIR=\"${APPDIR}\" cmake --install \"${BUILD_DIR}\" --component ocio" \
        "Staging the ocio component into AppDir. Only the ocio component: the default install also contains raylib's dev files."
    demo_cmd "cp \"${ROOT_DIR}/packaging/ocio.desktop\" \"${APPDIR}/\"" \
        "The XDG .desktop file at the AppDir top level: the AppImage format expects it there."
    demo_cmd "cp \"${ROOT_DIR}/packaging/icons/ocio.png\" \"${APPDIR}/\"" \
        "The application icon at the AppDir top level."
    demo_cmd "ln -sf usr/local/bin/ocio \"${APPDIR}/AppRun\"" \
        "AppRun is the entry point the AppImage runtime executes; it points at the staged binary."
else
    # linuxdeploy expects the usr/ layout: usr/bin, usr/lib, usr/share
    demo_cmd "DESTDIR=\"${APPDIR}\" cmake --install \"${BUILD_DIR}\" --component ocio --prefix /usr" \
        "Staging the ocio component into AppDir with the usr/ layout that linuxdeploy expects (usr/bin, usr/lib, usr/share)."

    # The installed ocio has no RUNPATH, so a shared libraylib in the build
    # tree is invisible to linuxdeploy's dependency scan: point it there.
    RAYLIB_SO="$(find "${BUILD_DIR}" -path "${APPDIR}" -prune -o -name 'libraylib.so*' -print -quit)"
    if [ -n "${RAYLIB_SO}" ]; then
        RAYLIB_DIR="$(dirname "${RAYLIB_SO}")"
        LD_LIBRARY_PATH="${RAYLIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
        export LD_LIBRARY_PATH
    fi

    demo_cmd "linuxdeploy --appdir \"${APPDIR}\" --executable \"${APPDIR}/usr/bin/ocio\" --desktop-file \"${ROOT_DIR}/packaging/ocio.desktop\" --icon-file \"${ROOT_DIR}/packaging/icons/ocio.png\"" \
        "linuxdeploy scans DT_NEEDED recursively, copies every library not on the AppImage excludelist into usr/lib, sets RUNPATH=\$ORIGIN/../lib, and creates AppRun plus the .desktop and icon links."
fi

echo "=== Packaging AppImage with appimagetool ==="
APPIMAGE_BIN="${OUTPUT_DIR}/ocio-x86_64.AppImage"

# appimagetool otherwise downloads the type2 runtime itself at every build,
# and can hang there: pass the pre-installed one explicitly.
demo_cmd "appimagetool --verbose --runtime-file \"${RUNTIME}\" \"${APPDIR}\" \"${APPIMAGE_BIN}\"" \
    "Packing the AppDir into a SquashFS image with the type2 runtime prepended. The runtime is passed explicitly: otherwise appimagetool downloads it at every build."

echo "=== AppImage build complete! Output: ${APPIMAGE_BIN} ==="
