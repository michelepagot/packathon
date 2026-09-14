# Packathon Packaging Guide

This document explains the packaging approaches explored in the **Packathon** project for the **`ocio`** application.

---

## Packaging Comparison Matrix

| Format | Target Ecosystem | Containment / Sandboxing | Dependencies Handling | Generation Tool |
|---|---|---|---|---|
| **Standalone Tarball / Zip** | Linux, macOS, Windows | None | Minimal runtime deps / static raylib | CMake / CPack (`TGZ`, `ZIP`) |
| **`.deb` Package** | Debian, Ubuntu, Mint | System integration | Declared dependencies (`dpkg`/`apt`) | CPack `DEB` generator |
| **`.rpm` Package** | Fedora, RHEL, openSUSE | System integration | Declared dependencies (`rpm`/`dnf`/`zypper`) | CPack `RPM` generator |
| **AppImage** | Cross-distribution Linux | Single-file, runs anywhere | Bundles runtime libraries into AppDir | `linuxdeploy` / `appimagetool` |
| **Flatpak** | Modern Linux desktop | Sandboxed (Bubblewrap, Flatpak runtime) | Bundled in runtime/SDK (`org.freedesktop`) | `flatpak-builder` |

---

## 1. Native Standalone Binaries (Linux, Windows, macOS ARM)

### How it works
- Raylib is fetched and compiled statically during the CMake build.
- The binary is packaged into a compressed archive (`.tar.gz` for Linux and macOS, `.zip` for Windows) along with any desktop integration assets.
- For Windows and macOS, the CPack generators `ZIP` and `TGZ` produce clean drop-in archives.

### Local Command
```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
cd build && cpack -G "TGZ"    # or -G "ZIP" on Windows
```

---

## 2. Debian (`.deb`) and RPM (`.rpm`) via CPack

### How it works
CMake's built-in **CPack** module provides native packaging generators:
- **`CPack DEB`**: Creates Debian archives (`.deb`). CPack generates `control` and `data.tar.gz` conforming to the Debian package standard. It handles dependency strings (such as `libc6`, `libgl1`, `libx11-6`).
- **`CPack RPM`**: Invokes `rpmbuild` under the hood to generate binary RPM packages (`.rpm`) with automatic requirement and provide detection.

### Key CMake Directives
```cmake
set(CPACK_PACKAGE_NAME "ocio")
set(CPACK_GENERATOR "DEB;RPM")
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)
```

### Local Command
```bash
cd build && cpack -G "DEB;RPM"
```

---

## 3. AppImage (`.AppImage`)

### How it works
- An AppImage is an ISO-like or squashfs image containing an entire application directory (`AppDir`), including the binary, desktop entry, application icon, and shared library dependencies not guaranteed on base systems.
- When executed, an embedded runtime mounts the squashfs filesystem via FUSE and launches `AppRun`.
- We use [`linuxdeploy`](https://github.com/linuxdeploy/linuxdeploy) to assemble the `AppDir`, resolve library dependencies, and generate `ocio-x86_64.AppImage`.

### Local Command
```bash
./packaging/appimage/build-appimage.sh
```

---

## 4. Flatpak (`.flatpak`)

### How it works
- Flatpak packages applications in sandboxes using kernel namespaces and Bubblewrap.
- The application runs against a standardized desktop runtime (`org.freedesktop.Platform`) rather than host libraries.
- The manifest [`packaging/flatpak/org.packathon.ocio.yml`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/flatpak/org.packathon.ocio.yml) defines:
  - Permissions (`--share=ipc`, `--socket=x11`, `--socket=wayland`, `--device=dri` for OpenGL graphics).
  - Build module invoking CMake.

### Local Command
```bash
flatpak-builder --force-clean build-dir packaging/flatpak/org.packathon.ocio.yml
flatpak-builder --export-bundle repo ocio.flatpak org.packathon.ocio
```

---

## 5. Explicit Build-Time vs. Runtime Separation (Podman Containerfiles)

To strictly audit, control, and document the toolchains needed for each packaging ecosystem without polluting the host, the project provides multi-stage `Containerfile`s that strictly separate **build-time** dependencies from **runtime** dependencies:

### Dependency Separation Overview

| Ecosystem | Stage | Purpose | Minimal Package Set |
|---|---|---|---|
| **openSUSE** | `builder` | Compiling, static raylib, CPack RPM | `gcc`, `gcc-c++`, `make`, `cmake`, `git`, `ca-certificates-mozilla`, `file`, `tar`, `gzip`, `libX11-devel`, `libXrandr-devel`, `libXinerama-devel`, `libXcursor-devel`, `libXi-devel`, `Mesa-libGL-devel`, `alsa-devel`, `rpm-build` |
| **openSUSE** | `runtime` | Running the `ocio` GUI application | `libX11-6`, `Mesa-libGL1`, `libGLU1`, `libasound2` *(no compilers, no cmake, no devel packages)* |
| **Debian** | `builder` | Compiling, static raylib, CPack DEB | `gcc`, `g++`, `make`, `libc6-dev`, `cmake`, `git`, `ca-certificates`, `file`, `tar`, `gzip`, `libx11-dev`, `libxrandr-dev`, `libxinerama-dev`, `libxcursor-dev`, `libxi-dev`, `libgl1-mesa-dev`, `libglu1-mesa-dev`, `libasound2-dev`, `dpkg-dev` |
| **Debian** | `runtime` | Running the `ocio` GUI application | `libx11-6`, `libgl1`, `libglu1-mesa`, `libglx-mesa0`, `libasound2` *(no compilers, no make, no dev packages)* |

---

### Can Vanilla Minimal Distro Images Run the Binary Directly?
**No.** Both `registry.opensuse.org/opensuse/tumbleweed:latest` and `debian:bookworm-slim` are headless server/container bases that do not bundle graphical display or OpenGL libraries out of the box (`libOpenGL.so.0`, `libGLX.so.0`, `libGLU.so.1`, `libX11.so.6`).

To run `ocio` in either distro, you either:
1. Use the **`runtime`** container stage (installs only the minimal shared libraries required for OpenGL and X11 display).
2. Install the generated package (`zypper in ./ocio-0.1.0-1.x86_64.rpm` or `apt-get install ./ocio_0.1.0_amd64.deb`), which automatically resolves and pulls in strictly the necessary runtime dependencies.

---

### Building Packages (.rpm / .deb) via Podman

Builds occur inside an isolated scratch directory (`/tmp/build`) within the container and output packages directly to `./dist/` on the host, avoiding any conflict with host CMake caches:

```bash
# openSUSE Tumbleweed -> generates .rpm and .tar.gz in ./dist/
podman build --target builder -t localhost/packathon-opensuse:builder -f Containerfile.opensuse .
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-opensuse:builder

# Debian Bookworm -> generates .deb and .tar.gz in ./dist/
podman build --target builder -t localhost/packathon-debian:builder -f Containerfile.debian .
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-debian:builder
```

---

### Running the GUI Application via Podman

Podman runs desktop GUI applications on your local display by mounting the display socket and enabling GPU hardware acceleration:

#### 1. Build the Runtime Image
```bash
# For openSUSE:
podman build --target runtime -t localhost/packathon-opensuse:runtime -f Containerfile.opensuse .

# For Debian:
podman build --target runtime -t localhost/packathon-debian:runtime -f Containerfile.debian .
```

#### 2. Launch GUI Window

**On X11:**
```bash
# Authorize local connections to X server
xhost +local:$USER

# Run container (works with localhost/packathon-opensuse:runtime or localhost/packathon-debian:runtime)
podman run --rm -it \
  --net=host \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  --device /dev/dri \
  localhost/packathon-opensuse:runtime
```

**On Wayland:**
```bash
podman run --rm -it \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:ro" \
  --device /dev/dri \
  localhost/packathon-opensuse:runtime
```


