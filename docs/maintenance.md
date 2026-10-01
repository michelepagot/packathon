# Dependency Updates & Maintenance Guide

This document explains how versions and dependencies are coordinated across **Packathon**, and how to update them.

---

## Coordinated Versions Across the Repository

| Component | Pinned Version | Files to Keep in Sync |
|---|---|---|
| **Raylib** | `5.5` | 1. [`CMakeLists.txt`](../CMakeLists.txt) (`RAYLIB_VERSION`)<br>2. [`packaging/rpm/ocio.spec`](../packaging/rpm/ocio.spec) (`%define raylib_version`)<br>3. [`packaging/flatpak/org.packathon.ocio.yml`](../packaging/flatpak/org.packathon.ocio.yml) (`modules[name=raylib].sources[type=git].tag`) |
| **Flatpak Runtime / SDK** | `25.08` | 1. [`packaging/flatpak/org.packathon.ocio.yml`](../packaging/flatpak/org.packathon.ocio.yml) (`runtime-version`)<br>2. [`packaging/containers/Containerfile.debian`](../packaging/containers/Containerfile.debian)<br>3. [`packaging/containers/Containerfile.opensuse`](../packaging/containers/Containerfile.opensuse)<br>4. [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) & [`.github/workflows/release.yml`](../.github/workflows/release.yml)<br>5. [`docs/container-packaging.md`](container-packaging.md) |
| **AppImage Runtime** | Continuous / Type 2 | 1. [`packaging/containers/Containerfile.*`](../packaging/containers/)<br>2. [`packaging/appimage/build-appimage.sh`](../packaging/appimage/build-appimage.sh) |

---

## Updating the Flatpak Runtime & SDK

When Freedesktop releases a new platform runtime branch or an existing branch reaches End-Of-Life (EOL):

1. **Update Manifest:**
   In [`packaging/flatpak/org.packathon.ocio.yml`](../packaging/flatpak/org.packathon.ocio.yml), update `runtime-version`:
   ```yaml
   runtime-version: '26.08'
   ```

2. **Update Builder Containerfiles:**
   In both [`packaging/containers/Containerfile.debian`](../packaging/containers/Containerfile.debian) and [`packaging/containers/Containerfile.opensuse`](../packaging/containers/Containerfile.opensuse), update the pre-installed runtime and SDK:
   ```dockerfile
   RUN flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo && \
       flatpak install -y --noninteractive flathub \
           org.freedesktop.Platform//26.08 \
           org.freedesktop.Sdk//26.08 && \
       flatpak remote-delete --force flathub && \
       ln -sf /usr/libexec/appstreamcli-compose \
           /var/lib/flatpak/runtime/org.freedesktop.Sdk/x86_64/26.08/active/files/bin/appstream-compose
   ```

3. **Update CI Workflows:**
   In [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) and [`.github/workflows/release.yml`](../.github/workflows/release.yml), update the Flathub builder action image:
   ```yaml
   container:
     image: ghcr.io/flathub-infra/flatpak-github-actions:freedesktop-26.08
   ```

4. **Update Documentation:**
   Update package set tables in [`docs/container-packaging.md`](container-packaging.md).

5. **Rebuild Builder Images:**
   Rebuild locally or trigger [`.github/workflows/containers.yml`](../.github/workflows/containers.yml) to publish updated images to GHCR.

---

## Updating Raylib

When updating the Raylib dependency:

1. **CMake:**
   In [`CMakeLists.txt`](../CMakeLists.txt), bump `RAYLIB_VERSION`:
   ```cmake
   set(RAYLIB_VERSION "5.6")
   ```

2. **RPM Spec:**
   In [`packaging/rpm/ocio.spec`](../packaging/rpm/ocio.spec), bump `%define raylib_version`:
   ```spec
   %define raylib_version 5.6
   ```

3. **Flatpak Manifest:**
   In [`packaging/flatpak/org.packathon.ocio.yml`](../packaging/flatpak/org.packathon.ocio.yml), bump the git tag in the `raylib` module:
   ```yaml
   modules:
     - name: raylib
       sources:
         - type: git
           url: https://github.com/raysan5/raylib.git
           tag: '5.6'
   ```

4. **Verify Distro Packages:**
   In `Containerfile.opensuse`, `raylib-devel` is pulled from the rolling Tumbleweed repository. If Tumbleweed packages a newer version than `RAYLIB_VERSION`, `RAYLIB_MODE=SYSTEM` will safely decline to build and prompt for fallback to `vendored_raylib` / static linking.
