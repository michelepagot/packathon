# Packathon

### Software Packaging and Distribution on Linux

<p class="text-muted" style="margin-top: 30px;">Linux Day Trieste 2026</p>

Note:
Leave ocio running live on a secondary screen or split window.
Opening gag:
"The organizers invited me here today to talk about packaging and release engineering. But let's be honest: I'm really here to show you my 15-minute vibecoded app that will change your life forever."
Move the mouse, show the eye tracking the cursor, press V to toggle version (Ocio v0.1.0).
"Now that you've seen it, I know you all want it. But I don't have a server or a distribution pipeline. So I decided to distribute it the classic way."
Pull the physical 3.5" floppy disk out of your backpack:
"If you leave me your postal address and a stamp after the talk, I will mail you a copy."
The pivot to reality:
What if I upload this raw compiled binary to a web server and tell 50 strangers to download and execute it?
It fails immediately on disparate machines: mismatched glibc, missing DT_NEEDED dynamic links (libGL.so, libX11.so), absent display server socket, or permissions issues.
The guinea pig: why this app on purpose:
Source is deliberately trivial: one main.c, ~280 lines of clean C99, zero business logic: nothing competes with packaging for attention.
Runtime footprint is maximally realistic: requires OpenGL hardware acceleration via DRI, an active display server (X11 / Wayland), and shared memory IPC (MIT-SHM).
"Maximally simple source, maximally realistic runtime footprint."

--

## Slides
<!-- .slide: class="text-center" -->

<div class="center-card">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=240x240&amp;data=https://michelepagot.github.io/packathon/" alt="Slide QR Code" style="border-radius: 12px; border: 3px solid rgba(255,255,255,0.4);" />
  <p><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
</div>

Note:
Pause to allow the audience to scan the QR code and follow along live on phones or laptops.

--

## Speaker

* **Michele Pagot**
* **SUSE**: Quality Engineering (QE)
* GitHub: [`@michelepagot`](https://github.com/michelepagot) · [`@mpagot`](https://github.com/mpagot)

Note:
Brief speaker introduction.

--

## Disclaimer

* Not a package maintainer by trade.
* I work in QE...

Note:
"I am not a package maintainer by trade. I work at the receiving end of release pipelines: testing, validating, and auditing artifacts on complete systems. This talk was born as a systems engineering inquiry to understand the upstream packaging constraints before software reaches our test benches."

--

## Agenda

1. **Intro**: Census, Perspectives, "Dependencies" primer
2. **Formats**: RPM, DEB, AppImage, Flatpak
3. **Release &amp; Distribution**
4. **Conclusion**

Note:
Concise overview of the talk progression.

---

## Census

1. Who uses Linux daily? <!-- .element: class="fragment" -->
2. Who installs software exclusively via official distro repos? <!-- .element: class="fragment" --> <br><small class="text-muted">(APT, Zypper, DNF, Pacman, AUR... Emerge, Slackpkg, urpmi)</small>
3. Who uses universal formats: Flatpak, AppImage, or Snap? <!-- .element: class="fragment" -->
4. <!-- .element: class="fragment" --> `curl | sh`
5. Who regularly compiles from source? <!-- .element: class="fragment" --> <br><small class="text-muted">(<code>git clone &amp;&amp; cmake &amp;&amp; make &amp;&amp; sudo make install</code>)</small>

Note:
Go through the 5 questions looking at the room:
1. 100% hands up.
2. Official repos: model citizens with blind trust in maintainers.
3. Flatpak/AppImage: upstream freshness vs surrendering to dependency hell.
4. curl | sh: 2 AM pragmatism vs tossing supply-chain security out the window.
5. Compilation: /usr/local purists.
Takeaway:
"Look around: in this room there is no single way software is received on Linux. Everyone operates under a different trust model, different update expectations, and different operational trade-offs."

--

## Perspectives

* <!-- .element: class="fragment" --> User
* <!-- .element: class="fragment" --> Developer
* <!-- .element: class="fragment" --> Maintainer

Note:
Present the three perspectives one by one:

1. The User (common starting point: simply wants the application running):
- Internal needs diverge: users demanding rock-solid multi-year immutability (servers, production workstations) vs. day-one upstream feature chasers.
- We want installation in as few steps as possible, and seamless updates over time.
- Some prioritize instant startup and minimal memory or disk footprint, while others do not care about disk space as long as there is zero configuration.
- Physical heterogeneity: everyone has different hardware and graphics cards, and when switching PCs or moving between distributions, we expect the exact same application to work seamlessly.

2. The Developer (focusing on public distribution for the broadest reach, not bespoke single-client builds):
- Goal is to reach the widest possible audience.
- Intimately knows their application code, internal logic, and direct dependencies.
- Does not know the quirks of twenty different Linux distributions, and lacks the hardware lab to test every permutation of kernel, drivers, and libraries.
- Operates under complete power asymmetry: full control over their own source code, but zero control over the user host operating system. The developer simply wants what they compiled and verified to run reliably on the end-user machine.

3. The Distro Maintainer / OS Owner:
- Knows the specific application less than its creator, and understands the application build system far less than the upstream developer.
- Intimately knows the operating system as an interconnected whole and all the other 30,000 co-distributed packages.
- Primary goal is ensuring that distributed software launches, runs, and never breaks the system: ABI compatibility, filesystem collisions in /usr, and security patching in shared libraries (a CVE in OpenSSL must be patched once across the entire OS).
- Diverging philosophies and needs: distros prioritizing vast software catalogs vs. those focusing on a smaller, tightly curated set of packages; rolling release models (Tumbleweed, Arch) vs. multi-year LTS stability (SLES, Debian, RHEL).

Interactive stage pause:
"Before we jump into HOW, let us pause and reflect on WHY. Look at this picture: do you recognize yourselves in these tensions? Is there a fundamental operational friction that one of these actors faces daily that we missed?"

Bridge to the rest of the talk:
"Nobody is right or wrong: each actor invests time, energy, and resources into completely legitimate concerns. The packaging formats we explore today did not arise from rivalry: they are different engineering attempts to arbitrate this trilemma. Now let us look at the HOW: what happens when we try to distribute our binary."

--

## Dependencies

> *"It works on my machine."*

```text
/ocio: error while loading shared libraries:
libOpenGL.so.0:
cannot open shared object file:
No such file or directory
```
<!-- .element: class="fragment" -->

<div class="center-card fragment">
  <img src="image/rabbit_hole_2_vi.png" alt="Down the rabbit hole" style="max-height: 360px; border: none; box-shadow: none;" />
</div>

Note:
Ask the audience the exit code: 127.

Test command in minimal container:
$ podman run --rm -v ./build/bin/ocio:/ocio:ro,Z registry.opensuse.org/opensuse/tumbleweed:latest /ocio

Reveal the rabbit hole fragment:
"Welcome down the dependency rabbit hole: you compiled cleanly, but runtime immediately fails."

Stage handoff:
"We built the binary, put it on a USB drive or downloaded it from GitHub, and ran it on a clean system. Immediate runtime failure.
Who terminated the process? Did the application crash? Did the kernel abort?
Let us look at what actually happens under the hood when Linux launches a binary."

--

## Launch

1. **Shell**: `$PATH` lookup &rarr; `/usr/bin/ocio` <small>(`command -v ocio`)</small>
2. **Kernel**: `execve()` &rarr; `PT_INTERP` &rarr; `ld.so`
3. **ld.so**: `DT_NEEDED` &rarr; `/lib64/libOpenGL.so.0` found
4. `main()`

Note:
What actually happens at launch:
"When an executable is launched, execution does not start in main(). The operating system's only role is to load the binary into memory and pass control to userspace helper software: the dynamic linker (ld.so). The dynamic linker is responsible for loading all required shared libraries before handing control over to our C code. If even a single library is missing, ld.so terminates the process immediately with exit code 127. The kernel did not fail, and our code did not crash - it never had the chance to execute a single instruction."

Under the hood:
1. Shell: locates `/usr/bin/ocio` via `$PATH` (`command -v ocio`).
2. Kernel: `execve()` maps the ELF and reads `PT_INTERP` (the string `/lib64/ld-linux-x86-64.so.2` from the `.interp` section). The kernel sets up the initial stack, writes the Auxiliary Vector (auxv: AT_PHDR, AT_ENTRY, AT_BASE), and points RIP directly to `ld.so`. The kernel succeeded with return code 0!
   (Contrast: if the interpreter path itself does not exist on disk, execve fails immediately in the kernel with ENOENT: "cannot execute: required file not found").
3. Dynamic Linker (`ld.so` in userspace): walks `DT_NEEDED` in strict search order (RPATH -> LD_LIBRARY_PATH -> RUNPATH -> /etc/ld.so.cache -> /lib64). Failing to open `libOpenGL.so.0` after repeated `openat()` attempts, `ld.so` prints the error and invokes syscall `exit_group(127)`.
4. `main()`: never reached.

Showcase command:
`readelf -p .interp ./ocio` (shows the dynamic linker path baked into the ELF)

Bridge to the next slide:
"Let us inspect the binary directly and see what the dynamic linker was looking for."
"The kernel validates the 16-byte e_ident header (\x7fELF). Remember those 16 bytes: we will see in Chapter 5 how AppImage cleverly re-purposes the unused padding at the end of that header."

--

## Following libOpenGL.so.0

```text
$ readelf -d ocio | grep NEEDED
 (NEEDED)  Shared library: [libm.so.6]
 (NEEDED)  Shared library: [libOpenGL.so.0]
 (NEEDED)  Shared library: [libGLX.so.0]
 (NEEDED)  Shared library: [libc.so.6]
```

```text
$ ldd ./ocio
    linux-vdso.so.1 (0x00007ffe315f6000)
    libm.so.6 => /lib64/libm.so.6 (0x00007f9c8f2b0000)
    libOpenGL.so.0 => not found
    libGLX.so.0 => not found
    libc.so.6 => /lib64/libc.so.6 (0x00007f9c8f0b0000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f9c8f3b0000)
```
<!-- .element: class="fragment" -->

Note:
Method to trace an executable's dependencies:
- `readelf -d` → reads the `.dynamic` section: what the binary *asks for* (`DT_NEEDED`), a fixed list written by the linker at compile time.
- `ldd` → runs `ld.so` with `LD_TRACE_LOADED_OBJECTS=1`: what the host *finds*, resolving against system paths + `/etc/ld.so.cache`.

The proof:
- Build machine: libraries installed (full desktop) → everything resolves.
- Test machine: `libOpenGL.so.0` / `libGLX.so.0` → "not found" (not installed).

Detail (only if asked):
- Raylib does not appear in `DT_NEEDED`: statically linked into `.text` in the default build.
- Raylib's GLFW backend requires `libOpenGL.so.0` + `libGLX.so.0` (libglvnd, not legacy libGL).

Showcase commands:
`readelf -d ./ocio | grep NEEDED`
`ldd ./ocio`

Bridge:
"It compiled without warnings and ran perfectly. How can a compiler produce a binary that dies before entering main()?"

--

## Build vs. Runtime

<div class="grid-2">
<div>

### Build-Time
Consumed **once**
<ul class="text-muted" style="font-size: 0.85em;">
<li>Headers &amp; static libs</li>
<li>Compiler &amp; tools</li>
</ul>

</div>
<div>

### Runtime
Required **every run**
<ul class="text-muted" style="font-size: 0.85em;">
<li>Dynamic `.so` &amp; `glibc`</li>
<li>Display &amp; GPU nodes</li>
</ul>

</div>
</div>

<p class="fragment text-info" style="margin-top: 35px;">
<em>In C, a dynamic binary is an incomplete contract with the host OS.</em>
</p>

Note:
Opening:
"Why did the binary compile cleanly if it cannot run?"

The contract (one line per slide column):
- **Build-time** = once: only headers (.h) for signatures and symbol stubs for relocation offsets. Never checks the .so exist on the host.
- **Runtime** = every run: concrete .so, an active display server (X11/Wayland), and GPU drivers.

Why not `gcc -static` like Go/Rust? (only if time allows)
- Real experiment (Variant 7): `ld` refuses immediately — `attempted static link of dynamic object '/usr/lib64/libOpenGL.so'`.
- `libglvnd` ships no static `.a` archives.
- DRI GPU drivers (`iris_dri.so`, `nvidia.so`) load at runtime via `dlopen()`: cannot be static.
- Static glibc breaks NSS plugins (`/etc/nsswitch.conf`).

Showcase command:
`gmake -C build-07-attempt-static 2>&1 | grep "attempted static link"`

Bridge to Formats:
"The binary needs these libraries, but the host does not have them. Every format bridges the gap differently: let us get into packaging."

---

## Formats

| Target | Mechanism |
|---|---|
| **Standalone Tarball** | Compressed archive (`.tar.gz`) with assets and `.desktop` |
| **RPM (`.rpm`)** | CPIO payload for Fedora/openSUSE/RHEL |
| **Debian (`.deb`)** | Standard `ar` archive via CPack |
| **AppImage** | Single executable with SquashFS mounted via FUSE |
| **Flatpak** | Bubblewrap sandbox on Freedesktop runtime |

Note:
The spectrum of formats explored: from simple unmanaged tarballs to full distro packages, self-mounting bundles, and desktop sandboxes.
Transition to Route 1: we will focus in depth on the Big 4 Desktop Formats (RPM, DEB, AppImage, Flatpak), starting with delegating to the distro.

---

## RPM: Native Distro Standard

<div class="grid-2" style="align-items: center; gap: 40px; margin-top: 30px;">
<div style="flex: 0 0 auto;">
  <img src="image/maximum_rpm.png" alt="Maximum RPM book cover" style="max-height: 380px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
</div>
<div style="flex: 1; font-size: 1.05em; line-height: 1.8;">

* *Marc Ewing &amp; Erik Troan* (Red Hat, 1997)
* Archive with dependency metadata
* Enterprise &amp; distro standard (LSB)

</div>
</div>

Note:
Introducing RPM:
- Origin: Started in 1995 by Marc Ewing and Erik Troan (Red Hat); the slide shows 1997, the year of the first stable release (RPM 3.0) that fixed the format.
- Name: "RPM" stands for "Red Hat Package Manager"; it has since become a recursive acronym, "RPM Package Manager".
- Predecessors (only if time allows): RPM grew out of pms (1993, Bogus Linux) and rpp, and briefly coexisted with pm (1995, Rik Faith and Doug Hoffman). It is not a PM -> PPM -> RPM rename: pm is a separate project, and PPM is a different tool (Puppy Linux).
- Implementation: originally written in Perl; the rewrite to C happens already in 1995 (RPM 1.4, November; RPM 2.0, March 1996, is the first version entirely in C).
- Nature: An archive with metadata carrying files and declaring formal dependencies.
- Adoption: The reference standard for openSUSE, SLE, Fedora, and RHEL (LSB standard).
- Daily CLI:
  * Inspect: rpm -qlp (files) and rpm -qp --requires (dependencies)
  * Install with package manager: zypper in or dnf in
   * Audit integrity: rpm -V (detects files altered compared to stored database digests)
  Next we look at what is physically inside the .rpm file on disk.

--

## RPM: Who Uses It
<!-- .slide: data-logos="image/redhat.png image/fedora.png image/centos-stream.png image/rocky-linux.png image/almalinux.png image/oracle-linux.png image/suse-linux-enterprise.png image/opensuse.png image/mageia.png image/openmandriva.png image/pclinuxos.png image/rosa-linux.png image/tizen.png image/sailfish-os.png image/qubes-os.png image/asahi-linux.png image/cbl-mariner.png image/asianux.png image/red-star-os.png" -->

  <p class="text-muted" style="margin-bottom: 10px;">Distributions that use RPM under the hood</p>

* <!-- .element: class="fragment" data-fragments="logos" --><strong>Red Hat</strong>: RHEL, Fedora, CentOS Stream, Rocky, AlmaLinux, Oracle
* <!-- .element: class="fragment" data-fragments="logos" --><strong>SUSE</strong>: SLE, openSUSE (Tumbleweed/Leap)
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Mandriva/Mageia</strong>: Mageia, OpenMandriva, PCLinuxOS, ROSA
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Mobile/embedded</strong>: Tizen, Sailfish OS
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Security/other</strong>: Qubes OS, Asahi Linux, CBL-Mariner, Asianux, Red Star OS
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Non-Linux</strong>: AIX, IBM i, NetWare, ArcaOS

Note:
 The real reach of RPM: it is not just "the Red Hat distro".
 - Red Hat family: RHEL, Fedora, CentOS Stream, Rocky Linux, AlmaLinux, Oracle Linux.
 - SUSE family: SUSE Linux Enterprise (SLE) and openSUSE (Tumbleweed/Leap).
 - Mandriva/Mageia family: Mageia, OpenMandriva, PCLinuxOS, ROSA Linux.
 - Mobile/embedded: Tizen (Samsung), Sailfish OS (Jolla).
 - Security/other: Qubes OS, Asahi Linux (Apple Silicon), CBL-Mariner (Microsoft), Asianux, Red Star OS.
 - Non-Linux: RPM has also been ported to AIX, IBM i, NetWare, and ArcaOS.
 - Front-ends: the same RPM format is queried by different front-ends depending on the distro: zypper (SUSE), dnf/yum (Red Hat/Fedora), urpmi (Mandriva/Mageia), apt-rpm (Ark/ALT).
  - Takeaway: "Same format, many dialects: the .rpm file is identical, only the installer changes."

--

## Inside an RPM: Structure

```text
$ file ocio-0.1.0-1.x86_64.rpm
ocio-0.1.0-1.x86_64.rpm: RPM v3.0 bin i386/x86_64
```
<!-- .element: class="fragment" -->

| Lead | Signature | Header | Payload |
|:---:|:---:|:---:|:---:|
| `magic` | `digests, GPG` | `name, deps, files` | `cpio (zstd)` |
<!-- .element: class="fragment" -->

```text
$ xxd -l 96 -d ocio-0.1.0-1.x86_64.rpm
0000: edab eedb 0300 0000 0001 6f63 696f 2d30  ..........ocio-0
0016: 2e31 2e30 2d31 0000 0000 0000 0000 0000  .1.0-1..........
0032: 0000 0000 0000 0000 0000 0000 0000 0000  ................
0048: 0000 0000 0000 0000 0000 0000 0000 0000  ................
0064: 0000 0000 0000 0000 0000 0000 0001 0005  ................
0080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
```
<!-- .element: class="fragment" style="font-size: 0.48em; line-height: 1.2;" -->

Note:
file identifies the format from the magic bytes (ed ab ee db): "RPM v3.0" is the legacy lead format, still written by modern rpm for compatibility.
xxd reveals the fixed 96-byte Lead:
- Magic bytes ed ab ee db (offsets 0..3)
- Version 3.0 (4..5) and binary package type (6..7)
- Package name "ocio-0.1.0-1" in ASCII (10..22)
- Header-style signature type (00 05 at offset 78)
Anatomy of the file:
- Lead: fixed legacy 96-byte block, mostly a magic number today.
- Signature: digests of header and payload, plus the GPG signature when present (ours has none).
- Header: all the metadata we query with rpm -q (name, version, Requires, Provides, file list with digests).
- Payload: the files themselves, in a cpio archive compressed with zstd (rpm -qp --qf '%{PAYLOADFORMAT} %{PAYLOADCOMPRESSOR}' prints "cpio zstd").

--

## Inside an RPM: Extraction

```text
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | file -
/dev/stdin: ASCII cpio archive (SVR4 with no CRC)
```

```text
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | cpio -idmv
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```
<!-- .element: class="fragment" -->

Note:
What is cpio:
- Unix archive format from the 1970s ("copy in / copy out"), same idea as tar: a flat sequence of (header + file data) records.
- No compression and no index of its own; compression is applied on top (zstd here).
- SVR4 "newc" variant: ASCII headers, magic "070701". The Linux kernel uses the same format for the initramfs.
How to extract it:
- rpm2cpio strips lead, signature and header, decompresses the payload and writes the plain cpio stream to stdout.
- cpio -i extract, -d create directories, -m keep modification times, -v list files.
- Paths are relative (./usr/...): everything lands in the current directory, the system is not touched.
- Shortcut: bsdtar -tf / -xf reads RPM files directly.
- The extracted ./usr/bin/ocio is byte-identical to the built binary.
Key message: extracting is just copying files. No dependency check, no database record, no scripts. Installing is what rpm adds on top: keep this in mind for the next slides.

--

## Inside an RPM: Payload

```text
$ rpm -qlp ocio-0.1.0-1.x86_64.rpm
/usr/bin/ocio
/usr/share/applications/ocio.desktop
/usr/share/icons/hicolor/256x256/apps/ocio.png
/usr/share/icons/hicolor/scalable/apps/ocio.svg
/usr/share/metainfo/org.packathon.ocio.metainfo.xml
```

Note:
rpm can query the file without installing it (-p = package file).
Payload breakdown (directories omitted from listing):
- /usr/bin/ocio: the binary, placed in a system directory already on $PATH.
- .desktop + icons: desktop entry and icons so the desktop environment renders it in menus.
- metainfo XML: AppStream metadata so GUI software centers (GNOME Software, Discover) can present descriptions, categories, and screenshots.

--

## Inside an RPM: Metadata

```text
$ rpm -qp --requires ocio-0.1.0-1.x86_64.rpm
libOpenGL.so.0()(64bit)
libGLX.so.0()(64bit)
libc.so.6(GLIBC_2.34)(64bit)
libm.so.6(GLIBC_2.43)(64bit)
...
```

```text
$ rpm -qp --provides ocio-0.1.0-1.x86_64.rpm
ocio = 0.1.0-1
application(ocio.desktop)
```
<!-- .element: class="fragment" -->

Note:
Header inspection:
- Look at the Requires: libOpenGL.so.0, libGLX.so.0. This is exactly the DT_NEEDED list from our initial crash.
- Nobody wrote these lines manually: rpmbuild's dependency generator inspects the ELF binary (DT_NEEDED + glibc symbol versions) and populates the header automatically.
- Provides: what this package offers to the system (a package name, version, and desktop capability).
- Park GLIBC_2.43: notice this symbol baseline; we will return to it when analyzing delegation trade-offs.

--

## Cooking an RPM

<div style="text-align: center;">
<img src="image/rpm-pipeline.png" alt="RPM build pipeline" style="max-height: 620px; width: auto;" />
</div>

Note:
How native RPMs are built:
- To build a native RPM, you need the source archive in SOURCES/ and the recipe in SPECS/.
- Running `rpmbuild -ba ocio.spec` reads the spec from SPECS/ and the tarball from SOURCES/.
- Executes prep, build, install into a staging root (BUILDROOT), and produces both the binary package (.rpm) and the source package (.src.rpm).
- The package manager does not build software; rpmbuild is the dedicated toolchain.
In the wild: Wezterm generates the spec at runtime via a heredoc inside ci/deploy.sh, with 3 subpackages (wezterm-common, wezterm-gui, wezterm-mux-server) and %if 0%{?suse_version} / %if 0%{?fedora} conditionals for package names. OpenTofu does not use rpmbuild at all: nFPM assembles the .rpm in-process, with no external toolchain.

--

## Inside the .spec: Preamble

* **Preamble**
* **NVR** = `Name` + `Version` + `Release` &rarr; the `.rpm` filename

Note:
The top portion of an RPM .spec file, containing lines like Name, Version, Release, License, Source0, is called the Preamble (or Header section). It precedes the body scriptlets (%prep, %build, %install).
- Each individual key-value pair (Name:, License:, Source0:) is a **tag** (also called a header tag or spec tag). "Directive" is a broader term that covers both these tags and the % build sections, so on this slide "tag" is the precise word for the Preamble lines.
- Name + Version + Release together are called NVR; they define the package's unique filename identity (NAME-VERSION-RELEASE.rpm).
- The Preamble holds static metadata that RPM tools read when querying or building the package: identity, license, upstream URL, source archives.
- Full set of common tags: Name, Version, Release, Summary, License, URL, Source0, BuildRequires, Requires.

--

## Inside the .spec: Build Sections

* **`%prep`** &rarr; **`%build`** &rarr; **`%install`** &rarr; **`%files`**
* The `%` directives are the **build lifecycle**

Note:
The % directives are the Build Sections (Body Sections / Build Phases), as opposed to the Preamble metadata tags.
- They define the build lifecycle: the step-by-step shell scripts and macros that rpmbuild executes to transform raw source into a finished RPM.
- %prep: prepares the build directory, typically unpacking tarballs via %autosetup.
- %build: invokes the buildsystem using distro macros (%cmake and %cmake_build).
- %install: installs build artifacts into a clean temporary root (BUILDROOT) mirroring the system filesystem.
- %files: explicit manifest of files from BUILDROOT to be bundled into the RPM payload. Any unpackaged file causes a build failure.
- %changelog: packaging history (date, maintainer, version, changes).
- Distinction: Preamble = static key-value metadata; Build Sections = the executable build lifecycle.

--

## Spec: Dependencies

* **`BuildRequires`**: Explicit tool &amp; header declarations
* **Clean chroot**: Missing dependency &rarr; build aborts
* **Hermetic graph**: Network disabled (OBS / Koji)

Note:
Build-time dependency management:
- The packager declares BuildRequires explicitly for all compilers, tools, and headers (e.g. gcc, cmake >= 3.16, pkgconfig, raylib-devel, Mesa-libGL-devel).
- In clean build roots (OBS, Koji, or mock), network access is disabled. If a dependency is not in BuildRequires, the build aborts immediately.
- This creates a strictly auditable, reproducible dependency graph for compilation.

--

## Spec: Runtime Dependencies

* **`find-requires`** &rarr; `Requires:`
* **`DT_NEEDED`** &rarr; seen
* **`dlopen()`** &rarr; invisible

Note:
Runtime dependency management:
- Nobody writes Requires: libc.so.6 manually in the spec file.
- After %install, rpmbuild executes the internal find-requires script over all ELF binaries in BUILDROOT.
- The dynamic duality:
  1. Standard linked libraries are listed in DT_NEEDED: find-requires reads them automatically and emits package requirements alongside glibc symbol baselines.
  2. Libraries loaded at runtime via dlopen() and function pointers: invisible to find-requires because they do not appear in the ELF dynamic section.
- The generated contract: find-requires translates the symbols and DT_NEEDED entries into the Requires: lines of the built RPM.

--

## CPack

* CMake built-in packaging: no handwritten `.spec` required

```cmake
set(CPACK_GENERATOR "TGZ;DEB;RPM")
set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)
include(CPack)
```

* Command: `cpack -G RPM`

Note:
The CPack workflow:
- For a developer using CMake, CPack creates RPMs without writing a .spec file by hand.
- Adding a few lines to CMakeLists.txt and running `cpack -G RPM` generates a package.
- Generates spec internally and invokes rpmbuild.
- Standard CMake build retains DT_NEEDED -> find-requires detects libOpenGL.so.0 -> installs & runs out of the box ("it just works!").
In the wild: CPack is the "artisan" path. Production pipelines reach the same .rpm via nFPM (OpenTofu, in-process, no rpmbuild) or via rpmbuild on a generated spec (Wezterm). Same format, two access routes.

--

## The --as-needed Trap

* <!-- .element: class="fragment" --> `%cmake` &rarr; `-Wl,--as-needed`
* <!-- .element: class="fragment" --> `dlopen()` GL dispatch &rarr; pruned from `DT_NEEDED`
* <!-- .element: class="fragment" --> 1 pkg (904 KiB) not 36 (53 MiB) &rarr; runtime crash

```rpm
# In ocio.spec: bridging the dlopen() blind spot
Requires: libOpenGL.so.0()(64bit)
Requires: libGLX.so.0()(64bit)
```
<!-- .element: class="fragment" -->

Note:
The trap for the spec author:
- With CPack, everything "just worked".
- But when an author writes a native ocio.spec using standard distro macros like %cmake, the distro toolchain injects hardening flags, notably -Wl,--as-needed.
- Because Raylib resolves OpenGL calls dynamically via function pointers and dlopen(), GNU ld with --as-needed considers the dynamic link unused and strips libOpenGL.so.0 and libGLX.so.0 from DT_NEEDED.
- find-requires scans only DT_NEEDED: it detects no graphics dependencies and emits only libc and libm.
- The resulting RPM builds cleanly, but Zypper installs only 1 package (904 KiB, no graphics deps) instead of 36 (53 MiB). The program starts, but crashes when initializing the window!
- The solution: the author must manually bridge the dlopen() blind spot by declaring virtual capabilities in ocio.spec with Requires: (the code block above).
In the wild: the trap is specific to C with dynamic libraries. Go (CGO off) and Rust (static) binaries have no GL stack in DT_NEEDED, so the find-requires / dpkg-shlibdeps blind spot does not arise. That is why OpenTofu and Wezterm never hit --as-needed.

--

## DEB: Dependencies

* **`dpkg-shlibdeps`**: scan ELF in staging
* **`*.shlibs`**: SONAME → package + version
* **`symbols`**: per-symbol constraints (optional)
* **Output**: `DT_NEEDED` → `Depends: ${shlibs:Depends}`

Note:
- `debian/control`: `Depends: ${shlibs:Depends}` (variable, not manual)
- Build: `dh_shlibdeps` (debhelper) → `dpkg-shlibdeps`
- Scan ELF in staging → per `DT_NEEDED`: lookup `*.shlibs` in `/var/lib/dpkg/info/` → (package, version)
- Duality as RPM: `DT_NEEDED` seen / `dlopen()` invisible
- `shlibs`: 1 line per SONAME, e.g. `libOpenGL.so.0 libgl1 (>= 1.3.2)`
- `symbols`: per-symbol constraints → exact ABI tracking
- In the wild: Wezterm → `dpkg-shlibdeps -O -e debian/usr/bin/*` in target container
- Live demo (4 steps): `packaging/packator.sh debian builder packaging/demo/demo-deb.sh --deb dist/ocio_0.1.0_amd64.deb --bin build-debian-static/bin/ocio --bin-shared build-debian-shared/bin/ocio`
- Failure-mode difference vs RPM: here the library must be a known package (with a readable shlibs file) or the build fails loudly. In RPM, find-requires emits the SONAME as a capability with no package database needed.

--

## DEB: The *.shlibs Lookup

```text
$ apt install libgl1
```

```text
$ cat /var/lib/dpkg/info/libgl1:amd64.shlibs
libOpenGL.so.0 libgl1 (>= 1.3.2)
libGL.so.1 libgl1 (>= 1.3.2)
```

* **Placed by**: `apt install` / `dpkg -i`
* **Used by**: `dpkg-shlibdeps` to map SONAME &rarr; (package, version)

Note:
The *.shlibs lookup table:
- Every package that ships a shared library must ship a .shlibs file in /var/lib/dpkg/info/. The file is named <package>:<arch>.shlibs and contains one line per library the package provides.
- The left column is the libtool form (name + ABI version), not the raw SONAME string. dpkg-shlibdeps converts libm.so.6 -> libm 6 before the lookup.
- The file is placed on the build machine when the package is installed (apt install or dpkg -i). It is not part of the source tree; it is part of the installed system.
- This is the "package database" that dpkg-shlibdeps needs to map a SONAME to a (package, version) pair. Without it, the mapping is impossible.
- RPM contrast (speaker only): find-requires needs no such database. It reads DT_NEEDED and emits the SONAME as a capability (libraylib.so.550()(64bit)) directly. The DEB side needs the extra SONAME-to-package hop, and that hop is where a source-built library breaks.

--

## DEB: Shared Raylib

* **`RAYLIB_SHARED=ON`**: `ocio` links `libraylib.so.550` (built from source)

```text
$ readelf -d .../libraylib.so.550 | grep SONAME
  (SONAME) Library soname: [libraylib.so.550]
```
<!-- .element: class="fragment" -->

```text
$ grep -r "libraylib" /var/lib/dpkg/info/*.shlibs
(no result)
```
<!-- .element: class="fragment" -->

* **No `*.shlibs` entry** &rarr; `Depends:` uncomputable &rarr; build aborts
* **Fix**: ship a `libraylib550` package (no distro provides it)
* **Demo**: [PR #27](https://github.com/michelepagot/packathon/pull/27) (intentionally red)

Note:
Where does the shared library live?
- RAYLIB_SHARED=ON makes ocio link libraylib.so.550, built from source via FetchContent. A DEB cannot bundle an arbitrary .so and claim a dependency on it: dpkg-shlibdeps must map the SONAME to a (package, version) using the *.shlibs files of installed packages.
- The build machine must have the library installed as a known package (with a readable .shlibs file). A source-built .so in the build tree is not enough: no package owns it, no .shlibs entry exists, the lookup fails, and the build aborts.
- Verified distro facts: Debian ships no raylib at all (apt-cache showpkg libraylib -> Unable to locate package). openSUSE ships raylib 6.0, SONAME libraylib.so.600, not the 5.5 ocio needs (rpm -q --whatprovides 'libraylib.so.550()(64bit)' -> no package). So neither distro provides the matching SONAME; a libraylib550 package would have to be contributed.
- Three options (speaker analysis): (1) ship libraylib550 as a sibling package with a Depends: line - the correct fix, out of scope for the talk; (2) SHLIBDEPS_PRIVATE_DIRS - a trap, it converts a loud build failure into a silent runtime failure; (3) skip the DEB generator (pass TGZ) - what the project does, honest but incomplete.
- AppImage parallel: the same RAYLIB_SHARED=ON flag, different answer. An AppImage bundles the .so in the box (above the excludelist); the by-hand appimagetool recipe is the mistake because it never scans DT_NEEDED, so a missing lib is silent at build and loud at runtime. linuxdeploy is the scanning tool on that side. The DEB's dpkg-shlibdeps is the scanning tool on this side; it just needs the library to be a known package.
- RPM contrast: find-requires needs no package database. It reads DT_NEEDED and emits the SONAME as a capability (libraylib.so.550()(64bit)) directly. The RPM builds fine; the failure moves to install time when no repo provides the capability. The DEB side needs the extra SONAME-to-package hop, and that hop is where a source-built library breaks.

--
## After Install: Resolved

```text
$ ldd /usr/bin/ocio
  libm.so.6 => /lib64/libm.so.6
  libOpenGL.so.0 => /lib64/libOpenGL.so.0
  libGLX.so.0 => /lib64/libGLX.so.0
  libc.so.6 => /lib64/libc.so.6
  libGLdispatch.so.0 => /lib64/libGLdispatch.so.0
  libX11.so.6 => /lib64/libX11.so.6
  libxcb.so.1 => /lib64/libxcb.so.1
  ...
```

<p class="fragment text-info" style="margin-top: 25px;">
<strong>486 KB</strong> package &rarr; <strong>36</strong> packages &rarr; <strong>52.6 MiB</strong> download
</p>

Note:
Compare this directly to our initial crash:
- Every previously missing library (libOpenGL.so.0, libGLX.so.0) is now resolved to an absolute path in /lib64.
- Notice the transitive resolution: the loader also resolved the secondary dependencies pulled in by libglvnd (libGLdispatch, libX11, libxcb).
- The delegation cost: to install our 486 KB package (904 KiB on disk), the SAT solver (libsolv) selected 36 packages from the repository for a total download of 52.6 MiB.
- The userspace contract is now fully satisfied by the distribution.

Cross-distro ldd matrix (excluding libraylib, which is static in all four working flavors):
- openSUSE (fetch-static, fetch-shared, local-static — all identical): 9 libs
  ld-linux, libc, libm, libOpenGL, libGLX, libGLdispatch, libX11, libxcb, libXau
- Debian (fetch-static, fetch-shared, local-static — all identical): 4 libs
  ld-linux, libc, libm
- The 6 extra libs on openSUSE (libOpenGL, libGLX, libGLdispatch, libX11, libxcb, libXau) are GLFW's X11/GL backend. Debian's raylib build statically links GLFW's X11 code, so only the C runtime and math lib remain.
- Within each distro, static vs shared vs fetch vs local makes zero difference to the non-raylib dependencies. The distro, not the build flavor, determines the runtime footprint.

--

## How 1 Became 36: libsolv

* <!-- .element: class="fragment" --> Contract: `libOpenGL.so.0()(64bit)` (auto-detected or declared)
* <!-- .element: class="fragment" --> Engine: `zypper` / `dnf` &rarr; `libsolv`
* <!-- .element: class="fragment" --> SAT: constraints &rarr; CNF &rarr; closure in ms

Note:
Why did installing our single RPM pull in 35 additional packages?
- The package contract requires libOpenGL.so.0()(64bit), whether auto-extracted by find-requires (CPack build) or declared by the maintainer in .spec to overcome --as-needed.
- Abstract capabilities (SONAME) decouple the binary from concrete package names: any package providing libOpenGL.so.0()(64bit) (such as libglvnd) satisfies the contract.
- The low-level rpm tool cannot resolve this: raw rpm -i fails with missing dependencies.
- Frontends (Zypper / DNF) pass the repository catalog to libsolv, which queries its whatprovides index.
- libsolv translates dependency and conflict rules into Boolean Conjunctive Normal Form (CNF) clauses (e.g. A requires B -> NOT A OR B).
- In milliseconds, the CDCL SAT solver calculates a consistent package closure: on our minimal headless container, satisfying libglvnd cascades into Mesa, X11, and DRM libraries, resulting in exactly 36 packages.
- Stage note: pin the Tumbleweed image by digest before the talk. A fresh pull shifts the closure to 40 packages (53.4 MiB / 229.8 MiB); the slide's 36 (52.6 MiB) matches the pinned 2026-06-22 image. Make the slide match whatever zypper prints live.

--

## After Install: Recorded &amp; Guarded

```text
$ rpm -qf /usr/lib64/libOpenGL.so.0
libglvnd-1.7.0-2.4.x86_64
```

```text
$ rpm -V ocio && echo clean
clean
```
<!-- .element: class="fragment" -->

```text
$ rpm -e --test libglvnd
error: Failed dependencies:
  libOpenGL.so.0()(64bit) is needed by (installed) ocio-0.1.0-1.x86_64
```
<!-- .element: class="fragment" -->

Note:
Installing is copying files plus keeping an authoritative database:
- Ownership (rpm -qf): every single file on the filesystem has a registered, accountable package owner.
- Integrity verification (rpm -V): verifies files against their stored sha256 digests. If a file is modified, rpm -V alerts immediately.
- Dependency protection (rpm -e --test): the system prevents accidental removal of libraries that other installed packages still rely upon.

--

## Who knows the buildsystem?

<div class="center-card">
  <img src="image/atuin_bug_report.png" alt="atuin bug report on OBS" style="max-height: 260px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
  <p style="font-size: 0.5em; margin: 4px 0;"><a href="https://build.opensuse.org/request/show/1376894#comment-2306874" target="_blank">build.opensuse.org/request/show/1376894#comment-2306874</a></p>
</div>
<!-- .element: class="fragment" -->

<div class="center-card">
  <img src="image/atuin_fix.png" alt="atuin.spec fix on OBS" style="max-height: 150px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
  <p style="font-size: 0.5em; margin: 4px 0;"><a href="https://build.opensuse.org/requests/1380854/changes" target="_blank">build.opensuse.org/requests/1380854/changes</a></p>
</div>
<!-- .element: class="fragment" -->

---

## DEB: Debian Distro Standard

<div class="grid-2" style="align-items: center; gap: 40px; margin-top: 30px;">
<div style="flex: 0 0 auto;">
  <img src="image/Application-x-deb.svg" alt="Debian package" style="max-height: 380px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
</div>
<div style="flex: 1; font-size: 1.05em; line-height: 1.8;">

* *Ian Murdock* (Debian, 1993)
* Strict policy &amp; FHS compliance
* Debian, Ubuntu &amp; Mint standard

<p class="fragment text-info" style="margin-top: 35px;">
<strong>Superpower:</strong> Exact symbol mapping via <code>dpkg-shlibdeps</code> and maintainer scriptlets.
</p>

</div>
</div>

Note:
Introducing DEB:
- Origin: Created in 1993 by Ian Murdock for the initial Debian release.
- Nature: An archive format bound by strict distro packaging policies and FHS compliance.
- Adoption: The reference standard for Debian, Ubuntu, Linux Mint, and derivatives.
- Daily CLI:
  * Inspect: dpkg-deb -c (files) and dpkg-deb -I (control metadata)
  * Install with solver: apt install ./file.deb
  * Audit integrity: debsums (verifies file checksums against md5sums)
- Superpower: Exact library symbol mapping and maintainer scriptlets.
Next we look at what is physically inside a .deb file on disk.

--

## DEB: Who Uses It
<!-- .slide: data-logos="image/debian.png image/ubuntu.png image/linuxmint.png image/kali.png image/deepin.png image/tails.png image/raspberry.png image/devuan.png image/zorin.png image/popos.png image/elementary.png image/parrot.png image/mxlinux.png image/whonix.png image/sparky.png image/pureos.png image/knoppix.png image/trisquel.png image/antix.png image/q4os.png image/peppermint.png image/bodhi.png image/siduction.png image/webconverger.png" -->

  <p class="text-muted" style="margin-bottom: 10px;">Distributions that use DEB under the hood</p>

* <!-- .element: class="fragment" data-fragments="logos" --><strong>Debian</strong>: Debian, Ubuntu, Linux Mint
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Modern desktops</strong>: Deepin, Zorin OS, Pop!_OS, elementary OS, MX Linux
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Security/privacy</strong>: Kali Linux, Tails, Whonix, Parrot OS
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Embedded/edge</strong>: Raspberry Pi OS
* <!-- .element: class="fragment" data-fragments="logos" --><strong>Derivatives/other</strong>: Devuan, SparkyLinux, PureOS, KNOPPIX, Trisquel, antiX, Q4OS, Peppermint, Bodhi, siduction, Webconverger

Note:
  - Debian family: Debian, Ubuntu (and all its flavours: Kubuntu, Xubuntu, Lubuntu, Ubuntu MATE, etc.), Linux Mint.
  - Modern desktops: Deepin (proprietary GUI), Zorin OS (Windows-switcher focused), Pop!_OS (System76), elementary OS (macOS-like aesthetics), MX Linux (community, Debian Stable based).
  - Security/privacy: Kali Linux (penetration testing), Tails (portable, all traffic via Tor), Whonix (Tor isolation), Parrot OS (security + daily driver).
  - Embedded/edge: Raspberry Pi OS (formerly Raspbian) for the world's most popular SBC.
  - Derivatives/other: Devuan (systemd-free), SparkyLinux (lightweight), PureOS (free software, Librem), KNOPPIX (live forensics), Trisquel (100% free software), antiX (very lightweight), Q4OS (KDE/Trinity DE), Peppermint OS (lightweight, cloud-first), Bodhi (Moksha DE), siduction (live, Debian Unstable based), Webconverger (browser kiosk).
  - Front-ends: the same DEB format is handled by dpkg (low-level) and apt (dependency resolver), regardless of the distro.
  - Takeaway: "Same format, same policy: the .deb file is identical, only the GUI on top changes."

--

## Inside a DEB: Unix `ar` Archive

```text
$ file ocio_0.1.0_amd64.deb
ocio_0.1.0_amd64.deb: Debian binary package (format 2.0)
```

```text
$ ar -t ocio_0.1.0_amd64.deb
debian-binary
control.tar.xz
data.tar.xz
```
<!-- .element: class="fragment" -->

```text
$ dpkg-deb -I ocio_0.1.0_amd64.deb | grep -E 'Depends|Recommends'
 Depends: libc6 (>= 2.35), libglx0, libx11-6
 Recommends: libxcursor1, libxi6, libxinerama1, libxrandr2
```
<!-- .element: class="fragment" -->

Note:
Anatomy of a .deb file:
- Uses no proprietary container format: it is a standard Unix ar archive (the exact same format used by compilers for static libraries .a).
- Contains exactly three members:
  1. debian-binary: text string with format version ("2.0\n").
  2. control.tar: compressed archive with package metadata (control file, md5sums, maintainer scriptlets).
  3. data.tar: compressed archive with the actual payload files unpacked onto the filesystem.
- dpkg-deb -I: inspects control metadata. The Depends line is split in two: libc6 (>= 2.35) is computed automatically by dpkg-shlibdeps from the binary's DT_NEEDED (libc, libm), while libglx0 and libx11-6 are declared by hand because GLFW loads them with dlopen() after main(), so they are invisible to the scanner. Recommends lists the optional X11 input/geometry libraries GLFW degrades without.

--

## Inside a DEB: Payload

```text
$ dpkg-deb -c ocio_0.1.0_amd64.deb
drwxr-xr-x root/root         0 ./
drwxr-xr-x root/root         0 ./usr/
drwxr-xr-x root/root         0 ./usr/bin/
-rwxr-xr-x root/root    497664 ./usr/bin/ocio
-rw-r--r-- root/root       245 ./usr/share/applications/ocio.desktop
-rw-r--r-- root/root      1892 ./usr/share/icons/hicolor/256x256/apps/ocio.png
-rw-r--r-- root/root       612 ./usr/share/icons/hicolor/scalable/apps/ocio.svg
-rw-r--r-- root/root       847 ./usr/share/metainfo/org.packathon.ocio.metainfo.xml
```

Note:
dpkg-deb -c lists the data.tar contents without extracting (timestamps omitted for readability):
- /usr/bin/ocio: the binary, placed in a system directory already on $PATH. It is 1,261,264 bytes (unstripped, debug info included), which is why Installed-Size reads 1264 KiB.
- .desktop + icons: desktop entry and icons so the desktop environment renders it in menus.
- metainfo XML: AppStream metadata so GUI software centers (GNOME Software, Discover) can present descriptions, categories, and screenshots.
- The payload is the same file set as the RPM: same FHS layout. The difference is purely in the container format (ar + tar vs. cpio) and the metadata encoding (control file vs. RPM header).

--

## Inside a DEB: Metadata

```text
$ dpkg-deb -I ocio_0.1.0_amd64.deb
 Package: ocio
 Version: 0.1.0
 Architecture: amd64
 Maintainer: Packathon Maintainers <maintainers@packathon.org>
 Installed-Size: 1264
 Depends: libc6 (>= 2.35), libglx0, libx11-6
 Recommends: libxcursor1, libxi6, libxinerama1, libxrandr2
 Section: graphics
 Priority: optional
 Description: Raylib interactive eye-tracking educational demo
```
<!-- .element: class="fragment" -->

```text
$ dpkg-deb -e ocio_0.1.0_amd64.deb ./deb-control/
$ cat ./deb-control/control | grep -E 'Depends|Recommends'
 Depends: libc6 (>= 2.35), libglx0, libx11-6
 Recommends: libxcursor1, libxi6, libxinerama1, libxrandr2
```
<!-- .element: class="fragment" -->

Note:
Control file inspection:
- Look at Depends: libc6 (>= 2.35), libglx0, libx11-6. This is the package-level equivalent of the RPM's libOpenGL.so.0()(64bit) capability strings.
- The difference in granularity: RPM declares SONAME-level capabilities (libOpenGL.so.0()(64bit)); DEB declares package names (libglx0). The solver maps package names to the actual libraries at resolution time.
- The line is split in two: libc6 (>= 2.35) is computed automatically by dpkg-shlibdeps from the binary's DT_NEEDED (libc, libm); libglx0 and libx11-6 are declared by hand because GLFW loads them with dlopen() after main(), so they are invisible to the scanner. Recommends lists the optional X11 input/geometry libraries.
- dpkg-deb -e extracts the control.tar member into a directory, exposing the control file, md5sums, and any maintainer scriptlets (preinst, postinst, prerm, postrm).

--

## After Install: Recorded & Guarded

```text
$ dpkg -S /usr/lib/x86_64-linux-gnu/libGLX.so.0
libglx0:amd64: /usr/lib/x86_64-linux-gnu/libGLX.so.0
```

```text
$ debsums ocio
/usr/bin/ocio: MD5 sum is OK
/usr/share/applications/ocio.desktop: MD5 sum is OK
```
<!-- .element: class="fragment" -->

```text
$ apt-get remove --dry-run libglx0
The following packages will be REMOVED:
  libglx0 ocio
```
<!-- .element: class="fragment" -->

Note:
Installing is copying files plus keeping an authoritative database:
- Ownership (dpkg -S): every file on the filesystem has a registered package owner, the Debian equivalent of rpm -qf. libGLX.so.0 is owned by libglx0 (the libglvnd dispatcher); libOpenGL.so.0 is owned by the separate libopengl0 package.
- Integrity verification (debsums): verifies files against their stored MD5 digests from the md5sums control file. It detects accidental change, not a root attacker, and MD5 is a weak hash by modern standards.
- Dependency protection (apt-get remove --dry-run): the solver prevents accidental removal of libraries that other installed packages still depend on, mirroring rpm -e --test.
- The dpkg database lives in /var/lib/dpkg/status; apt layers a repository index and its own resolver on top. APT's classic resolver is heuristic (not a SAT solver like libsolv); APT 3.0 adds a separate new solver (solver3).

--

## Cooking a DEB

<div style="text-align: center;">
<img src="image/deb-pipeline.png" alt="DEB build pipeline" style="max-height: 620px; width: auto;" />
</div>

Note:
How native DEBs are built:
- In Debian, the recipe is not a single file like in RPM, but a dedicated debian/ directory inside the source tree.
- The primary build driver is dpkg-buildpackage (or the developer wrapper debuild).
- Running dpkg-buildpackage -us -uc -b builds the binary package without signing source or changes files.
- The build process is orchestrated by debian/rules, which delegates to the Debhelper sequencer (dh).
- Artifacts produced: the binary package (.deb), the build log, and the .changes file declaring package upload metadata.
- In the repository the canonical recipe lives in packaging/deb/debian/ (control, rules, changelog, source/format); build-deb.sh --mode debhelper links it into the source root and runs dpkg-buildpackage -us -uc -b -d.
- The same build-deb.sh offers a second dialect, --mode frugal: no debhelper, the payload is staged into an FHS skeleton, md5sums and Installed-Size are computed by hand, and the archive is assembled with dpkg-deb. Same ar format, same reliance on dpkg-shlibdeps: two dialects, one format.
In the wild: at production scale the two dialects extend. OpenTofu uses nFPM (in-process, no dpkg-deb, no debhelper). Wezterm uses native dpkg-deb + dpkg-shlibdeps inside the Debian container. Same ar format, three access routes.

--

## Inside debian/

* **`control`**: metadata &amp; dependencies
* **`rules`**: build lifecycle (`dh $@`)
* **`changelog`**: version &amp; release
* **`copyright`**: DEP-5 licenses
* **`dh`**: build sequencer

Note:
The structure of a Debian recipe:
- debian/control: Declares package metadata, build-time dependencies (Build-Depends), and runtime dependencies using substitution variables like ${shlibs:Depends}.
- debian/rules: An executable Makefile. Modern packaging uses dh $@ to automate build steps (dh_auto_configure, dh_auto_build, dh_auto_install).
- debian/changelog: Authoritative for package version and release. In Debian, you do not set Version in control; dpkg-parsechangelog extracts it from the top entry.
- debian/copyright: Standardized DEP-5 manifest auditing licenses per file for DFSG compliance.
- Runtime resolution: dh_shlibdeps scans compiled ELF binaries, consults each library's shlibs/symbols file, and automatically populates ${shlibs:Depends}.

--

## Delegation

* <!-- .element: class="fragment" --> Binary Contract: Package carries payload only &rarr; dependencies delegated to host OS
* <!-- .element: class="fragment" --> Transitive Closure: Solver (`libsolv` / APT) traverses repository graph to satisfy requirements
* <!-- .element: class="fragment" --> Zero Runtime Overhead: Direct `execve()` on system `/usr` &rarr; no daemon, no wrapper
* <!-- .element: class="fragment" --> System Ledger: Host database registers file ownership, checksums, and dependency guards

Note:
The delegation architectural paradigm:
- Philosophy: The developer ships only application machine code and assets; the distribution provides all shared libraries and system drivers.
- Resolution: zypper/dnf and apt do not guess; their SAT solvers compute the transitive closure across tens of thousands of repository packages.
- Execution: Unlike AppImage (FUSE mount) or Flatpak (bwrap sandbox), a distro package runs directly via kernel execve() without intermediary runtimes.
- Bookkeeping: The package manager is an authoritative ledger ensuring file ownership, integrity verification (rpm -V / debsums), and preventing broken dependencies.

--

## Dialects

| Dimension | RPM | DEB |
|---|---|---|
| **Container** | CPIO | `ar` |
| **Tool** | `rpm` | `dpkg` |
| **Manager** | `zypper` | `apt` |
| **Deps gen** | `find-requires` | `dpkg-shlibdeps` |
| **Deps format** | SONAME capability | package name via `*.shlibs` |
| **Inspect** | `rpm -qlp` | `dpkg-deb -c` |
| **Audit** | `rpm -V` | `debsums` |
<!-- .element: style="font-size: 0.76em;" -->

Note:
Two dialects, identical engineering principles:
- Containers: RPM uses a compressed CPIO payload (zstd or gzip); DEB uses a classic Unix ar archive containing control.tar (metadata) and data.tar (payload).
- Dependency generation: find-requires scans ELF DT_NEEDED entries and emits each SONAME directly as a capability (e.g. `libraylib.so.550()(64bit)`) with no package database lookup; dpkg-shlibdeps must map each SONAME to a (package, version) via the `*.shlibs` files of installed packages, so it needs a package database. A source-built library with no shlibs entry fails the DEB build, but the RPM still builds and then requires `libraylib.so.550()(64bit)`, which no repository provides, so it is uninstallable. The failure moves from build time to install time.
- Inspection: rpm -qlp FILE.rpm vs dpkg-deb -c FILE.deb for files; rpm -qp --requires vs dpkg-deb -I for metadata.
- Integrity: rpm -V PACKAGE audits files against the RPM database; debsums PACKAGE verifies files against stored md5sums.
- Resolution: Both delegate to a high-level solver (zypper/dnf with libsolv, apt with its dependency engine).

--

## Delegation: Trade-Offs

<div class="grid-2" style="margin-top: 30px;">
<div class="box-success fragment">

#### Advantages

* Minimal payload: **486 KB** (52.6 MiB download delegated)
* Shared libraries: patched once at OS level for all apps
* Ownership &amp; verification: `rpm -qf`, `rpm -V` / `debsums`

</div>
<div class="box-danger fragment">

#### Constraints

* ABI coupling: strict host glibc baseline (e.g. `GLIBC_2.43`)
* Distro policies: FHS compliance, root scriptlet audits
* Matrix explosion: one build per target distro &amp; release

</div>
</div>

Note:
Evaluating the trade-offs of delegation:
- Advantages: High efficiency and shared maintenance. A 486 KB package delegates 52.6 MiB of download and ~226 MiB of disk dependencies to packages maintained by the distro. Shared libraries (e.g. libglvnd, Mesa) receive CVE fixes once for the whole system.
- Constraints: The binary is tightly coupled to the host environment ABI, in particular glibc symbol versions. Distro packaging requires complying with strict packaging policies (FHS, no bundling, root scriptlet scrutiny) and building distinct packages for every target distribution and architecture.

---

## AppImage: Portable Single-File

<div class="grid-2" style="align-items: center; gap: 40px; margin-top: 30px;">
<div style="flex: 0 0 auto;">
  <img src="image/appimage.png" alt="AppImage" style="max-height: 380px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
</div>
<div style="flex: 1; font-size: 1.05em; line-height: 1.8;">

* *Simon Peter* (2004 *klik*, 2011)
* One app = one executable file
* Distro-agnostic portability, zero install (no root)

</div>
</div>

Note:
Introducing AppImage:
- Origin: Created in 2004 by Simon Peter (probono) as klik, rebranded in 2011 as AppImage.
- Nature: An application packaged as a single executable file with an embedded SquashFS image. It contains the dependencies the host is not expected to have, not all of them (see "The Box Has an Edge").
- Adoption: De facto upstream format for standalone portable Linux desktop applications (no root required).
- Daily CLI:
  * Run: chmod +x ./file.AppImage && ./file.AppImage
  * Extract / Fallback: ./file.AppImage --appimage-extract (runs without FUSE)
- The GLIBC catch: Bundles application libraries, but relies on the host's glibc and kernel. The golden rule: build on the oldest distro you plan to support.
Next we look at what is physically inside the AppImage file on disk.

--

## Inside AppImage: The `EI_PAD` Trick

```text
$ file ocio-x86_64.AppImage

ocio-x86_64.AppImage: ELF 64-bit LSB pie executable,
static-pie linked
```
<!-- .element: class="fragment" -->

| `00..03` | `04..07` | `08..0A` | `0B..0F` |
|:---:|:---:|:---:|:---:|
| `\x7fELF` | `x86_64/SystemV` | **`AI\x02`** | `padding (0x00)` |
<!-- .element: class="fragment" -->

```text
$ xxd -l 96 -d ocio-x86_64.AppImage
0000: 7f45 4c46 0201 0100 4149 0200 0000 0000  .ELF....AI......
0016: 0300 3e00 0100 0000 87ae 0200 0000 0000  ..>.............
0032: 4000 0000 0000 0000 7862 0e00 0000 0000  @.......xb......
0048: 0000 0000 4000 3800 0a00 4000 1e00 1d00  ....@.8...@.....
0064: 0100 0000 0400 0000 0000 0000 0000 0000  ................
0080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
```
<!-- .element: class="fragment" style="font-size: 0.48em; line-height: 1.2;" -->

Note:
Dissecting the AppImage binary header:
- In the Foundations chapter we saw that every ELF binary begins with the 16-byte e_ident header.
- The ELF specification defines bytes 8 to 15 as EI_PAD: reserved padding intended for future ABI expansion, conventionally zeroed.
- AppImage Type 2 overwrites bytes 8, 9, and 10 with ASCII 'A', 'I', and 0x02.
- Why this is brilliant:
  1. Zero execution penalty: the OS kernel loader only checks bytes 0 to 3 (\x7fELF) and, like ld.so, ignores EI_PAD, so the file remains 100% executable machine code.
  2. Instant detection: desktop indexers, file managers, app managers and file(1) don't need to mount or scan the multi-megabyte SquashFS payload: reading 11 bytes gives instant identification, in O(1) time.
  3. Format versioning: generations are cleanly versioned, AI\x01 for legacy Type 1 (ISO 9660) vs AI\x02 for modern Type 2 (SquashFS + FUSE).
- The emulation caveat: Native kernels ignore EI_PAD, but container emulation (QEMU-user binfmt_misc) can trip on non-standard padding with ENOEXEC ("Exec format error"). This is why native ARM64 runners are required for reliable multi-arch builds.
- Reading the table: the "x86_64 / System V" column (bytes 04..07) is a simplification. Byte 7 (e_ident[7]) is the OS/ABI field: 01 = System V, the standard Linux ABI. The actual CPU architecture (e_machine = 0x3e, x86-64) lives further in the ELF header at offset 18, visible in the 0016: line as 3e00. The 03 at byte 16 (e_abi) is a finer-grained ABI version field, mostly unused on Linux.

--

## Inside an AppImage: Stub &amp; SquashFS

* **ELF runtime stub**: static-pie launcher at the front (~922 KiB)
* **SquashFS payload**: compressed filesystem appended behind it (~451 KiB)

```text
$ unsquashfs -s -offset $(./ocio-x86_64.AppImage --appimage-offset) ocio-x86_64.AppImage

Found a valid SQUASHFS
4:0 superblock on ocio-x86_64.AppImage
Filesystem size 461732 bytes,
compression zstd
```
<!-- .element: class="fragment" -->

Note:
Low-level mechanics of the AppImage binary:
- An AppImage is not an archive with an installer. It is a composite binary: an ELF executable stub with a compressed SquashFS filesystem glued behind it.
- The stub is a static-pie executable built with musl libc, libfuse3, and squashfuse.
- The payload is a pure SquashFS 4.0 filesystem compressed with zstd.
- Forensic verification: unsquashfs reads the superblock directly from the file without mounting or root privileges. The --appimage-offset option tells you where the seam is.
- Total file footprint: 1,406,364 bytes (1.34 MiB) — fits on a 1.44 MB floppy with room to spare.

--

## Inside AppImage: Mount Lifecycle

```text
$ ocio-x86_64.AppImage --appimage-mount
/tmp/.mount_ocio-xApLEba
```
<!-- .element: class="fragment" -->

```text
$ df -h | grep /tmp/.mount
ocio-x86_64.AppImage  451K  451K     0 100% /tmp/.mount_ocio-xApLEba

$ ls -1 /tmp/.mount_ocio-xApLEba
AppRun
ocio.desktop
ocio.png
usr
```
<!-- .element: class="fragment" -->

Note:
The runtime mount lifecycle:
- Launch and intercept: When executed, the ELF runtime stub intercepts control before the application starts. It creates a temporary directory /tmp/.mount_XXXXXX and uses FUSE (squashfuse + libfuse3) to mount the embedded SquashFS payload.
- Execution: Control is transferred to the AppRun script located at the mount root, which sets environment variables (such as PATH and LD_LIBRARY_PATH) and invokes usr/bin/ocio.
- Teardown: When the application terminates, the runtime stub unmounts the filesystem and deletes the mount point.
- The inspection technique:
  Instead of struggling to catch the ephemeral directory with watch commands, --appimage-mount mounts the filesystem, prints the path, and waits for Ctrl+C.
  In another shell, df and ls reveal the mounted FHS structure (usr/bin, usr/share, AppRun).
- The FUSE requirement and fallback:
  AppImage depends on host FUSE support (/dev/fuse and fusermount3).
  In environments lacking FUSE (containers, Docker, or minimal installations), launch fails.
  The official fallback: --appimage-extract-and-run (or APPIMAGE_EXTRACT_AND_RUN=1) extracts to /tmp and runs without FUSE.

--

## Cooking an AppImage

```text
AppDir/
├── AppRun -> usr/bin/ocio
├── ocio.desktop
├── ocio.png
└── usr/
    ├── bin/ocio
    ├── lib/          ← bundled libraries
    └── share/...
```

| Recipe | Who fills `usr/lib` |
|---|---|
| `appimagetool AppDir/ ocio.AppImage` | **You**, by hand. Nobody checks. |
| `linuxdeploy --appdir AppDir ...` + `appimagetool` | **The tool**: scans `DT_NEEDED`, copies, sets `RUNPATH` |
<!-- .element: class="fragment" -->

<p class="fragment" style="position: absolute; bottom: 0.3em; right: 1.5em; font-size: 0.85em; margin: 0;"><a href="https://github.com/wezterm/wezterm/blob/master/ci/appimage.sh" target="_blank">Wezterm</a></p>

Note:
An AppImage is a squashed directory tree, the AppDir:
- AppRun is the entry point (here a symlink to the binary).
- A .desktop file and its icon are required at the top level: appimagetool refuses to pack without them.
- usr/ is a small root filesystem: binary, bundled libraries, desktop file, icons, metainfo.
Two recipes, both in packaging/appimage/build-appimage.sh --method {linuxdeploy,appimagetool}:
- appimagetool by hand: we assemble the AppDir (CMake install, .desktop, icon, AppRun symlink). appimagetool only squashes the tree and prepends the runtime. It never looks at the dependencies: if the binary needs a library that is not on the host, nothing warns you.
- linuxdeploy (the script default): walks the DT_NEEDED tree, copies every library that is not on the AppImage excludelist into usr/lib, sets RUNPATH=$ORIGIN/../lib with patchelf, strips, and creates AppRun. appimagetool then packs the result.
- linuxdeploy and appimagetool are themselves AppImages. The builder images ship them pre-extracted, so they run without FUSE; the script downloads nothing and fails with install hints if a tool is missing.
In the wild: Wezterm is a production linuxdeploy user. ci/appimage.sh downloads linuxdeploy from its continuous release, points it at the AppDir, and sets UPDATE_INFORMATION with the gh-releases-zsync scheme so the AppImage can self-update from GitHub Releases. It is the same recipe as the slide, but with self-update embedded.
Key message: "self-contained" is not a property of the format. It is a packaging job, and the next question is: what should go in the box?

--

## Cooking an AppImage: Step by Step

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

```bash
DESTDIR=AppDir cmake \
       --install build \
       --component ocio \
       --prefix /usr
```
<!-- .element: class="fragment" -->

```bash
linuxdeploy --appdir AppDir \
            --executable AppDir/usr/bin/ocio \
            --desktop-file ocio.desktop \
            --icon-file ocio.png
```
<!-- .element: class="fragment" -->

```bash
appimagetool --runtime-file /usr/lib/runtime-x86_64 \
             AppDir ocio-x86_64.AppImage
```
<!-- .element: class="fragment" -->

Note:
The four steps that packaging/appimage/build-appimage.sh runs with the default --method linuxdeploy:
1. Build: a normal CMake Release build. Nothing AppImage-specific yet.
2. Stage: install only the ocio component (the default install also has raylib's dev files) into AppDir, with --prefix /usr because linuxdeploy expects the usr/ layout. This gives usr/bin/ocio plus the desktop file, icons and metainfo.
   DESTDIR vs --prefix: DESTDIR=AppDir is a real, relative staging root in the current working directory (the POSIX DESTDIR convention, same as `make install DESTDIR=...` or rpmbuild's BUILDROOT). --prefix /usr is a virtual prefix: CMake computes every install path as DESTDIR + prefix, so files land in ./AppDir/usr/... without ever touching the real /usr on the build machine. The two variables are independent: DESTDIR is where the tree is physically written, --prefix is the layout the files pretend to have inside it.
   Why --prefix /usr specifically: linuxdeploy and the AppImage format expect the FHS layout inside the AppDir (usr/bin, usr/lib, usr/share). With --prefix / and DESTDIR=AppDir you would get AppDir/bin/ocio (no usr/), which linuxdeploy would not recognize. --prefix /usr + DESTDIR=AppDir produces exactly the usr/ subtree the format requires, mirroring how rpmbuild stages into BUILDROOT and dpkg-buildpackage stages into a fakeroot.
3. Bundle: linuxdeploy reads DT_NEEDED recursively, copies into usr/lib every library that is not on the excludelist, sets RUNPATH=$ORIGIN/../lib, strips, and creates AppRun and the top-level .desktop and icon links. For our default build it copies nothing: everything ocio needs is on the excludelist (next slide).
4. Pack: appimagetool turns the AppDir into a SquashFS image and prepends the type2 runtime, the ELF stub with the AI\x02 magic from the EI_PAD slide. We pass the runtime file explicitly, otherwise appimagetool downloads it at every build.
The hand recipe (--method appimagetool) skips step 3: we place AppRun, the .desktop file and the icon ourselves, and nobody checks the libraries.
All three tools (linuxdeploy, appimagetool, runtime) come pre-installed in the builder images; linuxdeploy and appimagetool are pre-extracted, so they run without FUSE.

--

## The Box Has an Edge

| Category | Inside the box | Outside: the host |
|---|---|---|
| **Binary** | `ocio` + assets | glibc: `libc`, `libm`, `ld.so` |
| **GL** | Raylib (static) | `libOpenGL`, `libGLX`, `libGLdispatch` |
| **Display / Audio** | — | X11 / xcb, `libdrm`, ALSA |

AppImage **excludelist**: libraries assumed present on every desktop.
<!-- .element: class="fragment" -->

```text
$ ./ocio.AppImage            # vanilla Tumbleweed container
/ocio.AppImage: error while loading shared libraries: libOpenGL.so.0
```
<!-- .element: class="fragment" -->

<p class="fragment text-info">
Correct box, wrong host: a bare container is not a desktop.
</p>

Note:
What the excludelist is:
- pkg2appimage/excludelist, applied by linuxdeploy: libraries "assumed present on the host system and hence should NOT be bundled".
- Contents: glibc, the whole GL stack (libOpenGL, libGLX, libGLdispatch, libGL, libEGL, libdrm), X11/xcb, ALSA.

Why GL stays outside (same argument as Build vs. Runtime):
- GPU drivers are dynamic dispatchers that must match the host card.
- libglvnd loads libGLX_mesa or libGLX_nvidia from the host.
- A bundled Mesa works in a container, breaks on the NVIDIA proprietary driver or on a GPU newer than the bundled Mesa.

Our ocio:
- raylib is static; DT_NEEDED is only libm, libOpenGL.so.0, libGLX.so.0, libc.
- All four are on the excludelist, so linuxdeploy finds nothing to bundle.
- The AppImage is correct by the format's own rules.

The error in the container:
- It is the edge of the box, not a bug in it.
- Installing libglvnd in the container recreates the desktop base system AppImage assumes; on a real desktop it is already there.

The catch:
- AppImage never declares that base system. The excludelist is "a working document".
- Flatpak turns the same idea into an explicit, versioned runtime (bridge to Flatpak).

Side note:
- The AppImage built on Debian starts and prints --version in the same container.
- Not a better box: --as-needed dropped GL from DT_NEEDED, so it fails later, when GLFW dlopen()s Xlib.
In the wild: Wezterm applies the same excludelist idea to a single library: it passes --exclude-library=libwayland-client.so.0 to linuxdeploy to keep out a library the app does not use at runtime. The excludelist is a working document; the flag is its surgical form.

--

## Cooked Wrong, Cooked Right

```text
$ RAYLIB_SHARED=ON build-appimage.sh --method appimagetool
$ ./ocio-x86_64.AppImage
... error while loading shared libraries: libraylib.so.550
```

```text
$ RAYLIB_SHARED=ON build-appimage.sh --method linuxdeploy
$ ls AppDir/usr/lib
libraylib.so.550
$ readelf -d AppDir/usr/bin/ocio | grep RUNPATH
 (RUNPATH)  Library runpath: [$ORIGIN/../lib]
```
<!-- .element: class="fragment" -->

<p class="fragment text-danger">
<code>zypper in raylib</code> would hide the bug, and defeat the point of the box.
</p>

Note:
Now a real packaging mistake, above the excludelist line:
- Build raylib as a shared library. ocio now needs libraylib, which is not on the excludelist: it belongs in the box.
- Wrong: the hand recipe does not put it in (CMake installs libraylib.so with the raylib-devel component, not with ocio). The build-tree binary runs, because CMake's build RPATH points into the build directory: "works on my machine" one more time. The AppImage fails on the desktop.
- Right: linuxdeploy copies libraylib into usr/lib and sets RUNPATH=$ORIGIN/../lib, so ld.so finds it inside the mount. libOpenGL and libGLX stay outside, as they should. The script points LD_LIBRARY_PATH at the build-tree libraylib so the scan can find it: the installed binary has no RUNPATH, so the scan would otherwise see nothing.
- Not a fix: installing raylib with the distro package manager. It turns the AppImage back into a binary that depends on the distro. On Tumbleweed it would not even work: the distro ships raylib 6.0, ocio was built against 5.5.
- Parallel to the DEB slide: dpkg-shlibdeps is the scanning tool on that side, and it needs the library to be a known package. linuxdeploy is the scanning tool on this side, and it needs the library to be findable on the build host. Same habit: let the tool check the contract.
Takeaway: the fix for a broken box is inside the box, not on the host.
TO VERIFY before the talk: the exact soname, the error text and RUNPATH vs RPATH in the linuxdeploy output.

---

## Flatpak

<div class="grid-2" style="align-items: center; gap: 40px; margin-top: 30px;">
<div style="flex: 0 0 auto;">
  <img src="image/flatpak.png" alt="Flatpak" style="max-height: 380px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
</div>
<div style="flex: 1; font-size: 1.05em; line-height: 1.8;">

* **Alexander Larsson**, 2015
* Sandboxed apps, runtime-provided libraries.

</div>
</div>

Note:
Introducing Flatpak:
- Origin: Created in 2015 by Alexander Larsson at Red Hat under the working title xdg-app, officially rebranded to Flatpak in 2016. Larsson was a long-time core GNOME contributor.
- Before xdg-app: glick, an early single-file application installer experiment (a pun on "click"). As kernel container features (namespaces, cgroups, seccomp) matured, glick evolved into xdg-app.
- The Problem (four systemic issues, in Larsson's words):
  1. The distribution bottleneck: distros act as strict gatekeepers deciding if, when, and how an app is packaged; users on stable/LTS distros wait months or years for features and fixes, and bug reports land on the distro's outdated package instead of reaching upstream.
  2. Cross-distribution and cross-version incompatibility: no single binary worked across all distros, or even across release versions of the same distro (glibc, dependencies, and paths differed everywhere).
  3. The "package everything" burden: every distro felt compelled to package tens of thousands of apps, duplicating the effort of recompiling the world and diverting focus from innovating on the core OS and desktop.
  4. Lack of isolation: traditional Linux apps run unconfined under the user's permissions: any installed app can read, modify, or erase everything in $HOME and access other running processes.
- The Vision: Reconnect application developers directly with their users and decouple the application from the host operating system. Build once and run anywhere (Ubuntu, Fedora, openSUSE, Arch) without relying on distribution packaging teams: an upstream fix reaches users the same day, on any distro.
- Three Architectural Pillars:
  1. Runtime & Application Split: Applications run against versioned runtimes (org.freedesktop.Platform, GNOME, KDE) rather than host /usr; runtimes receive independent security updates.
  2. OSTree Storage: "Git for binaries" providing content-addressed storage, hardlink deduplication across apps and runtimes, and atomic rollback/updates.
  3. Unprivileged Sandboxing: Bubblewrap (bwrap) isolation using kernel namespaces, cgroups, and seccomp, mediated via XDG Desktop Portals.
- In the wild: Wezterm builds its Flatpak against the same org.freedesktop.Platform//25.08 runtime that ocio uses, plus Sdk//25.08 and Sdk.Extension.rust-stable//25.08. Same runtime, two independent projects.
- Trivia (if there is time):
  - The renaming: "XDG" was an obscure acronym to end users, and saying "an xdg-app app" was cumbersome.
  - "Flatpak" not "Flatpack": the missing c is intentional; the unique spelling makes it extremely easy to Google.
  - In 1994 Larsson bicycled to school to download software onto 14 floppy disks; if one corrupted, he had to bicycle back for a fresh copy.
  - Before Flatpak, GTK, and Nautilus, Larsson created Dia (1999) to draw UML diagrams for a university class.

--

## Flatpak: Sandboxed Desktop Runtime

<div class="grid-2">
<div>

### What It Is
* Universal sandboxed desktop standard
* Shared, versioned platform runtimes
* Content-addressed storage via OSTree

</div>
<div>

### Daily CLI
* **Run**: `flatpak run org.packathon.ocio`
* **Inspect**: `flatpak run --command=sh <app>`
* **Override**: `flatpak override --user <flags>`

</div>
</div>

<p class="fragment text-info" style="margin-top: 30px;">
<strong>Superpower:</strong> Total decoupling from host OS via unprivileged Bubblewrap sandboxes.
<br><span class="text-warn">The Catch:</span> Zero implicit access to host hardware, display, or files.
</p>

Note:
Introduce Flatpak via the 4-lens framework:
1. What it is: An application distribution format built around a clean split between application binaries and shared platform runtimes, backed by OSTree storage.
2. Superpower: Complete decoupling. The application never sees host /usr. Instead, it runs inside an unprivileged Bubblewrap container with namespaces and seccomp filtering. The concrete result: an upstream fix or feature reaches users the same day, regardless of which distro they run.
3. Common workflow: Install from configured remotes, run, inspect the interior environment with --command=sh, and dynamically tweak permissions with flatpak override.
4. The Catch: Because the sandbox is isolated by default, every access to the outside world must be explicitly declared. Access to host resources (files, webcam, notifications) goes through Portals: interactive host-side dialogs that grant fine-grained access only when the user approves.

--

## Inside Flatpak: Filesystem Layout

```text
$ flatpak run --command=sh org.packathon.ocio
[org.packathon.ocio ~]$ ls /
app  bin  dev  etc  lib  lib64  proc  run  sys  usr  var
[org.packathon.ocio ~]$ which ocio
/app/bin/ocio
```

* **`/app`**: Application payload &amp; custom bundled libraries (read-only mount)
* **`/usr`**: Shared runtime (`org.freedesktop.Platform`), immutable and versioned
* **Host `/`**: Completely hidden; isolation provided by **Bubblewrap** (`bwrap`)
<!-- .element: class="fragment" -->

Note:
Internal filesystem layout of Flatpak:
- Running --command=sh drops us into the exact environment the application sees.
- Notice the two primary mount points:
  1. /app contains exclusively the application binary, desktop files, and bundled dependencies.
  2. /usr is mounted from the shared Freedesktop runtime. It contains libc, mesa, and standard graphics stacks, guaranteed identical on Arch, Debian, openSUSE, or Fedora.
- The host root filesystem is nowhere to be seen.

--

## Inside Flatpak: OSTree

* **OSTree**: git for filesystem trees (content-addressed, SHA-256)
* **Commit**: snapshot of a whole directory tree
* **Ref**: named pointer to a commit, like a git branch
* **Delta**: diff between two commits; client downloads only the change

```text
$ ostree --repo=repo log app/org.packathon.ocio/x86_64/master
$ ostree --repo=repo static-delta generate --from=<old> --to=<new>
```
<!-- .element: class="fragment" -->

<p class="fragment text-info" style="margin-top: 25px;">
<strong>Why it matters:</strong> a Flatpak repo is just static files, so it can be served by any web server (GitHub Pages).
</p>

Note:
OSTree is the storage engine underneath every Flatpak:
- It is git, but the objects are filesystem contents, not source files. Every file, directory listing and commit is stored by its SHA-256 hash, so identical files are stored once (deduplication).
- A commit is a snapshot of a complete directory tree. A ref is a plain-text pointer to a commit, exactly like a git branch. The Flatpak ref for our app is app/org.packathon.ocio/x86_64/master (app-id, arch, branch).
- Deltas are the diff between two commits. --generate-static-deltas precomputes them so a client updating from v0.1.0 to v0.1.1 downloads only the changed files, not the whole app.
- Because an archive-z2 repo is only static files (objects/, refs/, summary), any HTTP server can serve it. This is why our pages.yml workflow deploys the repo to GitHub Pages alongside the slides, and users get flatpak update for free.
- Full hands-on walkthrough: ideas/OSTree_tutorial.md.
In the wild: Wezterm uses flatpak-cargo-generator to read Cargo.lock and emit a generated-sources.json listing the exact crates to fetch inside the sandbox. It is the Rust analogue of ocio's FetchContent: a lockfile that makes the build reproducible inside a network-less environment.

--

## Permissions: Hole-Punching

Not trusting the host requires explicit re-declaration of every capability:

```yaml
# packaging/flatpak/org.packathon.ocio.yml
finish-args:
  - --socket=x11        # Display server X11
  - --socket=wayland    # Wayland compositor socket
  - --device=dri        # GPU acceleration (/dev/dri)
  - --share=ipc         # Shared memory (MIT-SHM)
```

<p class="fragment text-info" style="margin-top: 25px;">
<strong>Consequence:</strong> Complexity shifts from dynamic library symbol versions to IPC sockets and portal configuration.
</p>

Note:
Explain hole-punching the sandbox:
- Historical context (per Larsson): traditional Linux apps run unconfined under the user's permissions: any installed app can read, modify, or erase everything in $HOME and access other processes. Flatpak's sandbox inverts this model: no implicit access, every resource must be re-declared.
- When you decouple from the host, you break everything interactive by default. The application cannot see your screen, touch your GPU, or play sound.
- finish-args in the Flatpak manifest punches deliberate holes:
  - sockets for X11/Wayland allow drawing windows.
  - /dev/dri allows hardware GPU acceleration.
  - --share=ipc allows fast shared-memory buffer transfers (MIT-SHM).
- Takeaway: Packaging complexity is never eliminated; it is conserved. Instead of debugging ELF DT_NEEDED symbol clashes, we now configure IPC sockets and XDG desktop portals.

--

## Broke over night

<div class="center-card">
  <img src="image/tuple_flatpak.jpg" alt="Tuple Flatpak story: gitlab.gnome.org/GNOME/gtk/-/issues/6359" style="max-height: 480px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
  <p style="font-size: 0.6em;"><a href="https://www.youtube.com/watch?v=4y1B8tFoy-k&amp;t=1018s" target="_blank">youtube.com/watch?v=4y1B8tFoy-k</a> · <a href="https://gitlab.gnome.org/GNOME/gtk/-/issues/6359" target="_blank">gitlab.gnome.org/GNOME/gtk/-/issues/6359</a></p>
</div>

Note:
Jonathan Marler (Tuple) uses this as an example of "adopting problems you cannot fix":
- January 2024: users report that Tuple's screen annotations on Linux are suddenly invisible. Tuple had shipped no code for weeks. The GNOME Flatpak runtime had updated itself in the background.
- Silent failure: GTK printed no error and no warning. The developers found out only when users complained.
- Marler found the runtime version that broke it, wrote a minimal test app that shows broken window alpha blending, and filed GTK issue #6359.
- Two months later, another contributor used that test app to bisect GTK: a performance optimization commit had removed alpha blending support by accident.
- The official GTK fix took four months.
- Result: Marler dropped GTK and Flatpak. The Linux app is now a single static binary built with Zig, with WebRTC, PipeWire and the Wayland/X11 protocols bundled, so system updates can no longer break it.
- Takeaway: the runtime is a dependency you do not control. It updates on its own schedule, not on yours.

--

## Bottles: Flatpak Only

<div class="grid-2" style="align-items: center; gap: 40px;">
<div class="center-card">
  <img src="image/bottles_pr_comment.jpg" alt="Bottles maintainer comment on issue #4629" style="max-height: 440px; width: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
  <p style="font-size: 0.5em; margin: 4px 0;"><a href="https://github.com/bottlesdevs/Bottles/issues/4629#issuecomment-5182539674" target="_blank">github.com/bottlesdevs/Bottles/issues/4629</a></p>
</div>
<!-- .element: class="fragment" -->
<div class="center-card">
  <img src="image/bottles_rant.png" alt="Please don't unofficially ship Bottles in distribution repositories" style="max-width: 100%; height: auto; border-radius: 8px; box-shadow: 0 4px 16px rgba(0, 0, 0, 0.5);" />
  <p style="font-size: 0.5em; margin: 4px 0;"><a href="https://usebottles.com/blog/2022-06-07-an-open-letter.md" target="_blank">usebottles.com/blog/an-open-letter</a></p>
</div>
<!-- .element: class="fragment" -->
</div>

---

## Release: Artifact vs Channel

> *"CPack outputs multiple formats in one command. But a file is not a distribution channel."*

<div class="grid-2 fragment" style="margin-top: 25px;">
<div class="box-danger">

#### CPack (Local Artifact)
* Compiles on developer's dirty host
* Bakes local paths &amp; toolchains into metadata
* Zero cryptographic provenance or trust

</div>
<div class="box-success">

#### Build Services (OBS / Koji)
* **Isolated chroots** (network disabled during build)
* Automatic rebuilds triggered by dependency updates
* Automated policy linting (`rpmlint`) &amp; key signing

</div>
</div>

<p class="fragment text-info" style="margin-top: 25px;">
<strong>Two real pipelines</strong>: <a href="https://github.com/opentofu/opentofu" target="_blank">OpenTofu</a> (Go, GoReleaser, triple-signed) &middot; <a href="https://github.com/wezterm/wezterm" target="_blank">Wezterm</a> (Rust, per-distro, unsigned)
</p>

Note:
The central thesis of Act 3:
- Producing a .deb or .rpm with CPack or alien is technically easy, but it produces an orphaned artifact.
- The Dirty Host problem: when you build on your workstation, you risk baking host-specific paths, uncommitted patches, or private compiler flags into the package header.
- True software distribution requires trusted build infrastructure (Open Build Service, Koji, Launchpad):
  1. Hermetic builds in pristine chroots with no internet access.
  2. The dependency graph automatically triggers rebuilds when shared libraries are updated.
  3. Quality gates (rpmlint, test suites) and automated GPG signing by secured hardware/keys.

--

## Updates: Channel vs Format

Update capabilities are governed by the **channel**, not the file format:

* <!-- .element: class="fragment" --> `.deb` / `.rpm` via repository: Native OS updates (`apt upgrade`, `zypper dup`).
* <!-- .element: class="fragment" --> Manually installed package (`dpkg -i` / `rpm -i`): Orphaned artifact; no future security patches.
* <!-- .element: class="fragment" --> Flatpak via an OSTree repository (Flathub or self-hosted on GitHub Pages): block-level static deltas, atomic updates.
* <!-- .element: class="fragment" --> AppImage: Static by default; requires a `.upd_info` ELF note pointing to a `zsync` control file.

<p class="fragment text-danger" style="margin-top: 25px;">
<em>A binary without an update channel is a perpetual security liability.</em>
</p>

Note:
The software lifecycle paradox:
- A package format is just a static snapshot in time. An update mechanism is an ongoing maintenance relationship.
- When a user downloads a .deb or .rpm from a GitHub release and runs dpkg -i or rpm -i, that package is orphaned: no repository index knows about it, and it will never be patched automatically by the system.
- Flatpak solves this via OSTree: updates are content-addressed and downloaded as atomic binary deltas (only changed blocks are transferred).
- The channel does not have to be Flathub: an OSTree repository is just a static file tree (commits + summaries in archive-z2 format). That is why the same mechanism works on GitHub Pages: every push to main produces a new signed commit, and the user picks it up with a plain flatpak update.
- AppImage is completely standalone by default. Updating requires embedding a .upd_info ELF note into the binary pointing to a zsync control file on a remote server.
- The fundamental security rule: shipping a binary without an update path means vulnerabilities remain on user machines indefinitely.
In the wild: Wezterm implements exactly this mechanism. ci/appimage.sh sets UPDATE_INFORMATION with the gh-releases-zsync|wez|wezterm|latest|WezTerm-*.AppImage.zsync scheme, and the .zsync sidecar is uploaded next to the AppImage on GitHub Releases. The AppImage self-updates incrementally from there.

--

## Signatures: Integrity &amp; Origin

* `--allow-unsigned-rpm`: no proof of origin, scriptlets run as **root**

| Ecosystem | Signature Target | Runtime Validation |
|---|---|---|
| **APT** | Repo metadata | Mandatory pre-unpack |
| **RPM** | Package header | GPG keyring check |
| **Flatpak** | OSTree commit | Validated on every pull |
| **AppImage** | Embedded ELF block | **No automatic check** |

<p class="fragment" style="margin-top: 25px;">
<strong>2026</strong>: <em>Sigstore / Keyless</em> for CI; GPG keyrings still mandatory in distros.
</p>

<p class="fragment" style="margin-top: 15px;">
<strong>In production</strong>: OpenTofu signs 3 ways (GPG internal + detached + cosign); Wezterm SHA256 only
</p>

Note:
The security implications of signatures:
- In the live demo, we had to pass --allow-unsigned-rpm. In production, this is dangerous: RPM and DEB packages can contain maintainer scriptlets that execute as root.
- Installing an unsigned package is equivalent to running curl ... | sudo bash.
- Architectural differences in verification:
  1. APT verifies the repository metadata first; individual .deb files are validated against sha256 sums inside the signed Release file.
  2. RPM signs the header and payload directly within the package file itself; zypper/rpm verifies this against imported GPG keys.
  3. Flatpak cryptographically verifies OSTree commits and summaries on each pull.
  4. AppImage supports embedded digital signatures, but userspace execution (chmod +x && ./app) never enforces validation automatically.
- Modern trend: Sigstore and cosign provide keyless provenance for upstream binaries, but distros continue to mandate GPG trust webs.
In the wild: OpenTofu signs every artifact three ways: GPG inside the package (nFPM), detached GPG (.gpgsig), and cosign/Sigstore (.sig + .pem). Wezterm does not sign: SHA256 per file only. The choice is a trade-off: OpenTofu trades breadth for strong signing; Wezterm trades signing for native per-distro packaging.

--

## SBOM: The Supply Chain Paradox

* Modern languages (Rust, Go): deterministic lockfiles (`Cargo.lock`, `go.sum`).
* **In C with CMake, there is no universal lockfile**:
  * `raylib` vendored at build time via Git (`FetchContent`, static archive).
  * System stack (X11, OpenGL, glibc) resolved dynamically at runtime by the distro.

Note:
The SBOM reality in systems software:
- Developers coming from Rust, Go, or modern Python expect lockfiles that pin every transitive dependency to an exact cryptographic digest.
- In C and CMake, no universal lockfile exists.
- In ocio, our dependency graph is split into two halves:
  1. Build-time: raylib is fetched via Git (FetchContent) and statically linked into the binary.
  2. Runtime: X11, OpenGL, and libc are completely absent from the source repository - they are resolved dynamically by the host at launch.
- The C SBOM Paradox: dependencies are split across build time and install time. A complete SBOM cannot be deduced from source code alone - it requires observing the build inside an isolated build service.
- You cannot generate an accurate Software Bill of Materials just by scanning git. You must capture the hermetic build environment (SPDX / CycloneDX generated inside OBS/Koji).
In the wild: Wezterm (Rust) has exactly the lockfile the slide says C lacks: Cargo.lock, vendored with cargo vendor --locked --versioned-dirs, and flatpak-cargo-generator that translates it into generated-sources.json for the sandboxed build. The paradox is specific to C with CMake, not to packaging in general.

---

## Synthesis: The Responsibility Matrix

| Format | Who Resolves Dependencies | Host Coupling | Model |
|---|---|---|---|
| **Tarball** | Developer (static) + Host (dynamic) | Undefined / Fragile | Direct `execve` |
| **`.deb` / `.rpm`** | **Distribution** (SAT solver) | Full | Native `execve` on `/usr` |
| **AppImage** | **Bundle** (SquashFS payload) | Loose (glibc/FUSE) | FUSE mount + `execve` |
| **Flatpak** | **Shared Runtime** (Freedesktop) | Decoupled | Bubblewrap + Portals |
| **OCI Container** | **Complete Userspace Image** | Minimal (kernel/DRI) | Namespaces + cgroups |

<p class="text-info" style="margin-top: 25px;">
<em>Every packaging choice arbitrates responsibility between user, developer, and maintainer.</em>
</p>

Note:
The grand conclusion of the format analysis:
- There is no single "best" format. Each represents an engineering trade-off about who pays the cost of complexity:
  1. Distro delegation (RPM/DEB): Maintainers and SAT solvers pay the cost in packaging effort. The system gains shared pagecache, minimal payloads, and unified security patches.
  2. Single-file bundling (AppImage): The developer pays by bundling libraries; the user gains zero-install simplicity.
  3. Sandboxed runtimes (Flatpak): Flathub and runtime maintainers manage the base stack; packagers manage hole-punching portals.
  4. Containerization (OCI): Complete isolation, but requires shifting entire operating system userspaces.
- Conservation of complexity: You cannot make software packaging simpler; you can only choose which actor in the supply chain bears the burden.

--

## Metrics

| Format | Artifact | Installed | Host Closure | Startup (CLI / GUI) | RAM |
|---|---|---|---|---|---|
| **Raw Binary** | 1.2 MB | 1.2 MB | | 3.8 ms / 123 ms *(base)* | 78 MiB |
| **RPM** | 486 KB | 1.27 MB | 36 pkgs / 226 MiB | = native | 78 MiB |
| **DEB** | 436 KB | 1.26 MB | 41 pkgs / 217 MB | = native | 78 MiB |
| **AppImage** | 1.34 MiB | 1.34 MiB | Host GL/X11 + FUSE | +10 ms / +5 ms | 83 MiB |
| **Flatpak** | 480 KB | 1.2 MB | ~1.1 GB runtime | +113 ms / +124 ms | 90 MiB |
<!-- .element: style="font-size: 0.68em; line-height: 1.2;" -->

Note:
Empirical measurements from the spike benchmark (warm cache, medians under Xvfb + llvmpipe):
- Systems trade-off: Delegation minimizes payload and startup by relying on the host OS; sandboxing buys portability at the price of launcher latency and runtime duplication.
- Measurement conditions: Flatpak startup toll (+113 ms) is dominated by the launcher: D-Bus proxy & helpers (namespaces: ~6 ms). Measured warm-cache under Xvfb/llvmpipe.
- Disk delegation paradox: A 486 KB RPM or 436 KB DEB asks the host for ~220 MiB of dependencies (roughly 450x its own size). Delegation does not eliminate dependencies; it shifts them to packages shared across the system.
- Flatpak runtime: The 480 KB bundle requires a ~1.1 GB runtime (Platform 669 MB + GL 462 MB), shared per branch and deduplicated by OSTree.
- AppImage floppy callback: At 1,406,364 bytes, the AppImage fits on the physical 1.44 MB floppy disk from the opening gag with room to spare! But it fits only because it bundles nothing but the app: OpenGL, X11, and glibc still come from the host.
- Startup overhead: AppImage adds only ~10 ms (CLI) and ~5 ms (GUI), virtually imperceptible. Flatpak adds a fixed toll of ~115 ms. Crucially, kernel namespaces account for only ~6 ms of that (bare bwrap: 9.7 vs 4.0 ms); the rest is the flatpak run orchestration (3 bwrap stages, xdg-dbus-proxy, session helpers, D-Bus round trips).
- RAM: Memory footprint is nearly identical across all formats (78 to 90 MiB PSS, within 15%). Software Mesa (llvmpipe) dominates everything; the packaging format barely impacts runtime RAM.
- Core takeaway: There is no cost-free packaging on Linux. You choose which actor in the supply chain bears the burden.

--

## Boundaries &amp; Deliberate Scope

<div class="grid-2">
<div>

### What We Left Out
* **Snap**: `snapd` daemon &amp; Ubuntu AppArmor ties
* **Nix / Guix**: Purely functional store (`/nix/store`)
* **Arch / AUR**: Build recipes, not distributed binaries

</div>
<div>

### The GLIBC Trap
* AppImages built on modern distros fail on older LTS systems
* **Remediation**: Build bundles inside an older LTS container

</div>
</div>

<p class="text-warn fragment" style="margin-top: 30px;">
<em>These are real-world systems boundaries, not oversights.</em>
</p>

Note:
Explain the conscious boundaries of the presentation:
- Snap: Requires a persistent privileged daemon (snapd), has hard ties to Canonical's backend, and relies on kernel AppArmor integration not present on all Linux distributions.
- Nix and GNU Guix: Truly fascinating declarative systems, but their content-addressed /nix/store model represents an entirely different operating system paradigm worthy of its own conference talk.
- Arch AUR: User-maintained PKGBUILD recipes that compile from source on the user's machine, not pre-built binary distribution.
- The GLIBC baseline lesson: Emphasize that bundling application libraries does not free you from the C library. If you compile an AppImage on Fedora 41 or openSUSE Tumbleweed, it will not run on Ubuntu 20.04 or SLE 15. The industry best practice is to compile AppImages inside a CentOS 7 or Debian oldstable container.

---

## Three Perspectives, One Binary

<div class="grid-3" style="text-align: center; font-size: 1.4em; margin-top: 40px;">
  <p><strong>User</strong></p>
  <p><strong>Developer</strong></p>
  <p><strong>Maintainer</strong></p>
</div>

Note:
Closing the loop on the triad introduced at the start of the talk.
Let the audience drive the discussion: what did each perspective gain or lose
with each format we covered?

---

## Q&amp;A

<div class="grid-2" style="align-items: center; max-width: 700px; margin: 40px auto 0 auto;">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&amp;data=https://michelepagot.github.io/packathon/" alt="Repository QR Code" style="border-radius: 8px; border: 2px solid rgba(255,255,255,0.3);" />
  <div>
    <p><strong>Slides &amp; Code:</strong></p>
    <p><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
    <p><a href="https://github.com/michelepagot/packathon" target="_blank">github.com/michelepagot/packathon</a></p>
    <p class="text-success" style="margin-top: 20px;"><strong>Open Q&amp;A</strong></p>
  </div>
</div>

Note:
Concluding the talk:
- Thank the audience for their time.
- Remind them that all container build recipes, specs, and demo scripts are completely open source and reproducible in the repository.
- Invite questions regarding distro packaging (RPM/DEB), portable bundles (AppImage), desktop sandboxing (Flatpak), or build services (OBS).

