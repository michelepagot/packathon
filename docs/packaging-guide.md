# Packathon Packaging Guide

This document explains the packaging approaches explored in the **Packathon** project for the **`ocio`** application.

## Packaging Comparison Matrix

| Format | Target Ecosystem | Containment / Sandboxing | Dependencies Handling | Generation Tool |
|---|---|---|---|---|
| **Standalone Tarball / Zip** | Linux, macOS, Windows | None | Minimal runtime deps / static raylib | CMake / CPack (`TGZ`, `ZIP`) |
| **`.deb` Package (CPack)** | Debian, Ubuntu, Mint | System integration | Declared dependencies (`dpkg`/`apt`) | CPack `DEB` generator |
| **`.rpm` Package (CPack)** | Fedora, RHEL, openSUSE | System integration | Declared dependencies (`rpm`/`dnf`/`zypper`) | CPack `RPM` generator |
| **Canonical Native `.rpm`** | Fedora, openSUSE, RHEL | System integration + unbundling | Automatic ELF dependency tracking (`find-requires`) | `rpmbuild` via [`packaging/rpm/ocio.spec`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/rpm/ocio.spec) |
| **AppImage** | Cross-distribution Linux | Single-file, runs anywhere | Bundles runtime libraries into AppDir | `appimagetool` (no `linuxdeploy` needed) |
| **Flatpak** | Modern Linux desktop | Sandboxed (Bubblewrap, Flatpak runtime) | Bundled in runtime/SDK (`org.freedesktop`) | `flatpak-builder` via [`packaging/flatpak/build-flatpak.sh`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/flatpak/build-flatpak.sh) |

## Native Standalone Binaries (Linux, Windows, macOS ARM)

The application supports flexible compilation modes configured via `RAYLIB_MODE`:
- `FETCH` (default): Raylib is fetched and compiled statically from GitHub during the CMake build.
- `LOCAL`: Raylib is compiled offline from pre-staged source directory (`build/_deps/raylib-src`).
- `SYSTEM`: Raylib is discovered from host packages via `find_package(raylib REQUIRED)`.

```bash
# Standard standalone build (static raylib fetched via git):
cmake -B build -DCMAKE_BUILD_TYPE=Release -DRAYLIB_MODE=FETCH
cmake --build build --config Release
cd build && cpack -G "TGZ"    # or -G "ZIP" on Windows
```

## Debian (`.deb`) and RPM (`.rpm`) via CPack

CMake's built-in **CPack** module provides native packaging generators:
- **`CPack DEB`**: Creates Debian archives (`.deb`). CPack generates `control` and `data.tar.gz` conforming to the Debian package standard. It handles dependency strings (such as `libc6`, `libgl1`, `libx11-6`).
- **`CPack RPM`**: Invokes `rpmbuild` under the hood to generate binary RPM packages (`.rpm`) with automatic requirement and provide detection.

```bash
cd build && cpack -G "DEB;RPM"
```

### Key CMake Directives
```cmake
set(CPACK_PACKAGE_NAME "ocio")
set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)
```

## Canonical RPM Packaging via `rpmbuild` (Without CPack)

To adhere to official upstream distribution standards (openSUSE, Fedora) without CPack abstractions, the project provides a canonical RPM spec file: [`packaging/rpm/ocio.spec`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/rpm/ocio.spec).

### Key Architectural Advantages
1. **Unbundling Policy**: Links against distro-provided shared library (`libraylib.so.600`), yielding a compact **38 KB** RPM instead of a statically bundled megabyte package.
2. **Automatic Shared Library Dependencies**: RPM's `find-requires` scans ELF `DT_NEEDED` headers and automatically generates package requirements (`libraylib.so.600()(64bit)`, `libc.so.6`, `libm.so.6`).
3. **Debuginfo Splitting**: Automatically extracts symbols into separate `ocio-debuginfo` and `ocio-debugsource` RPM packages.
4. **Multi-Source Support**: Provides `%bcond_with vendored_raylib` to support hermetic, air-gapped builds for OBS/Koji environments.

### Building Manually
```bash
# Using the helper script inside the openSUSE builder container:
podman run --rm -v "$PWD:/src:Z" -w /src \
  localhost/packathon-opensuse:builder-system \
  ./packaging/rpm/build-rpm.sh
```
Outputs in `./dist/`:
- `ocio-0.1.0-1.x86_64.rpm` (Binary package, 38 KB)
- `ocio-0.1.0-1.src.rpm` (Source package / SRPM, 69 KB)
- `ocio-debuginfo-0.1.0-1.x86_64.rpm` (Debug symbols, 20 KB)
- `ocio-debugsource-0.1.0-1.x86_64.rpm` (Debug source, 11 KB)

## AppImage (`.AppImage`)

- An AppImage is an ISO-like or squashfs image containing an entire application directory (`AppDir`), including the binary, desktop entry, application icon, and shared library dependencies not guaranteed on base systems.
- When executed, an embedded runtime mounts the squashfs filesystem via FUSE (or extracts in memory via `--appimage-extract-and-run`) and launches `AppRun`.
- Because `ocio` links raylib statically and depends only on universal system libraries (`libc`, `libm`, `libGL`), external bundle tools like `linuxdeploy` are not needed. We assemble the `AppDir` directly and package it with `appimagetool`.

```bash
./packaging/appimage/build-appimage.sh
```

## Flatpak (`.flatpak`)

- Flatpak packages applications in sandboxes using kernel namespaces and Bubblewrap.
- The application runs against a standardized desktop runtime (`org.freedesktop.Platform`) rather than host libraries.
- The manifest [`packaging/flatpak/org.packathon.ocio.yml`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/flatpak/org.packathon.ocio.yml) defines:
  - Permissions (`--share=ipc`, `--socket=x11`, `--socket=wayland`, `--device=dri` for OpenGL graphics).
  - Build module invoking CMake.

```bash
# Automated helper script:
./packaging/flatpak/build-flatpak.sh

# Or manual step-by-step:
flatpak-builder --force-clean build-dir packaging/flatpak/org.packathon.ocio.yml
flatpak-builder --export-bundle repo ocio.flatpak org.packathon.ocio
```

## Container-Based Packaging & Testing (Podman)

To isolate toolchains without host pollution, test package dependency resolution in upstream distributions,
and safely execute GUI applications, Packathon provides containerized environments for
both **openSUSE Tumbleweed** and **Debian Bookworm**.

For the complete guide on building the container images, obtaining `.rpm` / `.deb` artifacts, verifying packages in vanilla upstream containers, and running the GUI with display/GPU pass-through, see:

👉 **[Container-Based Packaging & Testing Guide](container-packaging.md)**

