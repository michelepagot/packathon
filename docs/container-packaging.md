# Container-Based Packaging & Testing Guide

This guide explains how **Packathon** uses [Podman](https://podman.io/) containers. There are two kinds of container, each with one job:

- **Builder images** (`opensuse-builder`, `debian-builder`): only the tools to build `ocio` and every package format. They contain no project source and no build output: you mount the checkout at `/src` and run the build scripts.
- **Vanilla & Demo images** (`opensuse-demo`, `debian-demo`, or upstream unmodified `debian:bookworm-slim`, `registry.opensuse.org/opensuse/tumbleweed`): where `ocio` runs. Without runtime dependencies it fails; after you install them by hand or through a package it works, and it can show the GUI on the host display. The `demo` images provide a clean runtime environment (zero compilers, zero graphics libraries) equipped with presentation ergonomics: `fzf` fuzzy reverse-search (`Ctrl-R`), pre-cooked command history, and distinct colored prompts.

There is no image of ours that contains `ocio`.

---

## Container Images

| Distro | Type | Published on GHCR | Local tag ([if you build it](#using-a-local-build)) | Purpose / Package set |
|---|---|---|---|---|
| **openSUSE** Tumbleweed | **Builder** | `ghcr.io/michelepagot/packathon/opensuse-builder` | `localhost/packathon-opensuse:builder` | All builds (`FETCH`, `LOCAL`, `SYSTEM`), CPack RPM, manual `rpmbuild`, AppImage, Flatpak |
| **openSUSE** Tumbleweed | **Demo** | `ghcr.io/michelepagot/packathon/opensuse-demo` | `localhost/packathon-opensuse:demo` | Clean runtime with demo ergonomics (`fzf`, `Ctrl-R`, pre-cooked history, cyan prompt). Zero compilers or graphics libraries. |
| **Debian** bookworm | **Builder** | `ghcr.io/michelepagot/packathon/debian-builder` | `localhost/packathon-debian:builder` | General builds (`FETCH`, `LOCAL`), CPack DEB, `build-deb.sh`, AppImage, Flatpak |
| **Debian** bookworm | **Demo** | `ghcr.io/michelepagot/packathon/debian-demo` | `localhost/packathon-debian:demo` | Clean runtime with demo ergonomics (`fzf`, `Ctrl-R`, pre-cooked history, blue prompt). Zero compilers or graphics libraries. |

*(For complete package manifests, stage definitions, and toolchain configurations, see [`Containerfile.debian`](../packaging/containers/Containerfile.debian) and [`Containerfile.opensuse`](../packaging/containers/Containerfile.opensuse).)*

The images have no default build: name the script to run after the image. With no command they open a shell.
`WORKDIR` is `/src`, so script paths are relative to the checkout:
```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/debian-builder:latest packaging/containers/build-package.sh
```
Because the scripts run from the mount, edits to the source or the scripts take effect without rebuilding the image.

### Getting the images

The [`containers.yml`](../.github/workflows/containers.yml) workflow publishes both builders and demo runners when a Containerfile changes on `main`, on every `v*` tag, and weekly.
The commands in this guide use the published images: `podman run` pulls them on first use.
Published images are also tagged `sha-<commit>` and with the release version. Use one of those instead of `latest` to pin a specific build.

### Using a local build

Build the images yourself to test a modified Containerfile or to work offline. Nothing is copied into the image, so the build context is `packaging/containers`:
```bash
# Build the vanilla demo images (target: vanilla-demo):
podman build --target vanilla-demo -t localhost/packathon-opensuse:demo -f packaging/containers/Containerfile.opensuse packaging/containers
podman build --target vanilla-demo -t localhost/packathon-debian:demo   -f packaging/containers/Containerfile.debian   packaging/containers

# Build the full builder images (default stage):
podman build -t localhost/packathon-opensuse:builder -f packaging/containers/Containerfile.opensuse packaging/containers
podman build -t localhost/packathon-debian:builder   -f packaging/containers/Containerfile.debian   packaging/containers
```
Then use the local tag in place of the GHCR name in any command of this guide:
```bash
podman run --rm -v "$PWD:/src:Z" localhost/packathon-debian:builder packaging/containers/build-package.sh
```
The scripts that start a builder themselves (`build-deb.sh` on a non-Debian host) use the local tag. To use the published image there, pull it and give it the local tag:
```bash
podman pull ghcr.io/michelepagot/packathon/debian-builder:latest
podman tag  ghcr.io/michelepagot/packathon/debian-builder:latest localhost/packathon-debian:builder
```

### Check, Rebuild, Clean Up
```bash
# List the published and local builder & demo images
podman images 'ghcr.io/michelepagot/packathon/*'
podman images 'localhost/packathon-*'

# Update the published images
podman pull ghcr.io/michelepagot/packathon/opensuse-demo:latest
podman pull ghcr.io/michelepagot/packathon/opensuse-builder:latest
podman pull ghcr.io/michelepagot/packathon/debian-demo:latest
podman pull ghcr.io/michelepagot/packathon/debian-builder:latest

# Rebuild after changing a Containerfile: re-run the same podman build command.
# Add --no-cache to re-run zypper/apt and pick up newer packages,
# and --pull=always to also fetch a newer base image.

# Remove the images
podman rmi ghcr.io/michelepagot/packathon/opensuse-builder:latest ghcr.io/michelepagot/packathon/debian-builder:latest \
           ghcr.io/michelepagot/packathon/opensuse-demo:latest ghcr.io/michelepagot/packathon/debian-demo:latest
podman rmi localhost/packathon-opensuse:builder localhost/packathon-debian:builder \
           localhost/packathon-opensuse:demo localhost/packathon-debian:demo
```

---

## Walkthrough: Build, Fail, Fix, Package, Install

Five steps that show who owns the dependencies. Each step names the image it runs in.
Steps 1, 2 and 4 need no display. Steps 3 and 5 end with a window, so they need the display flags explained in [Running the GUI from a Container](#running-the-gui-from-a-container); without a display (for example in Codespaces) they stop at the last `ocio` error.

### Step 1: build `ocio` from source (Debian builder)
```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/debian-builder:latest \
  sh -c 'cmake -S . -B build-debian -DCMAKE_BUILD_TYPE=Release && cmake --build build-debian -j"$(nproc)"'
```
Result: `build-debian/bin/ocio` in the checkout.
`build-debian/` is the default build directory of `build-deb.sh`, which reuses this binary in step 4 instead of compiling again.

### Step 2: run it in vanilla Debian and watch it fail
```bash
podman run --rm -v "$PWD/build-debian/bin/ocio:/usr/local/bin/ocio:ro,Z" \
  ghcr.io/michelepagot/packathon/debian-demo:latest \
  sh -c 'ldd /usr/local/bin/ocio; ocio --version; ocio'
```
*(You can also use upstream `debian:bookworm-slim`)*
Expected:
- `ldd`: only `libc.so.6` and `libm.so.6`, all found.
- `ocio --version`: works (`ocio 0.1.0`).
- `ocio`: `GLFW: Error: 65544 X11: Failed to load Xlib`, `Failed to initialize GLFW`, then a segmentation fault.

The Debian binary is linked with `--as-needed` and records only `libc` and `libm` (see [Runtime dependencies](../src/README.md#runtime-dependencies)).
The tools say everything is fine, and the program still dies after `main()`, when GLFW tries to `dlopen()` Xlib. This needs no display.

### Step 2b: the same in vanilla Tumbleweed
```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/opensuse-builder:latest \
  sh -c 'cmake -S . -B build-opensuse -DCMAKE_BUILD_TYPE=Release && cmake --build build-opensuse -j"$(nproc)"'
podman run --rm -v "$PWD/build-opensuse/bin/ocio:/usr/local/bin/ocio:ro,Z" \
  ghcr.io/michelepagot/packathon/opensuse-demo:latest \
  sh -c 'ldd /usr/local/bin/ocio; ocio --version; echo "exit $?"'
```
*(You can also use upstream `registry.opensuse.org/opensuse/tumbleweed:latest`)*
Expected:
- `ldd`: `libOpenGL.so.0 => not found`, `libGLX.so.0 => not found`.
- `ocio --version`: `error while loading shared libraries: libOpenGL.so.0`, `exit 127`.

The openSUSE binary records `libOpenGL.so.0` and `libGLX.so.0` as `DT_NEEDED`, so the dynamic loader stops before `main()`: here the tools do see the problem.
The rest of the walkthrough continues on Debian.

### Step 3: install the dependencies by hand (vanilla Debian, with display)
```bash
xhost +SI:localuser:$USER
podman run --rm -it \
  -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --device /dev/dri \
  -v "$PWD/build-debian/bin/ocio:/usr/local/bin/ocio:ro,Z" \
  ghcr.io/michelepagot/packathon/debian-demo:latest bash
```
> [!TIP]
> In `debian-demo`, press `Ctrl-R` to fuzzy-search pre-cooked walkthrough commands (e.g. `ocio`, `apt-get install -y --no-install-recommends libx11-6`, etc.) with `fzf`. Upstream `debian:bookworm-slim` works identically if you type manually.

Inside:
```bash
ocio                                                        # Failed to load Xlib
apt-get update
apt-get install -y --no-install-recommends libx11-6         # one library at a time...
ocio                                                        # GLX: Failed to load GLX
apt-get install -y --no-install-recommends libglx0
ocio                                                        # the eye opens
```
Every `dlopen()` is a separate, later failure. The full list per distro is in [Runtime dependencies](../src/README.md#runtime-dependencies).

### Step 4: build the package (Debian builder)
```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/debian-builder:latest packaging/deb/build-deb.sh
```
Result: `dist/ocio_0.1.0_amd64.deb`, built with the hand-written recipe ([`packaging/deb/`](../packaging/deb/)), with `Depends: libc6 (>= …), libglx0, libx11-6`.
`build-deb.sh` compiles only if `build-debian/bin/ocio` does not exist: after a source change, delete `build-debian/` or re-run step 1.
The CPack alternative is `packaging/containers/build-package.sh` (see [Building Packages in the Builder Images](#building-packages-in-the-builder-images)).

### Step 5: install the package and run it (vanilla Debian, with display)
```bash
xhost +SI:localuser:$USER
podman run --rm -it \
  -e DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix:ro --device /dev/dri \
  -v "$PWD/dist/ocio_0.1.0_amd64.deb:/tmp/ocio.deb:ro,Z" \
  ghcr.io/michelepagot/packathon/debian-demo:latest \
  sh -c 'apt-get update && apt-get install -y /tmp/ocio.deb && ocio'
```
APT installs the declared dependencies and the packages they pull in, then the window opens.
[`packaging/demo/demo-deb.sh`](../packaging/demo/demo-deb.sh) covers this step without a display: it stops at `ldd` and `dpkg --verify`.

### openSUSE variant

The same steps work with `ghcr.io/michelepagot/packathon/opensuse-builder:latest`, `ghcr.io/michelepagot/packathon/opensuse-demo:latest` (or `registry.opensuse.org/opensuse/tumbleweed`), `zypper` and [`packaging/rpm/build-rpm.sh`](../packaging/rpm/build-rpm.sh). Steps 1 and 2 are step 2b.
In step 3, `libglvnd` provides `libOpenGL.so.0` and `libGLX.so.0`, and brings `libX11-6` with it.
Unlike `build-deb.sh`, `build-rpm.sh` always compiles again from the spec.

---

## Running the GUI from a Container

`ocio` runs in a vanilla image, with either the hand-installed libraries (walkthrough step 3) or a package (step 5).

### Running on X11
```bash
# 1. Allow your own user (and nobody else) to connect to the X server
xhost +SI:localuser:$USER

# 2. Share the X11 socket and the GPU device nodes
podman run --rm -it \
  -e DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
  --device /dev/dri \
  debian:bookworm-slim bash
```
- `-e DISPLAY` passes the host's display name.
- `-v /tmp/.X11-unix:/tmp/.X11-unix:ro` mounts the X server socket.
- `--device /dev/dri` gives access to the GPU for hardware rendering.
- `xhost +SI:localuser:$USER` lets processes running as your UID connect. Avoid `xhost +local:`, which opens the display to every local user.

The vanilla images run as root, which rootless Podman maps to your own UID on the host, so the `xhost` rule matches.
If the process in the container runs as another user, rootless Podman maps it to a subordinate UID, which the X server refuses (`Authorization required`). Add `--userns=keep-id` in that case: it runs the container as your own UID.

> [!NOTE]
> Tested on an X11 session with an AMD GPU (hardware rendering through Mesa).
> `--net=host` and `--ipc=host` are not needed: the mounted socket is enough to reach the X server.
> Software rendering (no usable GPU) was not tested.

### Running on Wayland

> [!NOTE]
> Not tested. The bundled GLFW is probably built for X11 only, in which case `ocio` needs XWayland and the X11 recipe above.

```bash
podman run --rm -it \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  -v "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY:ro" \
  --device /dev/dri \
  debian:bookworm-slim bash
```

---

## Building Packages in the Builder Images

The CPack builds use the shared helper script [`packaging/containers/build-package.sh`](../packaging/containers/build-package.sh). It compiles in an isolated scratch space (`/tmp/build`) inside the container, so host CMake caches (`CMakeCache.txt`) are never touched, and exports the packages and the raw `ocio` binary to `/src/dist`, which is `./dist/` on the host.

### Generate `.rpm`, `.tar.gz`, and raw binary (openSUSE)
```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/opensuse-builder:latest packaging/containers/build-package.sh
```
**Output in `./dist/`:**
- `ocio` (standalone binary)
- `ocio-0.1.0-1.x86_64.rpm`
- `ocio-0.1.0-Linux-x86_64.tar.gz`

### Generate `.deb`, `.tar.gz`, and raw binary (Debian)
```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/debian-builder:latest packaging/containers/build-package.sh
```
**Output in `./dist/`:**
- `ocio` (standalone binary)
- `ocio_0.1.0_amd64.deb`
- `ocio-0.1.0-Linux.tar.gz`

### Configuring Build Matrix Options in Containers
[`build-package.sh`](../packaging/containers/build-package.sh) reads CMake options from container environment variables (`-e`):

| Variable | Default / Options | Purpose |
|---|---|---|
| `RAYLIB_MODE` | `FETCH` (options: `FETCH`, `SYSTEM`, `LOCAL`) | Choose where Raylib is obtained: download via Git (`FETCH`), use distro packages (`SYSTEM`, openSUSE only, must be exactly `RAYLIB_VERSION`), or use pre-staged local source (`LOCAL`). |
| `RAYLIB_SHARED` | `OFF` (options: `ON`, `OFF`) | Set to `ON` to link Raylib dynamically as a shared library (`libraylib.so`). |

> [!TIP]
> Ready-to-copy commands for each matrix combination (`FETCH`, `LOCAL`, `SYSTEM`, and `RAYLIB_SHARED=ON`) along with distro-specific behavior notes are documented directly in the usage headers of [`Containerfile.opensuse`](../packaging/containers/Containerfile.opensuse) and [`Containerfile.debian`](../packaging/containers/Containerfile.debian).


### Building Canonical RPMs Manually (Without CPack)

You can build canonical RPM packages manually with `rpmbuild` using [`packaging/rpm/build-rpm.sh`](../packaging/rpm/build-rpm.sh) and [`packaging/rpm/ocio.spec`](../packaging/rpm/ocio.spec):

```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/opensuse-builder:latest packaging/rpm/build-rpm.sh
```
The script builds against the distro `raylib-devel` when its version matches the spec's `raylib_version`, and switches to `--with vendored_raylib` otherwise (it prints which one it picked).
Tumbleweed currently ships raylib 6.0, so the script takes the vendored path: raylib is built from the bundled tarball and linked statically into `ocio`.
The RPM is therefore bigger and has no `libraylib` requirement. Against a matching distro `raylib-devel`, `ocio` would link the shared `libraylib` and the RPM would require it.

This produces in `./dist/`:
- `ocio-0.1.0-1.x86_64.rpm` (binary RPM)
- `ocio-0.1.0-1.src.rpm` (source RPM)
- `ocio-debuginfo-0.1.0-1.x86_64.rpm` (debuginfo)
- `ocio-debugsource-0.1.0-1.x86_64.rpm` (debugsource)

### Building the DEB Manually (Without CPack)

```bash
podman run --rm -v "$PWD:/src:Z" ghcr.io/michelepagot/packathon/debian-builder:latest packaging/deb/build-deb.sh
```
This is walkthrough step 4. On a host without `dpkg-shlibdeps`, `./packaging/deb/build-deb.sh` re-runs itself in the Debian builder.

---

## Testing & Verifying Packages in Pristine Vanilla Containers

This step checks that each package installs on a clean system with only its declared dependencies, and that `ocio` starts.
`ocio --version` exits before opening a window, so it only proves the libraries the binary links directly (`DT_NEEDED`).
The libraries GLFW loads later with `dlopen()` (X11, GLX) are declared by hand, and only a run with a display shows they are present (walkthrough step 5).

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
2. Zypper installs the packages that provide those libraries, together with their own dependencies. For example, `libglvnd` provides `libOpenGL.so.0` and `libGLX.so.0`, and the GL stack brings `Mesa-libGL1`, `Mesa-dri`, `libdrm` and `libX11-6`. The exact list changes as Tumbleweed moves.
   `ocio` never asks for `libX11-6`: no `DT_NEEDED` entry of `ocio` names it. It is a transitive dependency: `libGLX.so.0` itself links `libX11.so.6`, so the package that provides `libGLX.so.0` requires `libX11-6`.
3. `ocio --version` executes successfully and prints `ocio 0.1.0`.

### Testing `.deb` on Pristine Debian Bookworm
```bash
podman run --rm \
  -v "$PWD/dist/ocio_0.1.0_amd64.deb:/ocio.deb:ro,Z" \
  debian:bookworm-slim \
  sh -c "apt-get update && apt-get install -y /ocio.deb && ocio --version"
```
**What happens:**
1. APT inspects `/ocio.deb` and reads `Depends: libc6 (>= …), libglx0, libx11-6`. `dpkg-shlibdeps` computed `libc6` from the binary; `libglx0` and `libx11-6` are declared by hand in `CMakeLists.txt`, because GLFW loads them with `dlopen()` and they leave no `DT_NEEDED` trace.
2. APT installs those packages together with their own dependencies (for example `libglx-mesa0` and `libgl1-mesa-dri`).
3. `ocio --version` executes successfully and prints `ocio 0.1.0`.

---

## Building & Testing AppImage in Podman

Packathon builders come equipped with `appimagetool` and the type 2 runtime pre-extracted into `/usr/lib/appimagetool` to run seamlessly inside containers without requiring FUSE (see [`Containerfile.debian`](../packaging/containers/Containerfile.debian) for setup details). Because `ocio` links raylib statically, no external bundling tool (`linuxdeploy`) is needed.

### 1. Build `ocio-x86_64.AppImage`
Run the build script inside the Debian builder container. An AppImage keeps the glibc baseline of the system it was built on, so one built on Tumbleweed would not start on Bookworm:
```bash
podman run --rm -v "$PWD:/src:Z" \
  -e BUILD_DIR=/tmp/build \
  -e OUTPUT_DIR=/src/dist \
  ghcr.io/michelepagot/packathon/debian-builder:latest \
  packaging/appimage/build-appimage.sh
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

### 3. FUSE in a Container: Extract or Mount
Without extra flags, an AppImage cannot mount itself in a container. Podman does not pass `/dev/fuse` by default, and the vanilla images have no `fusermount3`:
```text
Error: No suitable fusermount binary found on the $PATH
fuse: device not found, try 'modprobe fuse' first

Cannot mount AppImage, please check your FUSE setup.
...
open dir error: No such file or directory
```
There are two solutions:

- **Extract and run (no FUSE, no image change).** The runtime unpacks the payload to `/tmp/appimage_extracted_*` and runs `AppRun` from there. Use the command line flag or the environment variable. They do the same thing:
  ```bash
  podman run --rm -v "$PWD/dist/ocio-x86_64.AppImage:/ocio.AppImage:ro,Z" \
    ghcr.io/michelepagot/packathon/opensuse-demo:latest \
    /ocio.AppImage --appimage-extract-and-run --version

  podman run --rm -e APPIMAGE_EXTRACT_AND_RUN=1 \
    -v "$PWD/dist/ocio-x86_64.AppImage:/ocio.AppImage:ro,Z" \
    ghcr.io/michelepagot/packathon/opensuse-demo:latest \
    /ocio.AppImage --version
  ```
  *(Output: `AppRun 0.1.0`)*

- **Real FUSE mount (as on a desktop).** Pass the device and the capability to mount it, and install `fuse3` (it provides `fusermount3`) in the container:
  ```bash
  podman run --rm -it --device /dev/fuse --cap-add SYS_ADMIN \
    -v "$PWD/dist/ocio-x86_64.AppImage:/ocio.AppImage:ro,Z" \
    ghcr.io/michelepagot/packathon/opensuse-demo:latest bash
  # inside:
  zypper in -y --no-recommends fuse3
  /ocio.AppImage --version          # ocio.AppImage 0.1.0, mounted on /tmp/.mount_ocio.A*
  ```
  Both flags are necessary. Without `/dev/fuse` you get `fuse: device not found`. Without `SYS_ADMIN`, `fusermount3: mount failed: Operation not permitted`. Without `fuse3`, the runtime prints `No suitable fusermount binary found` and then mounts directly, because it runs as root with `SYS_ADMIN`.

Both solutions only remove the FUSE problem. An AppImage built on Tumbleweed records `libOpenGL.so.0` and `libGLX.so.0` and does not bundle them, so in vanilla Tumbleweed it stops next with `error while loading shared libraries: libOpenGL.so.0` until you install `libglvnd` (walkthrough step 2b). The Debian-built AppImage of step 1 records only `libc` and `libm`, so `--version` works and the failure comes later, when GLFW loads Xlib (as in walkthrough step 2). To see the window, add the display flags of [Running the GUI from a Container](#running-the-gui-from-a-container).

> [!NOTE]
> Tested with rootless Podman, on a host without SELinux or AppArmor. With SELinux or AppArmor active, the FUSE mount can also need `--security-opt label=disable` or `--security-opt apparmor=unconfined`.

---

## Building & Testing Flatpak in Podman

Flatpak packaging builds completely autonomously inside the container using the Flatpak Platform and SDK pre-installed in the builder image (see [`Containerfile.debian`](../packaging/containers/Containerfile.debian) and [`Containerfile.opensuse`](../packaging/containers/Containerfile.opensuse) for provisioning details), with zero network download required for runtime dependencies and eliminating any host dependency on `/var/lib/flatpak`.

> [!NOTE]
> `flatpak-builder` uses Bubblewrap (`bwrap`) to create build sandboxes with user namespaces, which requires running Podman with `--privileged`.

### Flatpak Hermetic Sandbox & Dependency Architecture

A core design principle of `flatpak-builder` is **strict network isolation during the compilation phase**:
1. **Source Download Phase (Network ON)**: `flatpak-builder` parses all entries in `modules[].sources` across the manifest (`org.packathon.ocio.yml`) and downloads/clones them.
2. **Build & Install Phase (Network OFF)**: `flatpak-builder` strips all network access from the Bubblewrap build sandbox to guarantee hermetic, reproducible compilation.

Because network is prohibited during the build phase, CMake cannot use `FetchContent` to download Raylib at compile time (doing so results in `fatal: unable to access ... Could not resolve host: github.com`).

To solve this following Flathub best practices, `packaging/flatpak/org.packathon.ocio.yml` decomposes the build into two distinct modules:
- **`raylib` module**: Clones the official Raylib 5.5 tag during the source download phase, compiles it inside the sandbox, and installs it into `/app` (`/app/lib`, `/app/include`).
- **`ocio` module**: Configured with `-DRAYLIB_MODE=SYSTEM`. CMake's `find_package(raylib 5.5 EXACT REQUIRED)` finds the sandbox-installed Raylib in `/app` and links it, without requiring any network connectivity. Its config file reports version `5.5.0`, which CMake accepts as an exact match for `5.5`.

### 1. Build `ocio.flatpak` Bundle
```bash
podman run --privileged --rm -v "$PWD:/src:Z" \
  ghcr.io/michelepagot/packathon/debian-builder:latest \
  packaging/flatpak/build-flatpak.sh
```
This script:
1. Verifies that `org.freedesktop.Platform` and `org.freedesktop.Sdk` matching the manifest's `runtime-version` (25.08) are present (pre-installed in the builder images).
2. Runs `flatpak-builder` to download and compile both `raylib` and `ocio`.
3. Packages a standalone bundle `ocio.flatpak` into `./dist/`.

### 2. Test Flatpak in Container
Install and run the bundle inside a privileged container:
```bash
podman run --privileged --rm -v "$PWD/dist:/dist:ro,Z" \
  ghcr.io/michelepagot/packathon/debian-builder:latest \
  sh -c "flatpak install -y --user /dist/ocio.flatpak && flatpak run org.packathon.ocio --version"
```
*(Output: `ocio 0.1.0`)*
