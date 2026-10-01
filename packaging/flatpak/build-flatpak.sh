#!/usr/bin/env bash
set -euo pipefail

# Build Flatpak bundle for ocio (Packathon project)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-/tmp/flatpak-build}"
REPO_DIR="${REPO_DIR:-/tmp/flatpak-repo}"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/dist}"
MANIFEST="${SCRIPT_DIR}/org.packathon.ocio.yml"
BUNDLE="${OUTPUT_DIR}/ocio.flatpak"
STATE_DIR="${STATE_DIR:-/tmp/flatpak-builder-state}"
BRANCH="$(sed -n "s/^runtime-version: *'\{0,1\}\([^']*\)'\{0,1\} *$/\1/p" "${MANIFEST}")"

mkdir -p "${OUTPUT_DIR}"

echo "=== 1. Checking Flatpak SDK/Runtime (${BRANCH}) ==="
if ! flatpak info "org.freedesktop.Platform//${BRANCH}" >/dev/null 2>&1 || \
   ! flatpak info "org.freedesktop.Sdk//${BRANCH}" >/dev/null 2>&1; then
    echo "Error: Flatpak runtime org.freedesktop.Platform//${BRANCH} or SDK org.freedesktop.Sdk//${BRANCH} is not installed." >&2
    echo "They are pre-installed in the Packathon builder container images." >&2
    echo "To install them on your host, run:" >&2
    echo "  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" >&2
    echo "  flatpak install flathub org.freedesktop.Platform//${BRANCH} org.freedesktop.Sdk//${BRANCH}" >&2
    exit 1
fi
echo "SDK and Runtime ${BRANCH} found."

# In Freedesktop SDK >= 24.08 (including 25.08), appstream-compose was replaced by
# /usr/libexec/appstreamcli-compose. flatpak-builder expects appstream-compose in PATH
# inside the SDK to compose metadata. Ensure symlink exists if writable.
for sdk_files in /var/lib/flatpak/runtime/org.freedesktop.Sdk/x86_64/"${BRANCH}"/active/files \
                 "${HOME}/.local/share/flatpak/runtime/org.freedesktop.Sdk/x86_64/${BRANCH}/active/files"; do
    if [ -d "${sdk_files}/bin" ] && [ -f "${sdk_files}/libexec/appstreamcli-compose" ] && [ ! -e "${sdk_files}/bin/appstream-compose" ]; then
        ln -sf /usr/libexec/appstreamcli-compose "${sdk_files}/bin/appstream-compose" 2>/dev/null || true
    fi
done

echo "=== 2. Building application with flatpak-builder ==="
flatpak-builder --force-clean --state-dir="${STATE_DIR}" --repo="${REPO_DIR}" "${BUILD_DIR}" "${MANIFEST}"

echo "=== 3. Exporting single-file Flatpak bundle ==="
flatpak build-bundle "${REPO_DIR}" "${BUNDLE}" org.packathon.ocio

echo "=== Flatpak build complete! Output: ${BUNDLE} ==="
