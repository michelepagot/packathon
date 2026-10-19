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
  - Top-level `paths-ignore` excludes unrelated documentation (`docs/**`), other workflow files, `.gitignore`, `LICENSE`, `*.png`, and `.devcontainer/**` so the workflow does not trigger at all for those changes.
- **Path Filtering (shared `filter` job)**:
  - A dedicated `filter` job runs `dorny/paths-filter@v3` once and exposes outputs (`app`, `rpm`, `containers`, `meta`, `deb`, `appimage`, `flatpak`) to all downstream jobs via `needs.filter.outputs.*`.
  - On non-PR events (push, `workflow_dispatch`) all outputs are forced to `true` so no job is ever skipped.
  - Each build job has a **job-level `if:`** condition that references the shared filter outputs. If none of the job's relevant paths changed, the entire job is skipped (not just a single step). This prevents wasted runner time on PRs that only touch, e.g., `packaging/containers/**` (which should only run the openSUSE and Debian container jobs, not the Flatpak, Host, Windows, or macOS jobs).
- **Jobs**:
  - `filter`: Shared path-detection gate. Runs `dorny/paths-filter@v3` once; all other jobs depend on it.
  - `test-opensuse-containers-and-modes`: Skipped unless `app`, `rpm`, `containers`, or `meta` changed. Sets up openSUSE builder image using `./packaging/containers/setup-builder.sh opensuse` (pulling pre-built GHCR image with automatic local `podman build` fallback; `--rebuild` only when `containers` changed). Exercises build modes (`FETCH`, `SHARED`) and verifies CPack RPM and canonical rpmbuild in vanilla Tumbleweed.
  - `test-debian-containers-and-modes`: Skipped unless `app`, `deb`, `appimage`, `flatpak`, `containers`, or `meta` changed. Sets up Debian builder image using `./packaging/containers/setup-builder.sh debian`. Exercises build modes (`FETCH`, `LOCAL`), packaging modes (debhelper, frugal), AppImage, and Flatpak, verifying each in vanilla Debian Bookworm.
  - `test-flatpak`: Skipped unless `app` or `flatpak` changed. Builds the Flatpak manifest with `flatpak-builder` inside a container and exports an OSTree repository, verifying Flatpak buildability with cache reuse (`.flatpak-builder`).
  - `test-host-sanity`: Skipped unless `app` changed. Compiles `ocio` on Ubuntu host (`Release` configuration) using default GCC compiler, verifies CLI flags (`--help`, `--version`).
  - `test-windows`: Skipped unless `app` changed. Builds `ocio` with MSVC in parallel (`--parallel`), runs CLI smoke tests.
  - `test-macos`: Skipped unless `app` changed. Builds `ocio` with Clang on Apple Silicon (`macos-14`) in parallel (`--parallel`), runs CLI smoke tests.

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

Maintains and publishes the official developer/builder and demo container images to GHCR:
- `ghcr.io/michelepagot/packathon/opensuse-builder:latest`
- `ghcr.io/michelepagot/packathon/debian-builder:latest`
- `ghcr.io/michelepagot/packathon/opensuse-demo:latest`
- `ghcr.io/michelepagot/packathon/debian-demo:latest`

- **Triggers**: Changes to `packaging/containers/**` pushed to `main`, tag pushes (`v*`), weekly cron (Monday 04:00 UTC), or manual trigger via `workflow_dispatch`.
- **Concurrency**: `concurrency: group: containers-${{ github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }}`.
- **Optimization**: Uses Docker Buildx with layer caching (`cache-from` / `cache-to`) to minimize rebuild times.
- **Known limitation**: Both the demo (`vanilla-demo`) and builder (`builder`) targets live in the same Containerfile. Any change to the file triggers all 8 matrix jobs (4 images x 2 arches), even if only the builder stage changed. Splitting into per-target Containerfiles would allow finer-grained path filtering.

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
