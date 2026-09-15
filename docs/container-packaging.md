# Container-Based Packaging & Testing Guide

This guide explains how **Packathon** uses [Podman](https://podman.io/) containers to provide clean, isolated, and reproducible environments for:
1. **Building** distribution packages (`.rpm`, `.deb`, and standalone archives) without installing compilers or dev libraries on the host.
2. **Testing & Verifying** the generated packages in pristine, untouched upstream distribution images (`openSUSE Tumbleweed` and `Debian Bookworm`) to ensure runtime dependencies resolve automatically.
3. **Running the GUI** directly inside containerized runtimes with local display and GPU hardware pass-through.
4. *(Roadmap)* Extending container-isolated workflows to **AppImage** and **Flatpak** builds and test runs.

---

## 1. Architectural Philosophy: Build vs. Runtime Separation

To prevent dependency creep and maintain strict control over required toolchains, container images are split into two distinct stages via multi-stage `Containerfile`s:

| Ecosystem | Stage | Target Image Name | Purpose | Minimal Package Set |
|---|---|---|---|---|
| **openSUSE** | `builder` | `localhost/packathon-opensuse:builder` | Compiling C/C++, static raylib, CPack RPM | `gcc`, `gcc-c++`, `make`, `cmake`, `git`, `ca-certificates-mozilla`, `file`, `tar`, `gzip`, `libX11-devel`, `libXrandr-devel`, `libXinerama-devel`, `libXcursor-devel`, `libXi-devel`, `Mesa-libGL-devel`, `alsa-devel`, `rpm-build` |
| **openSUSE** | `runtime` | `localhost/packathon-opensuse:runtime` | Running the `ocio` GUI application | `libX11-6`, `Mesa-libGL1`, `libGLU1`, `libasound2` *(zero compilers, zero devel headers)* |
| **Debian** | `builder` | `localhost/packathon-debian:builder` | Compiling C/C++, static raylib, CPack DEB | `gcc`, `g++`, `make`, `libc6-dev`, `cmake`, `git`, `ca-certificates`, `file`, `tar`, `gzip`, `libx11-dev`, `libxrandr-dev`, `libxinerama-dev`, `libxcursor-dev`, `libxi-dev`, `libgl1-mesa-dev`, `libglu1-mesa-dev`, `libasound2-dev`, `dpkg-dev` |
| **Debian** | `runtime` | `localhost/packathon-debian:runtime` | Running the `ocio` GUI application | `libx11-6`, `libgl1`, `libglu1-mesa`, `libglx-mesa0`, `libasound2` *(zero compilers, zero dev headers)* |

---

## 2. Building the Images

All container builds should be executed from the repository root:

### openSUSE Tumbleweed Images
```bash
# Build the builder stage (for compiling & packaging .rpm)
podman build --target builder -t localhost/packathon-opensuse:builder -f Containerfile.opensuse .

# Build the minimal runtime stage (for running GUI)
podman build --target runtime -t localhost/packathon-opensuse:runtime -f Containerfile.opensuse .
```

### Debian Bookworm Images
```bash
# Build the builder stage (for compiling & packaging .deb)
podman build --target builder -t localhost/packathon-debian:builder -f Containerfile.debian .

# Build the minimal runtime stage (for running GUI)
podman build --target runtime -t localhost/packathon-debian:runtime -f Containerfile.debian .
```

---

## 3. Obtaining Packaging Artifacts (.rpm & .deb)

Container builds compile the application in an isolated scratch space (`/tmp/build`) inside the container. This guarantees that host CMake caches (`CMakeCache.txt`) are never overwritten or conflicted. Finished packages are automatically exported into `./dist/` on the host:

### Generate `.rpm` and `.tar.gz` (openSUSE)
```bash
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-opensuse:builder
```
**Output in `./dist/`:**
- `ocio-0.1.0-1.x86_64.rpm`
- `ocio-0.1.0-Linux-x86_64.tar.gz`

### Generate `.deb` and `.tar.gz` (Debian)
```bash
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-debian:builder
```
**Output in `./dist/`:**
- `ocio_0.1.0_amd64.deb`
- `ocio-0.1.0-Linux.tar.gz`

---

## 4. Testing & Verifying Packages in Pristine Vanilla Containers

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

---

## 5. Running the GUI Application via Podman

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

---

## 6. Roadmap: Extending to AppImage & Flatpak

This containerized build and test workflow is designed to expand to additional packaging formats:

### AppImage in Podman (Planned)
- **Builder**: A container based on an older LTS baseline (e.g. `ubuntu:20.04` or `rockylinux:8`) to guarantee maximum backward glibc compatibility for the generated `ocio-x86_64.AppImage`.
- **Testing**: Running the resulting `.AppImage` inside vanilla target containers using FUSE emulation or `--appimage-extract-and-run`.

### Flatpak in Podman (Planned)
- **Builder**: A container equipped with `flatpak-builder` and the `org.freedesktop.Sdk` runtime to compile and generate `ocio.flatpak` in an isolated environment without needing Flatpak SDKs on the host.
- **Testing**: Validating manifest sandboxing permissions and bundle installation in headless container environments.
