#!/usr/bin/env bash
set -euo pipefail

# Build Flatpak bundle for ocio (Packathon project)
#
# Usage:
#   build-flatpak.sh [--mode MODE] [-p|--pause] [-d|--dry-run]
#
# Modes:
#   app       (default) Build app bundle only
#   bundles   App bundle + runtime + GL extension bundles (3 files)
#   sideload  App bundle + sideload repo directory (air-gapped distribution)
#
# Options:
#   -p, --pause    Pause and wait for [Enter] before executing each command
#   -d, --dry-run  Dry-run mode: only print commands without executing them
#   -h, --help     Show this help message

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
source "${SCRIPT_DIR}/../lib/pause.sh"
BUILD_DIR="${BUILD_DIR:-/tmp/flatpak-build}"
REPO_DIR="${REPO_DIR:-/tmp/flatpak-repo}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"
MANIFEST="${SCRIPT_DIR}/org.packathon.ocio.yml"
BUNDLE="${OUTPUT_DIR}/ocio.flatpak"
STATE_DIR="${STATE_DIR:-/tmp/flatpak-builder-state}"
RUNTIME_REPO="${RUNTIME_REPO:-/tmp/flatpak-runtime-repo}"
SIDEOAL_REPO="${SIDEOAL_REPO:-${OUTPUT_DIR}/sideload-repo}"
SYSTEM_REPO="${SYSTEM_REPO:-/var/lib/flatpak/repo}"
COLLECTION_ID="org.packathon.ocio"
BRANCH="$(sed -n "s/^runtime-version: *'\{0,1\}\([^']*\)'\{0,1\} *$/\1/p" "${MANIFEST}")"
ARCH="$(uname -m)"

usage() {
    sed -n '4,16p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

MODE="app"
export PAUSE_MODE=false
DRY_RUN=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --mode requires a value (app|bundles|sideload)" >&2
                exit 1
            fi
            MODE="$2"
            shift 2
            ;;
        --mode=*)
            MODE="${1#--mode=}"
            shift
            ;;
        -p|--pause)
            PAUSE_MODE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -pd|-dp)
            PAUSE_MODE=true
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "${MODE}" in
    app|bundles|sideload) ;;
    *)
        echo "Error: Invalid mode '${MODE}'. Valid modes: app, bundles, sideload" >&2
        exit 1
        ;;
esac

demo_cmd "mkdir -p \"${OUTPUT_DIR}\"" "Ensuring the dist/ output directory exists."

echo "=== 1. Checking Flatpak SDK/Runtime (${BRANCH}) ==="
demo_cmd "flatpak info org.freedesktop.Platform//${BRANCH} && flatpak info org.freedesktop.Sdk//${BRANCH}" \
    "Verifying the Flatpak runtime and SDK for branch ${BRANCH} are installed."
if [ "${DRY_RUN}" = false ] && \
   { ! flatpak info "org.freedesktop.Platform//${BRANCH}" >/dev/null 2>&1 || \
     ! flatpak info "org.freedesktop.Sdk//${BRANCH}" >/dev/null 2>&1; }; then
    echo "Error: Flatpak runtime org.freedesktop.Platform//${BRANCH} or SDK org.freedesktop.Sdk//${BRANCH} is not installed." >&2
    echo "They are pre-installed in the Packathon builder container images." >&2
    echo "To install them on your host, run:" >&2
    echo "  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" >&2
    echo "  flatpak install flathub org.freedesktop.Platform//${BRANCH} org.freedesktop.Sdk//${BRANCH}" >&2
    exit 1
fi
echo "SDK and Runtime ${BRANCH} found."

echo "=== 2. Building application with flatpak-builder ==="
demo_cmd "flatpak-builder --force-clean --disable-rofiles-fuse --state-dir=\"${STATE_DIR}\" --repo=\"${REPO_DIR}\" \"${BUILD_DIR}\" \"${MANIFEST}\"" \
    "Building the application inside the Flatpak SDK sandbox."

echo "=== 3. Exporting single-file Flatpak bundle ==="
demo_cmd "flatpak build-bundle \"${REPO_DIR}\" \"${BUNDLE}\" org.packathon.ocio" \
    "Exporting the built app as a single-file .flatpak bundle."
echo "App bundle: ${BUNDLE}"

if [[ "${MODE}" == "app" ]]; then
    echo "=== Flatpak build complete! Output: ${BUNDLE} ==="
    exit 0
fi

# --- Helper: pull a runtime from the system repo into a target repo ---
pull_runtime() {
    local target_repo="$1"
    local runtime_id="$2"
    local branch="$3"

    local deploy_ref="deploy/runtime/${runtime_id}/${ARCH}/${branch}"
    local canonical_ref="runtime/${runtime_id}/${ARCH}/${branch}"
    local deploy_ref_file="${SYSTEM_REPO}/refs/heads/${deploy_ref}"

    if [[ ! -f "${deploy_ref_file}" ]]; then
        echo "Error: Deploy ref not found: ${deploy_ref_file}" >&2
        echo "The runtime ${runtime_id}//${branch} must be installed in the system Flatpak repo." >&2
        exit 1
    fi

    echo "Pulling ${runtime_id}//${branch} from system repo (local, no network)..."
    demo_cmd "ostree pull-local --repo=\"${target_repo}\" --disable-verify-bindings \"${SYSTEM_REPO}\" \"${deploy_ref}\"" \
        "Pulling ${runtime_id}//${branch} from the system Flatpak repo (local, no network)."

    demo_cmd "ostree refs --repo=\"${target_repo}\" --create=\"${canonical_ref}\" \"${deploy_ref}\"" \
        "Creating the canonical ref in the target repo."
}

if [[ "${MODE}" == "bundles" ]]; then
    echo "=== 4. Exporting runtime and GL extension bundles ==="
    demo_cmd "rm -rf \"${RUNTIME_REPO}\"" "Removing any previous runtime repo."
    demo_cmd "ostree init --mode=bare-user-only --repo=\"${RUNTIME_REPO}\"" \
        "Initializing a bare-user-only ostree repo for the runtime bundles."

    pull_runtime "${RUNTIME_REPO}" "org.freedesktop.Platform" "${BRANCH}"
    pull_runtime "${RUNTIME_REPO}" "org.freedesktop.Platform.GL.default" "${BRANCH}"

    demo_cmd "ostree summary --update --repo=\"${RUNTIME_REPO}\"" \
        "Updating the ostree summary metadata."

    echo "Building platform runtime bundle..."
    demo_cmd "timeout 300 flatpak build-bundle --runtime \"${RUNTIME_REPO}\" \"${OUTPUT_DIR}/freedesktop-platform-${BRANCH}.flatpak\" org.freedesktop.Platform \"${BRANCH}\"" \
        "Building the Freedesktop platform runtime bundle."
    echo "Platform bundle: ${OUTPUT_DIR}/freedesktop-platform-${BRANCH}.flatpak"

    echo "Building GL extension bundle..."
    demo_cmd "timeout 300 flatpak build-bundle --runtime \"${RUNTIME_REPO}\" \"${OUTPUT_DIR}/freedesktop-platform-gl-${BRANCH}.flatpak\" org.freedesktop.Platform.GL.default \"${BRANCH}\"" \
        "Building the GL extension runtime bundle."
    echo "GL bundle: ${OUTPUT_DIR}/freedesktop-platform-gl-${BRANCH}.flatpak"

    echo ""
    echo "=== Air-gapped install sequence ==="
    echo "  flatpak install --system freedesktop-platform-${BRANCH}.flatpak"
    echo "  flatpak install --system freedesktop-platform-gl-${BRANCH}.flatpak"
    echo "  flatpak install --no-deps --no-related ocio.flatpak"
    echo ""
    echo "=== Flatpak build complete! (mode: bundles) ==="
    exit 0
fi

if [[ "${MODE}" == "sideload" ]]; then
    echo "=== 4. Building sideload repository (air-gapped distribution) ==="
    demo_cmd "rm -rf \"${SIDEOAL_REPO}\"" "Removing any previous sideload repo."
    demo_cmd "ostree init --mode=archive --repo=\"${SIDEOAL_REPO}\" --collection-id=\"${COLLECTION_ID}\"" \
        "Initializing an archive-mode ostree repo with the collection ID."

    local_app_ref="app/org.packathon.ocio/${ARCH}/master"
    local_app_ref_file="${REPO_DIR}/refs/heads/${local_app_ref}"
    if [ "${DRY_RUN}" = false ] && [[ ! -f "${local_app_ref_file}" ]]; then
        echo "Error: App ref not found: ${local_app_ref_file}" >&2
        echo "flatpak-builder may have used a different branch. Check: ostree refs --repo=${REPO_DIR}" >&2
        exit 1
    fi

    echo "Pulling app commit into sideload repo..."
    demo_cmd "ostree pull-local --repo=\"${SIDEOAL_REPO}\" --disable-verify-bindings \"${REPO_DIR}\" \"${local_app_ref}\"" \
        "Pulling the built app commit into the sideload repo."

    pull_runtime "${SIDEOAL_REPO}" "org.freedesktop.Platform" "${BRANCH}"
    pull_runtime "${SIDEOAL_REPO}" "org.freedesktop.Platform.GL.default" "${BRANCH}"

    demo_cmd "flatpak build-update-repo --generate-static-deltas \"${SIDEOAL_REPO}\"" \
        "Generating static deltas and updating repo metadata."

    echo ""
    echo "=== Sideload repo ready: ${SIDEOAL_REPO} ==="
    echo "Transfer this directory to the target machine, then run:"
    echo "  flatpak remote-add --no-gpg-verify --collection-id=${COLLECTION_ID} \\"
    echo "      packathon-local /path/to/sideload-repo"
    echo "  flatpak install --sideload-repo=/path/to/sideload-repo \\"
    echo "      packathon-local org.packathon.ocio"
    echo ""
    echo "=== Flatpak build complete! (mode: sideload) ==="
    exit 0
fi
