# Container-Based Packaging & Testing Guide

This guide explains how **Packathon** uses [Podman](https://podman.io/) containers to provide clean, isolated, and reproducible environments for:
1. **Building** distribution packages (`.rpm`, `.deb`, and standalone archives) without installing compilers or dev libraries on the host.
2. **Testing & Verifying** the generated packages in pristine, untouched upstream distribution images (`openSUSE Tumbleweed` and `Debian Bookworm`) to ensure runtime dependencies resolve automatically.
3. **Running the GUI** directly inside containerized runtimes with local display and GPU hardware pass-through.
4. *(Roadmap)* Extending container-isolated workflows to **AppImage** and **Flatpak** builds and test runs.

## Architectural Philosophy: Build vs. Runtime Separation

To prevent dependency creep and maintain strict control over required toolchains, container images are split into distinct multi-stage targets via `Containerfile`s:

| Ecosystem | Stage | Target Image Name | Purpose | Minimal Package Set |
|---|---|---|---|---|
| **openSUSE** | `builder` | `localhost/packathon-opensuse:builder` | General builds (`FETCH`, `LOCAL`), CPack RPM, AppImage, Flatpak | `gcc`, `gcc-c++`, `make`, `cmake`, `git`, `ca-certificates-mozilla`, `curl`, `file`, `tar`, `gzip`, `libX11-devel`, `libXrandr-devel`, `libXinerama-devel`, `libXcursor-devel`, `libXi-devel`, `Mesa-libGL-devel`, `alsa-devel`, `rpm-build`, `flatpak`, `flatpak-builder`, `appimagetool` *(zero raylib-devel)* |
| **openSUSE** | `builder-system` | `localhost/packathon-opensuse:builder-system` | Distro-style unbundled builds (`RAYLIB_MODE=SYSTEM`, manual `rpmbuild`) | Inherits from `builder` + `raylib-devel`, `libraylib600` |
| **openSUSE** | `runtime` | `localhost/packathon-opensuse:runtime` | Running the `ocio` GUI application | `libX11-6`, `Mesa-libGL1`, `libGLU1`, `libasound2` *(zero compilers, zero devel headers)* |
| **Debian** | `builder` | `localhost/packathon-debian:builder` | General builds (`FETCH`, `LOCAL`), CPack DEB, AppImage, Flatpak | `gcc`, `g++`, `make`, `libc6-dev`, `cmake`, `git`, `ca-certificates`, `curl`, `file`, `tar`, `gzip`, `libx11-dev`, `libxrandr-dev`, `libxinerama-dev`, `libxcursor-dev`, `libxi-dev`, `libgl1-mesa-dev`, `libglu1-mesa-dev`, `libasound2-dev`, `dpkg-dev`, `flatpak`, `flatpak-builder`, `appimagetool` *(zero raylib dev headers)* |
| **Debian** | `builder-system` | `localhost/packathon-debian:builder-system` | Distro-style builds (`RAYLIB_MODE=SYSTEM`) | Inherits from `builder` + pre-compiled Raylib 5.5 in `/usr/local` |
| **Debian** | `runtime` | `localhost/packathon-debian:runtime` | Running the `ocio` GUI application | `libx11-6`, `libgl1`, `libglu1-mesa`, `libglx-mesa0`, `libasound2` *(zero compilers, zero dev headers)* |

## Building the Images

All container builds should be executed from the repository root:

### openSUSE Tumbleweed Images
```bash
# Build the general builder stage (for FETCH and LOCAL modes)
podman build --target builder -t localhost/packathon-opensuse:builder -f packaging/containers/Containerfile.opensuse .

# Build the specialized builder-system stage (for SYSTEM mode and manual rpmbuild)
podman build --target builder-system -t localhost/packathon-opensuse:builder-system -f packaging/containers/Containerfile.opensuse .

# Build the minimal runtime stage (for running GUI)
podman build --target runtime -t localhost/packathon-opensuse:runtime -f packaging/containers/Containerfile.opensuse .
```

### Debian Bookworm Images
```bash
# Build the general builder stage (for FETCH and LOCAL modes)
podman build --target builder -t localhost/packathon-debian:builder -f packaging/containers/Containerfile.debian .

# Build the specialized builder-system stage (for SYSTEM mode)
podman build --target builder-system -t localhost/packathon-debian:builder-system -f packaging/containers/Containerfile.debian .

# Build the minimal runtime stage (for running GUI)
podman build --target runtime -t localhost/packathon-debian:runtime -f packaging/containers/Containerfile.debian .
```

## Obtaining Packaging Artifacts (.rpm & .deb)

Container builds compile the application in an isolated scratch space (`/tmp/build`) inside the container via the shared helper script [`packaging/containers/build-package.sh`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/containers/build-package.sh). This guarantees that host CMake caches (`CMakeCache.txt`) are never overwritten or conflicted. Finished packages and the raw `ocio` binary are automatically exported into `./dist/` on the host:

### Generate `.rpm`, `.tar.gz`, and raw binary (openSUSE)
```bash
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-opensuse:builder
```
**Output in `./dist/`:**
- `ocio` (standalone binary)
- `ocio-0.1.0-1.x86_64.rpm`
- `ocio-0.1.0-Linux-x86_64.tar.gz`

### Generate `.deb`, `.tar.gz`, and raw binary (Debian)
```bash
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-debian:builder
```
**Output in `./dist/`:**
- `ocio` (standalone binary)
- `ocio_0.1.0_amd64.deb`
- `ocio-0.1.0-Linux.tar.gz`

### Configuring Build Matrix Options in Containers
The shared packaging script ([`packaging/containers/build-package.sh`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/containers/build-package.sh)) supports configuring CMake options directly via container environment variables (`-e`):

| Variable | Default / Options | Purpose |
|---|---|---|
| `RAYLIB_MODE` | `FETCH` (options: `FETCH`, `SYSTEM`, `LOCAL`) | Choose where Raylib is obtained: download via Git (`FETCH`), use distro packages (`SYSTEM`), or use pre-staged local source (`LOCAL`). |
| `RAYLIB_SHARED` | `OFF` (options: `ON`, `OFF`) | Set to `ON` to link Raylib dynamically as a shared library (`libraylib.so`). |

**Examples across the matrix:**
```bash
# 1. Standard build (FETCH mode, downloads Raylib via git):
podman run --rm -v "$PWD:/src:Z" -e RAYLIB_MODE=FETCH localhost/packathon-opensuse:builder

# 2. Hermetic / offline build (LOCAL mode, uses pre-staged source with zero network):
podman run --rm -v "$PWD:/src:Z" -e RAYLIB_MODE=LOCAL localhost/packathon-opensuse:builder

# 3. Canonical distro build (SYSTEM mode, requires builder-system container):
podman run --rm -v "$PWD:/src:Z" -e RAYLIB_MODE=SYSTEM localhost/packathon-opensuse:builder-system

# 4. Build packages linking Raylib dynamically:
podman run --rm -v "$PWD:/src:Z" -e RAYLIB_SHARED=ON localhost/packathon-opensuse:builder
```

## Building Canonical RPMs Manually in Podman (Without CPack)

Students can build canonical RPM packages manually with `rpmbuild` using [`packaging/rpm/build-rpm.sh`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/rpm/build-rpm.sh) and [`packaging/rpm/ocio.spec`](file:///home/michelepa/draft/raylib_xp/c_eye_follow/packaging/rpm/ocio.spec):

```bash
podman run --rm -v "$PWD:/src:Z" -w /src \
  localhost/packathon-opensuse:builder-system \
  ./packaging/rpm/build-rpm.sh
```
This produces in `./dist/`:
- `ocio-0.1.0-1.x86_64.rpm` (38 KB binary RPM)
- `ocio-0.1.0-1.src.rpm` (69 KB source RPM)
- `ocio-debuginfo-0.1.0-1.x86_64.rpm` (20 KB debuginfo)
- `ocio-debugsource-0.1.0-1.x86_64.rpm` (11 KB debugsource)

## Testing & Verifying Packages in Pristine Vanilla Containers

A critical validation step is proving that generated packages are truly self-sufficient and declare correct dependencies without requiring manual intervention.

To test this, we mount the freshly generated package into an official, untouched vanilla upstream container (which has zero GUI, zero X11, and zero OpenGL packages installed), install it with the native package manager, and verify execution:

### Testing `.rpm` on Pristine openSUSE Tumbleweed
```bash
podman run --rm \
  -v "$PWD/dist/ocio-0.1.0-1.x86_64.rpm:/ocio.rpm:ro,Z" \
  registry.opensuse.org/opensuse/tumbleweed:latest \
  sh -c "zypper --non-interactive in --allow-unsigned-rpm /ocio.rpm && ocio --version"
```
**What happens:**
1. Zypper inspects `/ocio.rpm` and finds ELF `DT_NEEDED` capabilities: `libOpenGL.so.0()(64bit)`, `libGLX.so.0()(64bit)`, `libc.so.6`, `libm.so.6`.
2. Zypper automatically resolves and downloads the full driver stack (36 packages, including `Mesa-libGL1`, `libX11-6`, `Mesa-dri`, `libdrm`).
3. `ocio --version` executes successfully and prints `ocio 0.1.0`.

### Testing `.deb` on Pristine Debian Bookworm
```bash
podman run --rm \
  -v "$PWD/dist/ocio_0.1.0_amd64.deb:/ocio.deb:ro,Z" \
  debian:bookworm-slim \
  sh -c "apt-get update && apt-get install -y /ocio.deb && ocio --version"
```
**What happens:**
1. APT inspects `/ocio.deb` and reads `Depends: libc6 (>= 2.17), libgl1, libx11-6`.
2. APT resolves the dependency tree and downloads 40 packages (including `libgl1`, `libglx-mesa0`, `libgl1-mesa-dri`, `libx11-6`).
3. `ocio --version` executes successfully and prints `ocio 0.1.0`.

## Running the GUI Application via Podman

Podman can run the interactive `ocio` GUI on the host's physical display by sharing the X11 or Wayland socket and granting access to the host GPU DRI device node (`/dev/dri`):

### Running on X11
```bash
# 1. Authorize local container connections to the X server
xhost +local:$USER

# 2. Launch container (choose openSUSE or Debian runtime)
podman run --rm -it \
  --net=host \
  --ipc=host \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  --device /dev/dri \
  localhost/packathon-opensuse:runtime   # or localhost/packathon-debian:runtime
```
> [!TIP]
> The `--net=host --ipc=host` flags allow MIT-SHM (shared memory) communication between the raylib/GLFW client inside the container and the X server on the host, preventing display latency and protocol errors.

### Running on Wayland
```bash
podman run --rm -it \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:ro" \
  --device /dev/dri \
  localhost/packathon-opensuse:runtime   # or localhost/packathon-debian:runtime
```

## Building & Testing AppImage in Podman

Packathon builders come equipped with `appimagetool` pre-extracted into `/usr/lib/appimagetool` to run seamlessly inside containers without requiring FUSE. Because `ocio` links raylib statically, no external bundling tool (`linuxdeploy`) is needed.

### 1. Build `ocio-x86_64.AppImage`
Run the build script inside either the openSUSE or Debian builder container:
```bash
podman run --rm -v "$PWD:/src:Z" -w /src \
  -e BUILD_DIR=/tmp/build \
  -e OUTPUT_DIR=/src/dist \
  localhost/packathon-debian:builder \
  ./packaging/appimage/build-appimage.sh
```
The resulting `ocio-x86_64.AppImage` (~1.4 MB) is placed in `./dist/`.

### 2. Verify Execution in Pristine Vanilla Containers
Test the resulting single-file `.AppImage` in untouched base distribution containers using `--appimage-extract-and-run`:

- **In Vanilla openSUSE Tumbleweed**:
  ```bash
  podman run --rm \
    -v "$PWD/dist/ocio-x86_64.AppImage:/ocio.AppImage:ro,Z" \
    registry.opensuse.org/opensuse/tumbleweed:latest \
    /ocio.AppImage --appimage-extract-and-run --version
  ```
  *(Output: `AppRun 0.1.0`)*

- **In Vanilla Debian Bookworm**:
  ```bash
  podman run --rm \
    -v "$PWD/dist/ocio-x86_64.AppImage:/ocio.AppImage:ro,Z" \
    debian:bookworm-slim \
    /ocio.AppImage --appimage-extract-and-run --version
  ```
  *(Output: `AppRun 0.1.0`)*

## Building & Testing Flatpak in Podman

Flatpak packaging builds completely autonomously inside the container by downloading required runtime dependencies directly from Flathub into container storage, eliminating any host dependency on `/var/lib/flatpak`.

> [!NOTE]
> `flatpak-builder` uses Bubblewrap (`bwrap`) to create build sandboxes with user namespaces, which requires running Podman with `--privileged`.

### Flatpak Hermetic Sandbox & Dependency Architecture

A core design principle of `flatpak-builder` is **strict network isolation during the compilation phase**:
1. **Source Download Phase (Network ON)**: `flatpak-builder` parses all entries in `modules[].sources` across the manifest (`org.packathon.ocio.yml`) and downloads/clones them.
2. **Build & Install Phase (Network OFF)**: `flatpak-builder` strips all network access from the Bubblewrap build sandbox to guarantee hermetic, reproducible compilation.

Because network is prohibited during the build phase, CMake cannot use `FetchContent` to download Raylib at compile time (doing so results in `fatal: unable to access ... Could not resolve host: github.com`).

To solve this following Flathub best practices, `packaging/flatpak/org.packathon.ocio.yml` decomposes the build into two distinct modules:
- **`raylib` module**: Clones the official Raylib 5.5 tag during the source download phase, compiles it inside the sandbox, and installs it into `/app` (`/app/lib`, `/app/include`).
- **`ocio` module**: Configured with `-DRAYLIB_MODE=SYSTEM`. CMake's `find_package(raylib REQUIRED)` automatically detects the sandbox-installed Raylib in `/app` and links it, without requiring any network connectivity.

### 1. Build `ocio.flatpak` Bundle
```bash
podman run --privileged --rm -v "$PWD:/src:Z" -w /src \
  localhost/packathon-debian:builder \
  ./packaging/flatpak/build-flatpak.sh
```
This script:
1. Adds the Flathub remote inside the container.
2. Installs `org.freedesktop.Platform//24.08` and `org.freedesktop.Sdk//24.08`.
3. Runs `flatpak-builder` to download and compile both `raylib` and `ocio`.
4. Packages a standalone bundle `ocio.flatpak` into `./dist/`.

### 2. Test Flatpak in Container
Install and run the bundle inside a privileged container:
```bash
podman run --privileged --rm -v "$PWD/dist:/dist:ro,Z" \
  localhost/packathon-debian:builder \
  sh -c "flatpak install -y --user /dist/ocio.flatpak && flatpak run org.packathon.ocio --version"
```
*(Output: `ocio 0.1.0`)*

