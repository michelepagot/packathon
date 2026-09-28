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

<div class="grid-2">
<div>

1. **Census**
2. **Perspectives**
3. **Dependencies**
4. **Formats**
5. **Delegation**: RPM &amp; DEB *(Demo)*

</div>
<div>

6. **AppImage**, **Flatpak**, **Permissions**
7. **Release** &amp; **Updates**
8. **Signatures** &amp; **SBOM**
9. **Synthesis**, **Metrics**, **Q&amp;A**

</div>
</div>

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
/ocio: error while loading shared libraries: libOpenGL.so.0:
cannot open shared object file: No such file or directory
```
<!-- .element: class="fragment" -->

Note:
Ask the audience the exit code: 127.

Test command in minimal container:
$ podman run --rm -v ./build/bin/ocio:/ocio:ro,Z registry.opensuse.org/opensuse/tumbleweed:latest /ocio

Stage handoff:
"We built the binary, put it on a USB drive or downloaded it from GitHub, and ran it on a clean system. Immediate runtime failure.
Who terminated the process? Did the application crash? Did the kernel abort?
Let us look at what actually happens under the hood when Linux launches a binary."

--

## Launch

`$ ocio`

1. **Shell**: `$PATH` lookup &rarr; `/usr/bin/ocio` <small>(`command -v ocio`)</small>
2. **Kernel**: `execve()` &rarr; `PT_INTERP` &rarr; `ld.so`
3. **ld.so**: `DT_NEEDED` &rarr; `/lib64/libOpenGL.so.0` found
4. `main()`

Note:
The exact execution sequence of an ELF on Linux:
1. The shell finds the binary through $PATH.
2. The kernel calls execve(), maps the ELF, and hands control to the interpreter (ld.so). The kernel succeeded without errors!
3. The dynamic linker (in userspace) scans the DT_NEEDED entries.
And here is the revelation: failing to find libOpenGL.so.0, ld.so prints the error and invokes exit_group(127).
4. main() is never reached. Our C code never executed a single instruction.

Bridge to the next slide:
"How is this possible? On the development machine it compiled without warnings and ran smoothly. How can a compiler produce a binary that dies before entering main()?"

--

## Build vs. Runtime

<div class="grid-2">
<div>

### Build-Time
* Consumed **once**
* Headers &amp; static libs
* Compiler &amp; tools

</div>
<div>

### Runtime
* Required **every run**
* Dynamic `.so` &amp; `glibc`
* Display &amp; GPU nodes

</div>
</div>

<p class="fragment text-info" style="margin-top: 35px;">
<em>In C, a dynamic binary is an incomplete contract with the host OS.</em>
</p>

Note:
Compiling cleanly does not mean having a self-sufficient application.
- At build-time, only declarations (headers) and symbol stubs are needed to produce the ELF.
- At runtime, concrete shared libraries (.so), the display server, and GPU drivers are required.
In C, a dynamically linked binary is an incomplete contract that must be fulfilled by the host machine at runtime.

Bridge to the next slide:
"If the binary is an incomplete contract... how do we verify exactly what this binary requires and what is missing on the host machine?"

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
How does this incomplete contract manifest?
1. readelf -d directly inspects the ELF header: DT_NEEDED records everything the compiler registered as dynamic dependencies.
2. ldd simulates the dynamic linker (ld.so) on the host: it searches the filesystem for each library.
Result: libOpenGL.so.0 and libGLX.so.0 are "not found".

Bridge to Formats:
"The binary requires these libraries, but the host system does not have them. How do we ship them alongside the program or ensure they are installed?
This is where packaging begins: every format on Linux adopts a fundamentally different strategy to bridge this gap."

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

* *Marc Ewing &amp; Erik Troan* (Red Hat, 1997)
* Archive with dependency metadata
* Enterprise &amp; distro standard (LSB)

<p class="fragment text-info" style="margin-top: 35px;">
<strong>Superpower:</strong> Delegates dependency resolution to the OS graph solver.
</p>

Note:
Introducing RPM:
- Origin: Created in 1997 by Marc Ewing and Erik Troan (Red Hat).
- Nature: An archive with metadata carrying files and declaring formal dependencies.
- Adoption: The reference standard for openSUSE, SLE, Fedora, and RHEL (LSB standard).
- Daily CLI:
  * Inspect: rpm -qlp (files) and rpm -qp --requires (dependencies)
  * Install with solver: zypper in or dnf in
  * Audit integrity: rpm -V (detects files altered compared to stored database digests)
- Superpower: Delegates to the distro's SAT graph solver.
Next we look at what is physically inside the .rpm file on disk.

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
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | file -
/dev/stdin: ASCII cpio archive (SVR4 with no CRC)
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | cpio -idmv
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```
<!-- .element: class="fragment" -->

Note:
file identifies the format from the magic bytes (ed ab ee db): "RPM v3.0" is the legacy lead format, still written by modern rpm for compatibility.
Anatomy of the file:
- Lead: fixed legacy block, mostly a magic number today.
- Signature: digests of header and payload, plus the GPG signature when present (ours has none).
- Header: all the metadata we query with rpm -q (name, version, Requires, Provides, file list with digests).
- Payload: the files themselves, in a cpio archive compressed with zstd (rpm -qp --qf '%{PAYLOADFORMAT} %{PAYLOADCOMPRESSOR}' prints "cpio zstd").
What is cpio:
- Unix archive format from the 1970s ("copy in / copy out"), same idea as tar: a flat sequence of (header + file data) records.
- No compression and no index of its own; compression is applied on top (zstd here).
- SVR4 "newc" variant: ASCII headers, magic "070701". The Linux kernel uses the same format for the initramfs.
How to extract it (fragment):
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

## Live Demo: RPM

RPM installation in a *vanilla* openSUSE Tumbleweed container:

```bash
$ podman run --rm -v "$PWD/dist/ocio-0.1.0-1.x86_64.rpm:/ocio.rpm:ro,Z" \
    registry.opensuse.org/opensuse/tumbleweed:latest \
    sh -c "zypper --non-interactive in --allow-unsigned-rpm /ocio.rpm && ocio --version"
```

<p class="text-warn" style="margin-top: 30px;">* <code>--allow-unsigned-rpm</code></p>

Note:
Run the live demo or display the command in terminal.
What zypper does, in order (visible in its output):
- Resolve: computes the 36 packages.
- Retrieve: downloads them (ocio itself from the "Plain RPM files cache").
- Verify: checks signatures. Here it cannot: our package is unsigned.
- Check for file conflicts: no two packages may own the same path.
- Install: unpack files into /usr, record every file in the RPM database.
Critical detail of the asterisk: --allow-unsigned-rpm. rpm -qi ocio shows "Signature: (none)" and "Build Host: e246f0b7ceaf" (a random container ID): nothing proves who built this package. This one ships no scriptlets (rpm -qp --scripts is empty), but the next unsigned RPM could, and scriptlets run as root. Foreshadow the Signatures section.

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
- The delegation cost: to install our 486 KB package, the SAT solver (libsolv) selected 36 packages from the repository for a total download of 52.6 MiB.
- The userspace contract is now fully satisfied by the distribution.

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

## DEB: Debian Distro Standard

* *Ian Murdock* (Debian, 1993)
* Strict policy &amp; FHS compliance
* Debian, Ubuntu &amp; Mint standard

<p class="fragment text-info" style="margin-top: 35px;">
<strong>Superpower:</strong> Exact symbol mapping via <code>dpkg-shlibdeps</code> and maintainer scriptlets.
</p>

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
$ dpkg-deb -I ocio_0.1.0_amd64.deb | grep Depends
 Depends: libc6 (>= 2.17), libgl1, libx11-6
```
<!-- .element: class="fragment" -->

Note:
Anatomy of a .deb file:
- Uses no proprietary container format: it is a standard Unix ar archive (the exact same format used by compilers for static libraries .a).
- Contains exactly three members:
  1. debian-binary: text string with format version ("2.0\n").
  2. control.tar: compressed archive with package metadata (control file, md5sums, postinst/prerm scriptlets).
  3. data.tar: compressed archive with the actual payload files unpacked onto the filesystem.
- dpkg-deb -I: inspects control metadata. Depends: libc6, libgl1, libx11-6 is populated automatically by dpkg-shlibdeps.

--

## Dialects

| Dimension | RPM Ecosystem | DEB Ecosystem |
|---|---|---|
| **Container** | CPIO (`zstd`) | Standard `ar` |
| **Base tool** | `rpm` | `dpkg` |
| **Package manager** | `zypper` / `dnf` | `apt` |
| **Deps generator** | `find-requires` | `dpkg-shlibdeps` |
| **Inspect files** | `rpm -qlp` | `dpkg-deb -c` |
| **Inspect metadata** | `rpm -qp --requires` | `dpkg-deb -I` |
| **Audit integrity** | `rpm -V` | `debsums` |
<!-- .element: style="font-size: 0.76em;" -->

Note:
Two dialects, identical engineering principles:
- Containers: RPM uses a compressed CPIO payload (zstd or gzip); DEB uses a classic Unix ar archive containing control.tar (metadata) and data.tar (payload).
- Dependency generation: find-requires scans ELF DT_NEEDED entries; dpkg-shlibdeps maps symbols via library symbols files.
- Inspection: rpm -qlp FILE.rpm vs dpkg-deb -c FILE.deb for files; rpm -qp --requires vs dpkg-deb -I for metadata.
- Integrity: rpm -V PACKAGE audits files against the RPM database; debsums PACKAGE verifies files against stored md5sums.
- Resolution: Both delegate to a high-level solver (zypper/dnf with libsolv, apt with its dependency engine).

--

## Delegation

* **Philosophy**: Package carries payload only; dependencies delegated to the distribution.

<div class="grid-2 fragment" style="margin-top: 25px;">
<div class="box-success">

#### Advantages

* Minimal payload: **486 KB** (52.6 MiB delegated)
* Shared libraries: patched once for all apps
* Ownership &amp; verification: `rpm -qf`, `rpm -V`

</div>
<div class="box-danger">

#### Constraints

* ABI coupling: `libm.so.6(GLIBC_2.43)`
* Strict packaging policies (FHS, scriptlets)
* One build per target distribution

</div>
</div>

Note:
Recap: every bullet refers directly to what the audience has just witnessed:
- 486 KB vs 52.6 MiB: the distribution carries the weight of the runtime dependency graph.
- Shared libraries: libglvnd is shared across all GL apps; a security vulnerability is patched once in the OS.
- GLIBC_2.43 in the Requires: this package installs only where glibc >= 2.43 exists. Built on Tumbleweed, it is useless on an older LTS.
- The price of delegation is tight host coupling.

---

## AppImage: Portable Single-File

<div class="grid-2">
<div>

### What It Is
* One app = one executable file
* *Simon Peter* (2004 *klik*, 2011)
* Zero installation, no root needed

</div>
<div>

### Daily CLI
* **Run**: `chmod +x ./file.AppImage && ./file.AppImage`
* **Extract**: `./file.AppImage --appimage-extract`
* **Fallback**: Runs without FUSE via extracted root

</div>
</div>

<p class="fragment text-info" style="margin-top: 30px;">
<strong>Superpower:</strong> Instant portability via userspace FUSE mount.
<br><span class="text-warn">The Catch:</span> Bundles apps, not glibc ("build on oldest target distro").
</p>

Note:
Introduce AppImage via the 4-lens framework:
1. What it is: Created by Simon Peter (probono) in 2004 under the name klik, rebranded in 2011 to AppImage. Core concept: an application should be a single double-clickable file.
2. Superpower: Instant portability. Requires zero privileges, leaves no trace in system directories, and runs entirely in userspace using FUSE.
3. Common workflow: Download, chmod +x, run. When FUSE is unavailable (e.g. inside locked containers), --appimage-extract provides an immediate fallback.
4. The GLIBC paradox: AppImage bundles application libraries, but depends on the host's glibc and kernel. If built on a cutting-edge distro, newer GLIBC symbol versions prevent it from running on older distros. The golden rule: build on the oldest distro you plan to support.

--

## Inside an AppImage: Stub &amp; SquashFS

* **ELF runtime stub**: small executable at the head of the file
* **SquashFS filesystem**: compressed payload appended directly to the stub
* **Mount &amp; Execute**: FUSE mounts to `/tmp/.mount_XXXXXX` and executes `AppRun`

```text
$ ./ocio-x86_64.AppImage --appimage-extract
$ ls -1 squashfs-root
AppRun
ocio
ocio.desktop
ocio.png
```
<!-- .element: class="fragment" -->

Note:
Low-level mechanics of AppImage:
- An AppImage is an ELF binary followed immediately by a compressed SquashFS filesystem.
- When launched, the ELF runtime stub intercepts execution, mounts the embedded filesystem to a temporary directory in /tmp via FUSE, and executes the AppRun script inside the mount.
- AppRun sets LD_LIBRARY_PATH and launches the application.
- When terminated, the FUSE mount point is unmounted and removed.
- Demonstrating --appimage-extract proves that under the hood, it is a complete, self-sufficient filesystem root.

---

## Flatpak: Sandboxed Desktop Runtime

<div class="grid-2">
<div>

### What It Is
* Universal sandboxed desktop standard
* *Alexander Larsson* (2015 *xdg-app*, 2016)
* Backed by the Flathub ecosystem

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
1. What it is: Created in 2015 by Alexander Larsson at Red Hat (originally xdg-app). Has become the de-facto standard for cross-distro desktop apps, centered around Flathub.
2. Superpower: Complete decoupling. The application never sees host /usr. Instead, it runs inside an unprivileged Bubblewrap container with namespaces and seccomp filtering.
3. Common workflow: Install from remotes (Flathub), run, inspect the interior environment with --command=sh, and dynamically tweak permissions with flatpak override.
4. The Catch: Because the sandbox is isolated by default, every access to the outside world must be explicitly declared.

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
- When you decouple from the host, you break everything interactive by default. The application cannot see your screen, touch your GPU, or play sound.
- finish-args in the Flatpak manifest punches deliberate holes:
  - sockets for X11/Wayland allow drawing windows.
  - /dev/dri allows hardware GPU acceleration.
  - --share=ipc allows fast shared-memory buffer transfers (MIT-SHM).
- Takeaway: Packaging complexity is never eliminated; it is conserved. Instead of debugging ELF DT_NEEDED symbol clashes, we now configure IPC sockets and XDG desktop portals.

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

* **`.deb` / `.rpm` via repository**: Native OS updates (`apt upgrade`, `zypper dup`). <!-- .element: class="fragment" -->
* **Manually installed package (`dpkg -i` / `rpm -i`)**: Orphaned artifact; no future security patches. <!-- .element: class="fragment" -->
* **Flatpak via Flathub**: **OSTree** repository; block-level static deltas (atomic updates). <!-- .element: class="fragment" -->
* **AppImage**: Static by default; requires `.upd_info` in ELF header to enable `zsync` updates. <!-- .element: class="fragment" -->

<p class="fragment text-danger" style="margin-top: 25px;">
<em>A binary without an update channel is a perpetual security liability.</em>
</p>

Note:
The software lifecycle paradox:
- A package format is just a static snapshot in time. An update mechanism is an ongoing maintenance relationship.
- When a user downloads a .deb or .rpm from a GitHub release and runs dpkg -i or rpm -i, that package is orphaned: no repository index knows about it, and it will never be patched automatically by the system.
- Flatpak solves this via OSTree: updates are content-addressed and downloaded as atomic binary deltas (only changed blocks are transferred).
- AppImage is completely standalone by default. Updating requires embedding a .upd_info section into the ELF binary pointing to a zsync control file on a remote server.
- The fundamental security rule: shipping a binary without an update path means vulnerabilities remain on user machines indefinitely.

--

## Signatures: Integrity &amp; Origin

Why `--allow-unsigned-rpm` is unacceptable: no proof of origin, and scriptlets execute as **root**.

| Ecosystem | Signature Target | Runtime Validation |
|---|---|---|
| **APT** | Repository metadata (`Release.gpg`) | Mandatory pre-unpack verification |
| **RPM** | Package header + `repomd.xml` | GPG keyring verification in RPM database |
| **Flatpak** | Commit &amp; Summary in OSTree | Cryptographic validation on every pull |
| **AppImage** | Embedded ELF block (`--appimage-signature`) | **No automatic validation** at runtime |

<p class="fragment" style="margin-top: 25px;">
<strong>2026 Reality</strong>: <em>Sigstore / Keyless</em> (OIDC) for upstream CI releases; traditional GPG keyrings remain mandatory for distro package managers.
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

--

## SBOM: The Supply Chain Paradox

* Modern languages (Rust, Go): deterministic lockfiles (`Cargo.lock`, `go.sum`).
* **In C with CMake, there is no universal lockfile**:
  * `raylib` vendored at build time via Git (`FetchContent`, static archive).
  * System stack (X11, OpenGL, glibc) resolved dynamically at runtime by the distro.

<div class="fragment callout" style="margin-top: 25px;">
<strong>The C SBOM Paradox</strong>: Dependencies are split across build time and install time. A complete SBOM cannot be deduced from source code alone - it requires observing the build inside an isolated build service.
</div>

Note:
The SBOM reality in systems software:
- Developers coming from Rust, Go, or modern Python expect lockfiles that pin every transitive dependency to an exact cryptographic digest.
- In C and CMake, no universal lockfile exists.
- In ocio, our dependency graph is split into two halves:
  1. Build-time: raylib is fetched via Git (FetchContent) and statically linked into the binary.
  2. Runtime: X11, OpenGL, and libc are completely absent from the source repository - they are resolved dynamically by the host at launch.
- You cannot generate an accurate Software Bill of Materials just by scanning git. You must capture the hermetic build environment (SPDX / CycloneDX generated inside OBS/Koji).

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
<em>Every packaging choice arbitrates responsibility between developer, maintainer, and operating system.</em>
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

| Solution | Disk Footprint (Payload + Deps) | Cold Startup Overhead |
|---|---|---|
| **Raw Binary** | *[TBD: size MB]* | 0 ms (Baseline: *[TBD ms]*) |
| **Native .rpm / .deb** | *[TBD: size KB]* (+ host libraries) | ~0 ms (Shared in pagecache) |
| **Standalone Tarball** | *[TBD: size MB]* | ~0 ms |
| **AppImage** | *[TBD: size MB]* | +*[TBD ms]* (FUSE &amp; SquashFS) |
| **Flatpak** | *[TBD: size MB]* (+ ~500 MB base) | +*[TBD ms]* (bwrap &amp; IPC portals) |
| **OCI Container** | *[TBD: size MB]* | +*[TBD ms]* (Overlayfs &amp; rootless) |
| **Source Build** | *[TBD: size MB]* (+ toolchain) | 0 ms (post-compilation) |

<p style="margin-top: 25px;">
<strong>Systems trade-off:</strong> Portability and sandboxing come at the cost of cold-start latency and duplicate disk space.
</p>

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

