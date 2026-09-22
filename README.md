# Packathon 👁️📦

**Packathon** is a software distribution playground and experimental laboratory.
The central mission of the project is to explore, compare, document and have fun with
modern software packaging and automated release pipelines.


## The excuse: `ocio`

Just the most amazing 15min vibecoded next app I'm sure you must have and will change your life!!!
The user-facing GUI application is **`ocio`**, a lightweight C program powered by [raylib](https://www.raylib.com/)
featuring an interactive eye that tracks the mouse cursor.
`ocio` (*"watch out / look / eye"*) is a single-window graphics application written in C:
- **Gaze Tracking**: Pupil and iris follow cursor position with organic saccadic damping.
- **Version Handling**:
  - In GUI: Press <kbd>V</kbd> to toggle a sleek on-screen version overlay (`Ocio v0.1.0`).
  - In CLI: Pass `--version` / `-v` to print version info and exit.

```bash
$ ocio --version
ocio 0.1.0
```

> [!NOTE]
> **Linking Architecture & Shared Library Dependencies**:
> By default (`-DRAYLIB_SHARED=OFF`), raylib is compiled statically (`libraylib.a`) into `ocio`, leaving only base system runtime dependencies:
> ```
> DT_NEEDED: libm.so.6, libOpenGL.so.0, libGLX.so.0, libGLU.so.1, libc.so.6
> ```
> This makes `ocio` an almost standalone executable requiring no external raylib installation.
> 
> *Note*: If configured with `-DRAYLIB_SHARED=ON` or `-DRAYLIB_MODE=SYSTEM`, `ocio` links dynamically against `libraylib.so`, which must then be provided by the host environment or packaging bundle.

## Controls

| Action | Key / Input |
|---|---|
| Direct Gaze | Move Mouse Cursor |
| Toggle Version Overlay | <kbd>V</kbd> |
| Exit Application | <kbd>Escape</kbd> or close window |

## Release Artifacts

After miserably fails in distributing `ocio` using floppy disks via post mail I decided to explore something else.
Every GitHub release publishes a comprehensive set of distribution artifacts:

| Format / Target | Artifact Name | Description |
|---|---|---|
| **Linux x86_64** | `ocio-0.1.0-Linux-x86_64.tar.gz` | Standalone binary archive with desktop files |
| **Windows x86_64** | `ocio-0.1.0-Windows-x86_64.zip` | Standalone native Windows executable |
| **macOS ARM64** | `ocio-0.1.0-Darwin-arm64.tar.gz` | Native Apple Silicon (M1/M2/M3) binary archive |

But people keep complaining that those are not working on their machines, so let's explore something else

| Format / Target | Artifact Name | Description |
|---|---|---|
| **Debian / Ubuntu** | `ocio_0.1.0_amd64.deb` | Standard `.deb` package built via CPack |
| **RPM (Fedora/RHEL/openSUSE)** | `ocio-0.1.0-1.x86_64.rpm` | Standard `.rpm` package built via CPack |
| **AppImage** | `ocio-x86_64.AppImage` | Standalone single-file executable for any Linux distro |
| **Flatpak** | `ocio.flatpak` | Sandboxed desktop bundle |

For an in-depth breakdown of how each packaging approach works, see the [Packaging Guide](docs/packaging-guide.md) and the [Container-Based Packaging & Testing Guide](docs/container-packaging.md).


## Building from Source

### Prerequisites

- **CMake** 3.16+
- **C99/C11 Compiler** (GCC, Clang, or MSVC)
- **Git** (Raylib 5.5 is automatically fetched via CMake `FetchContent`)

#### Linux Build Dependencies
On Ubuntu / Debian:
```bash
sudo apt-get install -y cmake build-essential git \
    libasound2-dev libx11-dev libxrandr-dev libxi-dev \
    libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev libwayland-dev libxkbcommon-dev rpm
```
On openSUSE / SUSE:
```bash
sudo zypper in -y cmake gcc gcc-c++ git \
    libX11-devel libXrandr-devel libXinerama-devel libXcursor-devel libXi-devel Mesa-libGL-devel alsa-devel rpm-build
```

### Build & Run

```bash
# 1. Configure and build
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release

# 2. Run the application
./build/bin/ocio
```

## Local Packaging Recipes

### Standalone Tarball, Debian (.deb) & RPM (.rpm)
Packathon configures CMake's built-in **CPack** generator to build native packages:
```bash
cd build
cpack -G "TGZ;DEB;RPM"
```
Generated packages will appear in `build/`.

### AppImage
Run the automated packaging script (uses `appimagetool` directly, no `linuxdeploy` required thanks to static raylib linking):
```bash
./packaging/appimage/build-appimage.sh
```
The resulting `ocio-x86_64.AppImage` will be placed in `dist/`.

### Flatpak
Build and bundle using the helper script or `flatpak-builder` directly:
```bash
# Automated helper script (fetches SDK/Platform if missing and bundles ocio.flatpak into dist/):
./packaging/flatpak/build-flatpak.sh

# Or manual step-by-step:
flatpak-builder --force-clean build-dir packaging/flatpak/org.packathon.ocio.yml
flatpak-builder --export-bundle repo ocio.flatpak org.packathon.ocio
```

### Controlled Container Environments (Podman)
Each `Containerfile` separates **build-time** dependencies from clean **runtime** environments via multi-stage builds. Builds occur in container-isolated scratch space (`/tmp/build`) so they never conflict with or overwrite host build caches.

- **Packaging (.rpm / .deb)** (artifacts are exported into `./dist/`):
  ```bash
  # openSUSE (builds .rpm and .tar.gz into ./dist/):
  podman build --target builder -t localhost/packathon-opensuse:builder -f packaging/containers/Containerfile.opensuse .
  podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-opensuse:builder

  # Debian (builds .deb and .tar.gz into ./dist/):
  podman build --target builder -t localhost/packathon-debian:builder -f packaging/containers/Containerfile.debian .
  podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-debian:builder
  ```

- **Running GUI in Podman Container**:
  ```bash
  # 1. Build the minimal runtime image (choose openSUSE or Debian)
  podman build --target runtime -t localhost/packathon-opensuse:runtime -f packaging/containers/Containerfile.opensuse .
  # or:
  podman build --target runtime -t localhost/packathon-debian:runtime -f packaging/containers/Containerfile.debian .

  # 2. Grant X11 access and run ocio on host display
  xhost +local:$USER
  podman run --rm -it --net=host --ipc=host \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    --device /dev/dri \
    localhost/packathon-opensuse:runtime   # or localhost/packathon-debian:runtime
  ```

  For full details on testing packages in vanilla containers, display pass-through, and architectural rationale, see the [Container-Based Packaging & Testing Guide](docs/container-packaging.md).

## Automated CI/CD Pipelines

GitHub Actions workflows are located in [`.github/workflows/`](.github/workflows/):
- **`ci.yml`**: Runs on pull requests and pushes to `main` to verify compilation, test CLI flags, and validate CPack packaging.
- **`release.yml`**: Runs on tag pushes (`v*`) or manual dispatch to compile across a matrix of Linux (x86_64), Windows, macOS (ARM64), package `.deb`, `.rpm`, `.AppImage`, and `.flatpak`, and attach all artifacts to the GitHub Release.

## License

This project is licensed under the [MIT License](LICENSE).
