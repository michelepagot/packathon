# Packathon

**Packathon** is the companion repository for the talk
***Packathon: Packaging & Distributing Software on Linux*** (Linux Day Trieste 2026).

Slides: **https://michelepagot.github.io/packathon/**

> Getting a compiled binary onto a stranger's Linux machine is one question with many answers,
> and every answer is a choice about **who owns the dependencies**.

The repository takes one small application and packages it in several formats.
Every artifact is built from the same source and tested in clean containers, so you can compare the formats side by side.
The live demos from the talk can be reproduced from this repository.

## The excuse: `ocio`

The app being packaged is [`ocio`](src/README.md), an eye that follows the mouse cursor.
It took 15 minutes to vibecode, and it will change your life.

It was chosen on purpose: **maximally simple source, maximally realistic runtime footprint.**
It is one C file with no business logic, but at runtime it needs OpenGL, a display server and `/dev/dri`, just like a real desktop application.

My first plan was to mail it to you on a 3.5" floppy disk. The rest of this repository covers everything else.

## The routes

| Route | Format | Who provides the dependencies | Recipe | Live demo |
|---|---|---|---|---|
| None | Raw binary / tarball | The developer (static) + whatever is on the host | CPack `TGZ` | - |
| 1. Delegate to the distro | RPM | The distribution (`libsolv`) | [`packaging/rpm/`](packaging/rpm/) (`rpmbuild` + `ocio.spec`) | [`demo-rpm.sh`](packaging/demo/demo-rpm.sh) |
| 1. Delegate to the distro | DEB | The distribution (APT) | [`packaging/deb/`](packaging/deb/) (`dpkg-deb` + `dpkg-shlibdeps`) | [`demo-deb.sh`](packaging/demo/demo-deb.sh) |
| 2. Self-mounting bundle | AppImage | The bundle, except glibc and the GL stack | [`packaging/appimage/`](packaging/appimage/) (`appimagetool`) | [`demo-appimage.sh`](packaging/demo/demo-appimage.sh) |
| 3. Desktop sandbox | Flatpak | A shared runtime (`org.freedesktop.Platform//25.08`) | [`packaging/flatpak/`](packaging/flatpak/) (`flatpak-builder`) | [`demo-flatpak.sh`](packaging/demo/demo-flatpak.sh) |

CPack can also produce TGZ, DEB and RPM from [`CMakeLists.txt`](CMakeLists.txt). This is the quick, generic path. The recipes above are the minimal, hand-written versions that the talk dissects.

For more detail, see:
- [Packaging Guide](docs/packaging-guide.md): how each format works and what it costs
- [Container-Based Packaging & Testing](docs/container-packaging.md): builder and runtime images, display pass-through, vanilla-container verification

## Quick start

To try `ocio` without building anything, pull the published runtime image:

```bash
podman run --rm ghcr.io/michelepagot/packathon/opensuse:latest --version   # or .../debian:latest
```

To open the GUI from the container, see [Running the GUI](docs/container-packaging.md) for the display and `/dev/dri` pass-through flags.

Artifacts are written to `dist/`. The CPack builds and `build-deb.sh` run inside containers and need only `podman`. The other recipes use host tools: `rpmbuild` and a C toolchain for the RPM, a C toolchain for the AppImage, and `flatpak-builder` for the Flatpak.

```bash
# Native packages via CPack, in the matching builder container
podman build --target builder -t localhost/packathon-opensuse:builder -f packaging/containers/Containerfile.opensuse .
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-opensuse:builder   # .rpm + .tar.gz

podman build --target builder -t localhost/packathon-debian:builder -f packaging/containers/Containerfile.debian .
podman run --rm -v "$PWD:/src:Z" -w /src localhost/packathon-debian:builder     # .deb + .tar.gz

# The hand-written recipes
./packaging/rpm/build-rpm.sh
./packaging/deb/build-deb.sh                # runs in the Debian builder container on non-Debian hosts
./packaging/appimage/build-appimage.sh
./packaging/flatpak/build-flatpak.sh

# Install and inspect each artifact in a pristine container
./packaging/demo/demo-rpm.sh                # likewise demo-deb.sh, demo-appimage.sh, demo-flatpak.sh
```

To build and run `ocio` directly on your machine, see [`src/README.md`](src/README.md).

The [devcontainer](.devcontainer/) provides the same environment in a browser terminal (ttyd on port 7681). This is the setup used for the live demo.

## Releases and CI

Every tagged release on GitHub publishes the full set of artifacts: Linux tarball, `.rpm`, `.deb`, AppImage and Flatpak, plus a Windows `.zip` and a macOS ARM64 tarball.

| Workflow | What it does |
|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | Builds, checks the CLI flags and runs CPack on every PR and push to `main` |
| [`release.yml`](.github/workflows/release.yml) | On `v*` tags: builds every artifact, installs each Linux package in a vanilla container, attaches them to the release |
| [`containers.yml`](.github/workflows/containers.yml) | Publishes the openSUSE and Debian runtime images to `ghcr.io/michelepagot/packathon/{opensuse,debian}` (builder images are local only) |
| [`pages.yml`](.github/workflows/pages.yml) | Deploys the slides to GitHub Pages |

## Repository map

```
src/                  the ocio application (see src/README.md)
packaging/            one directory per format, plus containers/ and demo/
docs/                 packaging and container guides
docs/pages/slides/    the talk (Reveal.js, IT and EN)
.devcontainer/        browser-based live-demo environment
```

## Out of scope

The talk does not cover Snap, Nix, Arch/AUR, Windows MSI/MSIX or macOS notarization.
The AppImage is built on a recent distro, so it inherits that distro's glibc baseline and is less portable than the format promises. Building on an older LTS baseline is on the roadmap.

## License

[MIT](LICENSE)
