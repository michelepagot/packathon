# Packathon Packaging Guide

This document explains the packaging approaches explored in the **Packathon** project for the **`ocio`** application.

## Packaging Comparison Matrix

| Format | Target Ecosystem | Containment / Sandboxing | Dependencies Handling | Generation Tool |
|---|---|---|---|---|
| **Standalone Tarball / Zip** | Linux, macOS, Windows | None | Minimal runtime deps / static raylib | CMake / CPack (`TGZ`, `ZIP`) |
| **`.deb` Package** | Debian, Ubuntu, Mint | System integration | Declared dependencies (`dpkg`/`apt`) | CPack `DEB` generator |
| **`.rpm` Package** | Fedora, RHEL, openSUSE | System integration | Declared dependencies (`rpm`/`dnf`/`zypper`) | CPack `RPM` generator |
| **AppImage** | Cross-distribution Linux | Single-file, runs anywhere | Bundles runtime libraries into AppDir | `linuxdeploy` / `appimagetool` |
| **Flatpak** | Modern Linux desktop | Sandboxed (Bubblewrap, Flatpak runtime) | Bundled in runtime/SDK (`org.freedesktop`) | `flatpak-builder` |

## Native Standalone Binaries (Linux, Windows, macOS ARM)

- Raylib is fetched and compiled statically during the CMake build.
- The binary is packaged into a compressed archive (`.tar.gz` for Linux and macOS, `.zip` for Windows) along with any desktop integration assets.
- For Windows and macOS, the CPack generators `ZIP` and `TGZ` produce clean drop-in archives.

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
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

## AppImage (`.AppImage`)

- An AppImage is an ISO-like or squashfs image containing an entire application directory (`AppDir`), including the binary, desktop entry, application icon, and shared library dependencies not guaranteed on base systems.
- When executed, an embedded runtime mounts the squashfs filesystem via FUSE and launches `AppRun`.
- We use [`linuxdeploy`](https://github.com/linuxdeploy/linuxdeploy) to assemble the `AppDir`, resolve library dependencies, and generate `ocio-x86_64.AppImage`.

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
flatpak-builder --force-clean build-dir packaging/flatpak/org.packathon.ocio.yml
flatpak-builder --export-bundle repo ocio.flatpak org.packathon.ocio
```

## Container-Based Packaging & Testing (Podman)

To isolate toolchains without host pollution, test package dependency resolution in upstream distributions,
and safely execute GUI applications, Packathon provides containerized environments for
both **openSUSE Tumbleweed** and **Debian Bookworm**.

For the complete guide on building the container images, obtaining `.rpm` / `.deb` artifacts, verifying packages in vanilla upstream containers, and running the GUI with display/GPU pass-through, see:

👉 **[Container-Based Packaging & Testing Guide](container-packaging.md)**

