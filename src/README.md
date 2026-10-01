# `ocio`

`ocio` (Italian for *"eye"*, or *"watch out"*) is the test subject of [Packathon](../README.md):
a single-window C99 program, built on [raylib](https://www.raylib.com/), that draws an eye that follows the mouse cursor.

The whole application is one file, [`main.c`](main.c) (~280 lines).
It has no business logic on purpose, so nothing distracts from the packaging.

## Features

- **Gaze tracking**: the pupil and iris follow the cursor, with damped motion.
- **Version overlay**: press <kbd>V</kbd> to toggle `Ocio v0.1.0` on screen.
- **CLI flags**: `--version` / `-v` and `--help` / `-h` print to stdout and exit before any window opens.

```console
$ ocio --version
ocio 0.1.0
```

## Controls

| Action | Input |
|---|---|
| Move the gaze | Move the mouse cursor |
| Toggle version overlay | <kbd>V</kbd> |
| Quit | <kbd>Escape</kbd> or close the window |

## Building from source

### Prerequisites

- CMake 3.16+
- A C99 compiler (GCC, Clang or MSVC)
- Git (raylib 5.5 is fetched by CMake `FetchContent` by default)

On Debian / Ubuntu:
```bash
sudo apt-get install -y cmake build-essential git \
    libasound2-dev libx11-dev libxrandr-dev libxi-dev \
    libgl1-mesa-dev libglu1-mesa-dev libxcursor-dev libxinerama-dev libwayland-dev libxkbcommon-dev
```

On openSUSE:
```bash
sudo zypper in -y cmake gcc git \
    libX11-devel libXrandr-devel libXinerama-devel libXcursor-devel libXi-devel Mesa-libGL-devel alsa-devel
```

If you don't want to install a toolchain on the host, use the builder containers instead. See [Container-Based Packaging & Testing](../docs/container-packaging.md).

### Build and run

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release
./build/bin/ocio
```

### CMake options

| Option | Default | Effect |
|---|---|---|
| `RAYLIB_MODE` | `FETCH` | Where raylib comes from: `FETCH` (GitHub, pinned to 5.5), `SYSTEM` (installed package, must be exactly the pinned version; Debian doesn't package raylib), `LOCAL` (pre-staged source in `build/_deps/raylib-src`, used for offline builds such as Flatpak) |
| `RAYLIB_SHARED` | `OFF` | Link raylib as a shared library instead of statically |
| `ENABLE_CPACK` | `ON` | Generate the CPack configuration (TGZ, DEB, RPM, ZIP) |

## Runtime dependencies

With the default configuration, raylib (and the GLFW copy inside it) is linked statically.
What the binary still needs from the host depends on the build distro.

**Declared (`DT_NEEDED`)**, as seen by `readelf -d` and `ldd`:

| Built on | `DT_NEEDED` |
|---|---|
| openSUSE Tumbleweed | `libm.so.6`, `libOpenGL.so.0`, `libGLX.so.0`, `libc.so.6` |
| Debian bookworm | `libm.so.6`, `libc.so.6` (Debian GCC links with `--as-needed`) |

**Not declared (`dlopen()`)**: after `main()` starts, GLFW loads `libX11.so.6` and `libGLX.so.0` itself, and optionally Xcursor, Xi, Xinerama and Xrandr.
`ldd`, RPM `find-requires` and `dpkg-shlibdeps` can't see these libraries, so the packaging recipes declare them by hand.
To list them, run the binary under a display:

```bash
LD_DEBUG=files ./build/bin/ocio 2>&1 | grep 'dynamically loaded by'
```

**Packages to install**, for example in a vanilla container (see the [walkthrough](../docs/container-packaging.md#walkthrough-build-fail-fix-package-install)):

| Distro | Required | Optional (GLFW degrades gracefully without them) |
|---|---|---|
| Debian bookworm | `libglx0`, `libx11-6` (both `dlopen()`ed) | `libxcursor1`, `libxi6`, `libxinerama1`, `libxrandr2` |
| openSUSE Tumbleweed | `libglvnd` (provides `libOpenGL.so.0` and `libGLX.so.0`, and requires `libX11-6`) | not verified yet |

The package managers pull in the rest of the GL stack (on Debian, for example, `libglx-mesa0` and `libgl1-mesa-dri`).
The packaging recipes encode the same facts. If you change this table, update them too:
- [`packaging/deb/control`](../packaging/deb/control): `Depends` and `Recommends` of the hand-written DEB
- `CPACK_DEBIAN_PACKAGE_DEPENDS` in [`CMakeLists.txt`](../CMakeLists.txt): the CPack DEB
- [`packaging/rpm/ocio.spec`](../packaging/rpm/ocio.spec): RPM requirements come from `DT_NEEDED` automatically

There is also an implicit runtime requirement: a display server (X11 or Wayland) and, for hardware acceleration, `/dev/dri`.

With `-DRAYLIB_SHARED=ON` or `-DRAYLIB_MODE=SYSTEM`, `ocio` also needs `libraylib.so` at runtime, from the host or from the package bundle.

## License

[MIT](../LICENSE)
