#!/usr/bin/env bash
# ==============================================================================
# Setup Builder Image
# Usage: ./packaging/containers/setup-builder.sh <opensuse|debian> [--rebuild]
#
# Pulls the pre-built builder image from GHCR if available, or builds it
# locally with podman. Pass --rebuild to skip the pull and build unconditionally
# (used by CI when packaging/containers/ changed in the current PR/push/tag).
# ==============================================================================
set -euo pipefail

DISTRO="${1:-}"
if [ -z "$DISTRO" ]; then
  echo "Usage: $0 <opensuse|debian> [--rebuild]" >&2
  exit 1
fi
shift

REBUILD=0
for arg in "$@"; do
  case "$arg" in
    --rebuild) REBUILD=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

CONTAINERFILE="packaging/containers/Containerfile.${DISTRO}"
if [ ! -f "$CONTAINERFILE" ]; then
  echo "Error: Containerfile not found: $CONTAINERFILE" >&2
  exit 1
fi

LOCAL_TAG="localhost/packathon-${DISTRO}:builder"
REPO_OWNER="${GITHUB_REPOSITORY:-michelepagot/packathon}"
IMAGE="ghcr.io/${REPO_OWNER,,}/${DISTRO}-builder:latest"

if [ "$REBUILD" -eq 1 ]; then
  echo "Rebuild requested. Building $LOCAL_TAG locally from $CONTAINERFILE..."
  podman build -t "$LOCAL_TAG" -f "$CONTAINERFILE" packaging/containers
  exit 0
fi

echo "Attempting to pull pre-built image $IMAGE..."
if podman pull "$IMAGE"; then
  echo "Successfully pulled $IMAGE"
  podman tag "$IMAGE" "$LOCAL_TAG"
  exit 0
fi

echo "Failed to pull $IMAGE; falling back to local build..."
podman build -t "$LOCAL_TAG" -f "$CONTAINERFILE" packaging/containers
