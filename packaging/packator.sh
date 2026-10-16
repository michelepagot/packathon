#!/usr/bin/env bash
# =============================================================================
# packator.sh: Run Packathon container images with appropriate Podman flags
#
# Usage: packaging/packator.sh <opensuse|debian> <builder|demo> [command...]
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
    cat <<EOF
Usage: $(basename "$0") <opensuse|debian> <builder|demo> [command...]

Run Packathon container images with the appropriate Podman arguments.

Distros:
  opensuse    openSUSE Tumbleweed
  debian      Debian Bookworm

Image Families:
  builder     Build environment (--privileged, checkout mounted at /src)
  demo        Clean runtime environment (GUI/X11, DRI, FUSE, checkout mounted at /src)

Examples:
  # Open interactive shell in builder:
  $(basename "$0") debian builder

  # Run a build script inside builder:
  $(basename "$0") debian builder packaging/deb/build-deb.sh
  $(basename "$0") opensuse builder packaging/containers/build-package.sh

  # Open interactive shell in demo container with GUI support:
  $(basename "$0") opensuse demo

  # Test an AppImage or package in demo container:
  $(basename "$0") opensuse demo ./dist/ocio-x86_64.AppImage --appimage-extract-and-run
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -lt 2 ]; then
    usage
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        exit 0
    else
        exit 1
    fi
fi

DISTRO="$1"
TYPE="$2"
shift 2

case "${DISTRO}" in
    opensuse|debian) ;;
    *)
        echo "Error: Invalid distro '${DISTRO}'. Supported: opensuse, debian" >&2
        exit 1
        ;;
esac

case "${TYPE}" in
    builder|demo) ;;
    *)
        echo "Error: Invalid image family '${TYPE}'. Supported: builder, demo" >&2
        exit 1
        ;;
esac

IMAGE="ghcr.io/michelepagot/packathon/${DISTRO}-${TYPE}:latest"


PODMAN_ARGS=(--rm -v "${REPO_ROOT}:/src:Z" -w /src)

# TTY allocation if running interactively
if [ -t 0 ]; then
    PODMAN_ARGS+=(-i)
fi
if [ -t 1 ]; then
    PODMAN_ARGS+=(-t)
fi

if [ "${TYPE}" = "builder" ]; then
    # Builders require --privileged for flatpak Bubblewrap sandboxing
    PODMAN_ARGS+=(--privileged)
elif [ "${TYPE}" = "demo" ]; then
    # X11 display integration
    if [ -n "${DISPLAY:-}" ]; then
        PODMAN_ARGS+=(-e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro)
        if command -v xhost >/dev/null 2>&1; then
            xhost +SI:localuser:"${USER:-$(id -un)}" >/dev/null 2>&1 || true
        fi
    fi

    # Wayland display integration
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
        PODMAN_ARGS+=(-e WAYLAND_DISPLAY -v "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}:ro")
    fi

    # Hardware acceleration (GPU)
    if [ -e /dev/dri ]; then
        PODMAN_ARGS+=(--device /dev/dri)
    fi

    # FUSE support (for running AppImages directly)
    if [ -e /dev/fuse ]; then
        PODMAN_ARGS+=(--device /dev/fuse --cap-add SYS_ADMIN)
    fi
fi

if [ "${PACKATOR_DRY_RUN:-0}" = "1" ]; then
    if [ $# -gt 0 ]; then
        echo podman run "${PODMAN_ARGS[@]}" "${IMAGE}" "$@"
    else
        echo podman run "${PODMAN_ARGS[@]}" "${IMAGE}" bash
    fi
    exit 0
fi

if [ $# -gt 0 ]; then
    exec podman run "${PODMAN_ARGS[@]}" "${IMAGE}" "$@"
else
    exec podman run "${PODMAN_ARGS[@]}" "${IMAGE}" bash
fi
