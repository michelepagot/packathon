# Debian Packaging (`packaging/deb`)

This directory contains the recipes, staging skeletons, and metadata necessary to package the **Ocio** application into a Debian package (`.deb`).

## Directory Structure

```text
packaging/deb/
├── README.md               # This documentation file
├── build-deb.sh            # Main packaging script supporting multiple build modes
├── skeleton/               # Filesystem skeleton for low-level (frugal) packaging
│   ├── DEBIAN/
│   │   └── control         # Control file template with variable placeholders
│   └── usr/
│       ├── bin/            # Destination for the compiled executable (ocio)
│       └── share/
│           ├── applications/ # Destination for the .desktop entry
│           ├── icons/      # Destination for hicolor application icons
│           └── metainfo/   # Destination for AppStream metadata
└── debian/                 # Canonical Debian source packaging directory (debhelper)
    ├── changelog           # Package versioning, distribution target, and history
    ├── control             # Source and binary package metadata and build dependencies
    ├── rules               # Executable build recipe driving debhelper (dh) with CMake
    └── source/
        └── format          # Debian source package format (3.0 native)
```

---

## Files and Folders

### 1. `build-deb.sh`

The primary build script for assembling Debian packages. It is designed to run in a Debian environment (such as the `ghcr.io/michelepagot/packathon/debian-builder` container or a native Debian installation) and supports three distinct packaging paradigms:

- **`--mode frugal` (default)**:
  A transparent, low-level binary packaging workflow that bypasses heavy packaging frameworks. It manually executes each atomic step:
  1. Compiles the binary with CMake if not already present.
  2. Copies the layout from `skeleton/` and populates the payload files.
  3. Uses `dpkg-shlibdeps` to scan ELF dynamic library dependencies (`DT_NEEDED`) and resolve exact Debian package dependencies into `${shlibs:Depends}`.
  4. Computes file checksums (`md5sum`) into `DEBIAN/md5sums` and calculates `Installed-Size`.
  5. Substitutes placeholders in `DEBIAN/control`.
  6. Assembles the final `.deb` archive using `dpkg-deb --build`.

- **`--mode cmake`**:
  Leverages CMake's integrated packaging generator, **CPack** (`cpack -G DEB`), driven by configuration in the root `CMakeLists.txt`. CPack handles staging, runs `dpkg-shlibdeps`, generates control metadata, and produces the `.deb` package.

- **`--mode debhelper`**:
  The canonical Debian source packaging workflow. It invokes `dpkg-buildpackage` against the files in `debian/` (`debian/rules` running `dh $@ --buildsystem=cmake`). It handles automated configuration, compilation, staging, dependency generation, and packaging conforming to Debian Policy.

**Useful Options:**
- `--no-clean`: Retains intermediate build and staging directories for post-build inspection (`build-deb-staging/` for frugal mode, `_CPack_Packages/` for cmake mode, `debian/` and `obj-*/` for debhelper mode).
- `-p`, `--pause`: Pauses before executing each command, allowing step-by-step inspection and live demonstration.

---

### 2. `skeleton/`

Used by the **`frugal`** packaging mode as a template for staging files:

- **`DEBIAN/`**:
  Contains packaging metadata that is stored inside the control archive (`control.tar.gz`) of the `.deb` file rather than installed on the target filesystem.
  - `control`: A template defining package identity (`Package: ocio`), section, architecture, maintainer, and description, along with substitution variables (`${version}`, `${arch}`, `${installed:Size}`, `${shlibs:Depends}`).

- **`usr/`**:
  Represents the standard Linux Filesystem Hierarchy Standard (FHS) tree to be installed under `/usr` on the target system:
  - `usr/bin/`: Holds the compiled `ocio` binary.
  - `usr/share/applications/`: Holds `ocio.desktop` (XDG application menu launcher).
  - `usr/share/icons/`: Holds hicolor icons (`256x256` PNG and scalable SVG).
  - `usr/share/metainfo/`: Holds `org.packathon.ocio.metainfo.xml` (AppStream software center metadata).

---

### 3. `debian/`

The canonical Debian packaging directory used by the **`debhelper`** mode and standard Debian tooling:

- **`control`**:
  Defines Debian source metadata, build dependencies (`Build-Depends: debhelper-compat (= 13), cmake, ...`), standards compliance (`Standards-Version: 4.6.2`), and binary package dependencies using the `${shlibs:Depends}` and `${misc:Depends}` substitution variables.

- **`rules`**:
  An executable Makefile that instructs the `dh` sequencer how to build the package using the CMake buildsystem (`dh $@ --buildsystem=cmake`). Contains overrides (`override_dh_auto_configure`, `override_dh_auto_install`) to configure the build and ensure only the application binary and assets are packaged (omitting bundled static Raylib libraries).

- **`changelog`**:
  Maintains the release and version history following standard Debian format (`ocio (0.1.0-1) unstable; urgency=medium`). Parsed by `dpkg-parsechangelog` to determine the package version.

- **`source/format`**:
  Declares the Debian source package format. Configured as `3.0 (native)`.

---

## How to Build

To build the package using the provided container environment:

```bash
# Default frugal workflow (low-level atomic steps)
podman run --rm -v "$PWD:/src:Z" -w /src ghcr.io/michelepagot/packathon/debian-builder packaging/deb/build-deb.sh

# CPack DEB generator workflow
podman run --rm -v "$PWD:/src:Z" -w /src ghcr.io/michelepagot/packathon/debian-builder packaging/deb/build-deb.sh --mode cmake

# Canonical debhelper source package workflow
podman run --rm -v "$PWD:/src:Z" -w /src ghcr.io/michelepagot/packathon/debian-builder packaging/deb/build-deb.sh --mode debhelper
```

All built `.deb` packages are output to `dist/`.
