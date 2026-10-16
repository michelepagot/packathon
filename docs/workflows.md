# GitHub Workflows & Automation

This document details the GitHub Actions workflows configured in [`.github/workflows/`](../.github/workflows/) for continuous integration, multi-platform artifact packaging, container image publishing, slide coherence linting, and GitHub Pages deployments.

---

## Workflow Overview

| Workflow | File | Triggers | Primary Purpose |
|---|---|---|---|
| **Continuous Integration** | [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) | PRs & pushes to `main` (code/build paths) | Multi-OS build suite (openSUSE, Debian, Ubuntu host sanity, macOS, Windows), CLI smoke tests, CPack package generation, Flatpak build test. |
| **Releases** | [`.github/workflows/release.yml`](../.github/workflows/release.yml) | Git tags matching `v*`, manual dispatch | Builds production artifacts for all platforms, verifies native packages in clean vanilla containers, builds versioned Flatpak bundle, attaches all assets to the GitHub Release. |
| **Container Builders** | [`.github/workflows/containers.yml`](../.github/workflows/containers.yml) | Pushes to `main` affecting `packaging/containers/**`, manual dispatch | Builds and publishes multi-distribution builder images (`opensuse-builder`, `debian-builder`) to GitHub Container Registry (GHCR). |
| **GitHub Pages** | [`.github/workflows/pages.yml`](../.github/workflows/pages.yml) | Pushes to `main` (`docs/pages/**`, `packaging/flatpak/**`), published releases, manual dispatch | Deploys Reveal.js presentation slides and hosts the live Flatpak OSTree repository (`master` development channel on push, `stable` on release) with atomic deployment safety. |
| **Slide Linting** | [`.github/workflows/slides.yml`](../.github/workflows/slides.yml) | PRs & pushes affecting `docs/pages/slides/**` | Runs `lint-slides.py` to guarantee strict 1-to-1 structural coherence between English and Italian slides. |

---

## Workflow Details

### 1. Continuous Integration (`ci.yml`)

Runs on every pull request and push to the `main` branch when source code, packaging recipes, or build configurations change.

- **Concurrency & Resource Management**:
  - Uses `concurrency: group: ci-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }}` to terminate superseded runs on pull requests while allowing branch push runs to finish in order.
  - Path filters ignore unrelated documentation (`docs/**`), demo scripts, devcontainer definitions, and talk slides.
- **Jobs**:
  - `test-opensuse-containers-and-modes`: Sets up openSUSE builder image using `./packaging/containers/setup-builder.sh opensuse` (pulling pre-built GHCR image with automatic local `podman build` fallback). Exercises build modes (`FETCH`, `SYSTEM_STUB`, `SYSTEM_PKG`) and verifies CPack RPM and source/binary tarballs.
  - `test-debian-containers-and-modes`: Sets up Debian builder image using `./packaging/containers/setup-builder.sh debian`. Exercises build modes (`FETCH`, `SYSTEM_STUB`, `SYSTEM_PKG`) and verifies CPack DEB and source/binary tarballs.
  - `test-flatpak`: Builds the Flatpak manifest with `flatpak-builder` inside a container and exports an OSTree repository, verifying Flatpak buildability with cache reuse (`.flatpak-builder`).
  - `test-host-sanity`: Compiles `ocio` on Ubuntu host (`Release` configuration) using default GCC compiler, verifies CLI flags (`--help`, `--version`, invalid arguments).
  - `test-windows`: Builds `ocio` with MSVC in parallel (`--parallel`), runs CLI smoke tests.
  - `test-macos`: Builds `ocio` with Clang on Apple Silicon (`macos-latest`) in parallel (`--parallel`), runs CLI smoke tests.

### 2. Releases (`release.yml`)

Triggered automatically upon pushing a release tag (e.g., `git tag v0.1.0 && git push --tags`) or via manual dispatch.

- **Packaging Pipeline**:
  - Builds the canonical source tarball, raw Linux binary tarballs, openSUSE `.rpm`, and Debian `.deb`.
  - Builds native Windows `.zip` and macOS ARM64 `.tar.gz` packages using parallel CMake builds.
  - Builds the standalone AppImage via `appimagetool` in an isolated environment.
  - Builds the standalone Flatpak single-file bundle (`ocio-${{ github.ref_name }}.flatpak`) pinned to the release version and the `stable` OSTree branch channel.
- **Pragmatic Quality Gates (Vanilla Verification)**:
  - Spins up pristine vanilla distro containers (`opensuse/tumbleweed` and `debian:bookworm-slim`) with zero pre-installed developer tools.
  - Installs the generated `.rpm` and `.deb` packages using native package managers (`zypper --non-interactive install`, `apt-get install -y`).
  - Verifies that all required shared libraries and runtime dependencies resolve correctly and that `ocio --version` succeeds.
- **GitHub Release Publishing**:
  - Automatically collects all build artifacts, generates SHA-256 checksums, and attaches them to the tagged GitHub Release.

### 3. Container Builders (`containers.yml`)

Maintains and publishes the official developer/builder container images to GHCR:
- `ghcr.io/michelepagot/packathon/opensuse-builder:latest`
- `ghcr.io/michelepagot/packathon/debian-builder:latest`

- **Triggers**: Changes to `packaging/containers/**` pushed to `main`, or manual trigger via `workflow_dispatch`.
- **Concurrency**: `concurrency: group: containers-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }}`.
- **Optimization**: Uses Podman with layer caching (`cache-from` / `cache-to`) to minimize rebuild times.

### 4. GitHub Pages & Flatpak OSTree (`pages.yml`)

Unified deployment workflow for the project's web presence and Flatpak repository on GitHub Pages.

- **Atomic Staging & Safe Isolation**:
  - Stages Reveal.js presentation slides and documentation pages (`docs/pages/.`) into `public/`, copying dotfiles (such as `.nojekyll`).
  - Builds the Flatpak OSTree repository in an isolated working directory (`ostree-repo`) with branch caching across commits (`ostree-repo-${{ runner.os }}-...`).
  - Only upon successful build and prune is `ostree-repo` synced into `public/repo`. If the Flatpak build encounters an issue, `public/repo` is not corrupted, and presentation slides deploy uninterrupted.
- **Channel Strategy**:
  - **`master` branch**: Built on pushes to `main`, representing rolling nightly builds.
  - **`stable` branch**: Built on release publications, pinned to the release tag.
- **Fail-Safe Slide Protection**:
  - Presentation slides and web documentation are strictly prioritized. The workflow enforces strict file presence checks (`test -s public/index.html`, `test -s public/cheatsheet.html`, `test -s public/slides/slides-en.md`, `test -s public/slides/slides-it.md`, `test -f public/.nojekyll`).
  - OSTree generation steps run with `continue-on-error: true` so any potential Flatpak packaging issue will never prevent conference slides from being deployed.
- **Deployment Safety**:
  - Uses GitHub Pages deployment concurrency (`group: pages`, `cancel-in-progress: false`) to ensure atomic, non-overlapping updates to the live site.

### 5. Slide Linting (`slides.yml`)

Guarantees alignment between the English and Italian presentations.

- **Trigger**: Pull requests and pushes modifying `docs/pages/slides/**`.
- **Concurrency**: `concurrency: group: slides-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }}`.
- **Validation**: Executes `docs/pages/slides/lint-slides.py` to verify slide count, section headers, code snippet blocks, and speaker note parity between `slides-en.md` and `slides-it.md`.
