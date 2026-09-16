#!/bin/bash
# =============================================================================
# Build ocio RPM manually using rpmbuild (No CPack)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

VERSION="0.1.0"
NAME="ocio"
RPM_TOPDIR="${RPM_TOPDIR:-/tmp/rpmbuild}"

echo "==> Setting up clean RPM build tree in ${RPM_TOPDIR}..."
rm -rf "${RPM_TOPDIR}"
mkdir -p "${RPM_TOPDIR}"/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}

echo "==> Creating source tarball ${NAME}-${VERSION}.tar.gz..."
tar --exclude='.git' \
    --exclude='build*' \
    --exclude='dist' \
    --transform="s,^\.,${NAME}-${VERSION}," \
    -czf "${RPM_TOPDIR}/SOURCES/${NAME}-${VERSION}.tar.gz" \
    -C "${REPO_ROOT}" .

echo "==> Copying spec file..."
cp "${SCRIPT_DIR}/ocio.spec" "${RPM_TOPDIR}/SPECS/"

echo "==> Running rpmbuild (Binary & Source RPMs)..."
rpmbuild -ba \
    --define "_topdir ${RPM_TOPDIR}" \
    "$@" \
    "${RPM_TOPDIR}/SPECS/ocio.spec"

echo "==> Collecting generated RPMs into dist/..."
mkdir -p "${REPO_ROOT}/dist"
cp -f "${RPM_TOPDIR}/RPMS"/*/*.rpm "${REPO_ROOT}/dist/"
cp -f "${RPM_TOPDIR}/SRPMS"/*.src.rpm "${REPO_ROOT}/dist/"

echo "==> Generated RPM packages in dist/:"
ls -lh "${REPO_ROOT}/dist/"*.rpm

RPM_FILE=$(ls "${REPO_ROOT}/dist/${NAME}-${VERSION}"*.x86_64.rpm | head -n1)
echo "==> Package information (rpm -qip):"
rpm -qip "${RPM_FILE}"

echo "==> Auto-detected RPM dependencies (rpm -qp --requires):"
rpm -qp --requires "${RPM_FILE}"

echo "==> RPM payload files (rpm -qpl):"
rpm -qpl "${RPM_FILE}"
