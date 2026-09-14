# Packathon 👁️📦

**Packathon** is a software distribution playground and experimental laboratory. While the user-facing GUI application is **`ocio`** (a lightweight C program powered by [raylib](https://www.raylib.com/) featuring an interactive eye whose gaze tracks the mouse cursor), the central mission of the project is to explore, compare, and document modern multi-format software packaging and automated release pipelines.

---

## The Application: `ocio`

`ocio` (*"watch out / look / eye"*) is a single-window graphics application written in C:
- **Gaze Tracking**: Pupil and iris follow cursor position with organic saccadic damping.
- **Version Handling**:
  - In GUI: Press <kbd>V</kbd> to toggle a sleek on-screen version overlay (`Ocio v0.1.0`).
  - In CLI: Pass `--version` / `-v` to print version info and exit.

```bash
$ ocio --version
ocio 0.1.0
```

---

## Release Artifacts

Every GitHub release publishes a comprehensive set of distribution artifacts:

| Format / Target | Artifact Name | Description |
|---|---|---|
| **Linux x86_64** | `ocio-0.1.0-Linux-x86_64.tar.gz` | Standalone binary archive with desktop files |
| **Windows x86_64** | `ocio-0.1.0-Windows-x86_64.zip` | Standalone native Windows executable |
| **macOS ARM64** | `ocio-0.1.0-Darwin-arm64.tar.gz` | Native Apple Silicon (M1/M2/M3) binary archive |
| **Debian / Ubuntu** | `ocio_0.1.0_amd64.deb` | Standard `.deb` package built via CPack |
| **RPM (Fedora/RHEL/openSUSE)** | `ocio-0.1.0-1.x86_64.rpm` | Standard `.rpm` package built via CPack |
| **AppImage** | `ocio-x86_64.AppImage` | Standalone single-file executable for any Linux distro |
| **Flatpak** | `ocio.flatpak` | Sandboxed desktop bundle |

For an in-depth breakdown of how each packaging approach works and their respective trade-offs, see the [Packaging Guide](docs/packaging-guide.md).

---

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

---

## Local Packaging Recipes

### 1. Standalone Tarball, Debian (.deb) & RPM (.rpm)
Packathon configures CMake's built-in **CPack** generator to build native packages:
```bash
cd build
cpack -G "TGZ;DEB;RPM"
```
Generated packages will appear in `build/`.

### 2. AppImage
Run the automated packaging script (uses `linuxdeploy`):
```bash
./packaging/appimage/build-appimage.sh
```
The resulting `ocio-x86_64.AppImage` will be placed in `dist/`.

### 3. Flatpak
Build and bundle using `flatpak-builder`:
```bash
flatpak-builder --force-clean build-dir packaging/flatpak/org.packathon.ocio.yml
flatpak-builder --export-bundle repo ocio.flatpak org.packathon.ocio
```

### 4. Controlled Container Environments (Podman)
Each `Containerfile` separates **build-time** dependencies from clean **runtime** environments via multi-stage builds. Builds occur in container-isolated scratch space (`/tmp/build`) so they never conflict with or overwrite host build caches.

- **Packaging (.rpm / .deb)** (artifacts are exported into `./dist/`):
  ```bash
  # openSUSE (builds .rpm and .tar.gz into ./dist/):
  podman build --target builder -t localhost/packathon-opensuse:builder -f Containerfile.opensuse .
  podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-opensuse:builder

  # Debian (builds .deb and .tar.gz into ./dist/):
  podman build --target builder -t localhost/packathon-debian:builder -f Containerfile.debian .
  podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-debian:builder
  ```

- **Running GUI in Podman Container**:
  ```bash
  # 1. Build the minimal runtime image (choose openSUSE or Debian)
  podman build --target runtime -t localhost/packathon-opensuse:runtime -f Containerfile.opensuse .
  # or:
  podman build --target runtime -t localhost/packathon-debian:runtime -f Containerfile.debian .

  # 2. Grant X11 access and run ocio on host display
  xhost +local:$USER
  podman run --rm -it --net=host --ipc=host \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix:ro \
    --device /dev/dri \
    localhost/packathon-opensuse:runtime   # or localhost/packathon-debian:runtime
  ```


---

## Automated CI/CD Pipelines

GitHub Actions workflows are located in [`.github/workflows/`](.github/workflows/):
- **`ci.yml`**: Runs on pull requests and pushes to `main` to verify compilation, test CLI flags, and validate CPack packaging.
- **`release.yml`**: Runs on tag pushes (`v*`) or manual dispatch to compile across a matrix of Linux (x86_64), Windows, macOS (ARM64), package `.deb`, `.rpm`, `.AppImage`, and `.flatpak`, and attach all artifacts to the GitHub Release.

---

## Controls

| Action | Key / Input |
|---|---|
| Direct Gaze | Move Mouse Cursor |
| Toggle Version Overlay | <kbd>V</kbd> |
| Exit Application | <kbd>Escape</kbd> or close window |

---

## License

This project is licensed under the [MIT License](LICENSE).
