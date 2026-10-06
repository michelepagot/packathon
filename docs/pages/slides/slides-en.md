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

`$ ocio`

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
Declared requirements vs. Host reality:
"How do we diagnose what went wrong?
`readelf -d` inspects the binary file itself to see what dependencies were recorded when it was compiled.
`ldd` asks the dynamic linker to simulate resolving those dependencies on the current host system.
On the build system, all dependencies were present in the local cache. On the target system, the required libraries are absent, so ldd reports 'not found'."

Under the hood:
1. `readelf -d` directly reads the `.dynamic` section: `DT_NEEDED` records the dynamic dependencies registered by the linker. Notice Raylib is not listed because in our default build it is statically embedded into `.text`. But Raylib's GLFW backend pulls in `libOpenGL.so.0` and `libGLX.so.0` (libglvnd, not legacy libGL).
2. `ldd` is a shell script wrapper executing `ld.so` with `LD_TRACE_LOADED_OBJECTS=1`. It searches the host filesystem and `/etc/ld.so.cache`.
   Result: `libOpenGL.so.0` and `libGLX.so.0` are reported as "not found".

Showcase commands:
`readelf -d ./ocio | grep NEEDED` (the compile-time dependency list)
`ldd ./ocio` (the host-time resolution check)

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
The build-time vs runtime contract:
"Why did the binary compile cleanly if it cannot run?
At build time, the compiler only needs header files (.h) to verify function signatures and symbol stubs to compute relocation offsets. It does not verify that functional shared libraries will be present on the target host.
At runtime, the binary requires the concrete shared libraries (.so), an active display server (X11 or Wayland), and hardware GPU driver modules."

Why not link 100% statically (`gcc -static`) like Go or Rust?
- We tested this exact experiment (Variant 7): GNU ld refuses immediately with: `attempted static link of dynamic object '/usr/lib64/libOpenGL.so'`.
- `libglvnd` provides no static `.a` archives on Linux distributions.
- More fundamentally: desktop GPU drivers on Linux are dynamic dispatchers. Hardware DRI drivers (Mesa: `iris_dri.so`, `radeonsi_dri.so`, `nvidia.so`) must be detected and loaded dynamically via `dlopen()` at runtime to match whatever graphics card is physically installed in the machine.
- Static glibc also breaks dynamic NSS plugins (`/etc/nsswitch.conf`).
- Takeaway: A desktop GUI application on Linux cannot be 100% static. In C, a dynamically linked binary is an incomplete contract that must be fulfilled by the host OS.

Showcase command:
`gmake -C build-07-attempt-static 2>&1 | grep "attempted static link"` (shows GNU ld refusing static OpenGL)

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
- Origin: Created in 1997 by Marc Ewing and Erik Troan (Red Hat).
- Nature: An archive with metadata carrying files and declaring formal dependencies.
- Adoption: The reference standard for openSUSE, SLE, Fedora, and RHEL (LSB standard).
- Daily CLI:
  * Inspect: rpm -qlp (files) and rpm -qp --requires (dependencies)
  * Install with package manager: zypper in or dnf in
  * Audit integrity: rpm -V (detects files altered compared to stored database digests)
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
$ xxd -l 96 -d dist/ocio-0.1.0-1.x86_64.rpm
00000000: edab eedb 0300 0000 0001 6f63 696f 2d30  ..........ocio-0
00000016: 2e31 2e30 2d31 0000 0000 0000 0000 0000  .1.0-1..........
00000032: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000048: 0000 0000 0000 0000 0000 0000 0000 0000  ................
00000064: 0000 0000 0000 0000 0000 0000 0001 0005  ................
00000080: 0000 0000 0000 0000 0000 0000 0000 0000  ................
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

* **Tool**: `rpmbuild` (from `rpm-build`)
* **Recipe**: The `.spec` file (`ocio.spec`)
* **Tree**: `SOURCES/`, `SPECS/`, `BUILD/`, `BUILDROOT/`, `RPMS/`, `SRPMS/`
* **Workflow**: `rpmbuild -ba ocio.spec`

Note:
How native RPMs are built:
- To build a native RPM, you need the source archive in SOURCES/ and the recipe in SPECS/.
- Running `rpmbuild -ba ocio.spec` reads the spec from SPECS/ and the tarball from SOURCES/.
- Executes prep, build, install into a staging root (BUILDROOT), and produces both the binary package (.rpm) and the source package (.src.rpm).
- The package manager does not build software; rpmbuild is the dedicated toolchain.

--

## Inside the .spec: Sections

* **Preamble**: `Name`, `Version`, `Release`, `License`, `Source0`
* **`%prep`**: Unpack sources and apply patches (`%autosetup`)
* **`%build`**: Compile the application (`%cmake`, `%cmake_build`)
* **`%install`**: Stage files into `BUILDROOT` (`%cmake_install`)
* **`%files`**: Manifest of files packaged into the CPIO payload

Note:
The structure of a spec file:
- Preamble: Package metadata, license, upstream URL, and source archives.
- %prep: Prepares the build directory, typically unpacking tarballs via %autosetup.
- %build: Invokes the buildsystem using distro macros (%cmake and %cmake_build).
- %install: Installs build artifacts into a clean temporary root (BUILDROOT) mirroring the system filesystem.
- %files: Explicit manifest of files from BUILDROOT to be bundled into the RPM payload. Any unpackaged file causes a build failure.

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

* **`find-requires`**: Automated scan of `BUILDROOT` binaries
* **`DT_NEEDED`**: Dynamic link &rarr; detected automatically
* **`dlopen()`**: Runtime loading &rarr; invisible to scanner
* **Generated contract**: Translates symbols &amp; `DT_NEEDED` &rarr; `Requires:`

Note:
Runtime dependency management:
- Nobody writes Requires: libc.so.6 manually in the spec file.
- After %install, rpmbuild executes the internal find-requires script over all ELF binaries in BUILDROOT.
- The dynamic duality:
  1. Standard linked libraries are listed in DT_NEEDED: find-requires reads them automatically and emits package requirements alongside glibc symbol baselines.
  2. Libraries loaded at runtime via dlopen() and function pointers: invisible to find-requires because they do not appear in the ELF dynamic section.

--

## CPack

* CMake built-in packaging: no handwritten `.spec` required
* Minimal configuration in `CMakeLists.txt`:

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

--

## The --as-needed Trap

* <!-- .element: class="fragment" --> Distro hardening: `%cmake` injects `-Wl,--as-needed` by default
* <!-- .element: class="fragment" --> Linker pruning &amp; `dlopen()` blind spot: Raylib dispatches OpenGL via pointers &rarr; `DT_NEEDED` dropped, `find-requires` misses it
* <!-- .element: class="fragment" --> Silent failure: installs 1 package (904 KiB) instead of 36 (53 MiB) &rarr; crashes at runtime

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
- The resulting RPM builds cleanly, but Zypper installs only 1 package (904 KiB) instead of 36 (53 MiB). The program starts, but crashes when initializing the window!
- The solution: the author must manually bridge the dlopen() blind spot by declaring virtual capabilities in ocio.spec with Requires:.

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

## How 1 Became 36: libsolv

* <!-- .element: class="fragment" --> Local contract: capability contract &rarr; `libOpenGL.so.0()(64bit)` (auto-detected or declared)
* <!-- .element: class="fragment" --> Repository graph: 30,000+ packages providing virtual capabilities and versions
* <!-- .element: class="fragment" --> Resolution engine: `zypper` / `dnf` delegates to `libsolv`
* <!-- .element: class="fragment" --> Boolean SAT: converts constraints into CNF clauses &rarr; computes transitive closure in ms

Note:
Why did installing our single RPM pull in 35 additional packages?
- Whether auto-extracted by find-requires (CPack build) or declared by the maintainer in .spec to overcome --as-needed, the package contract requires libOpenGL.so.0()(64bit).
- Abstract capabilities (SONAME) decouple the binary from concrete package names: any package providing libOpenGL.so.0()(64bit) (such as libglvnd) satisfies the contract.
- The low-level rpm tool cannot resolve this: raw rpm -i fails with missing dependencies.
- Frontends (Zypper / DNF) pass the repository catalog to libsolv, which queries its whatprovides index.
- libsolv translates dependency and conflict rules into Boolean Conjunctive Normal Form (CNF) clauses (e.g. A requires B -> NOT A OR B).
- In milliseconds, the CDCL SAT solver calculates a consistent package closure: on our minimal headless container, satisfying libglvnd cascades into Mesa, X11, and DRM libraries, resulting in exactly 36 packages.

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

## Cooking a DEB

* **Tool**: `dpkg-buildpackage` (from `dpkg-dev`) / `debuild`
* **Recipe**: The `debian/` directory inside the source tree
* **Tree**: Source root containing `debian/` metadata and rules
* **Workflow**: `dpkg-buildpackage -us -uc -b`
  * Drives build via `debian/rules` and Debhelper (`dh`)
  * Produces binary package (`.deb`) and changes file (`.changes`)

Note:
How native DEBs are built:
- In Debian, the recipe is not a single file like in RPM, but a dedicated debian/ directory inside the source tree.
- The primary build driver is dpkg-buildpackage (or the developer wrapper debuild).
- Running dpkg-buildpackage -us -uc -b builds the binary package without signing source or changes files.
- The build process is orchestrated by debian/rules, which delegates to the Debhelper sequencer (dh).
- Artifacts produced: the binary package (.deb), the build log, and the .changes file declaring package upload metadata.

--

## Inside debian/

* **`control`**: Package metadata, `Build-Depends`, and `Depends: ${shlibs:Depends}`
* **`rules`**: Executable Makefile driving the build lifecycle (`dh $@`)
* **`changelog`**: Canonical package version, release history & target distro
* **`copyright`**: Machine-readable licensing manifest (DEP-5 standard)
* **Debhelper (`dh`)**: Sequencer automating configure, build, staging & strip

Note:
The structure of a Debian recipe:
- debian/control: Declares package metadata, build-time dependencies (Build-Depends), and runtime dependencies using substitution variables like ${shlibs:Depends}.
- debian/rules: An executable Makefile. Modern packaging uses dh $@ to automate build steps (dh_auto_configure, dh_auto_build, dh_auto_install).
- debian/changelog: Authoritative for package version and release. In Debian, you do not set Version in control; dpkg-parsechangelog extracts it from the top entry.
- debian/copyright: Standardized DEP-5 manifest auditing licenses per file for DFSG compliance.
- Runtime resolution: dh_shlibdeps scans compiled ELF binaries, consults library .symbols files, and automatically populates ${shlibs:Depends}.

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

* *Simon Peter* (2004 *klik*, 2011)
* One app = one executable file
* Distro-agnostic portability, zero install (no root)

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

## Inside an AppImage: Stub &amp; SquashFS

* **ELF runtime stub**: small executable at the head of the file
* **SquashFS filesystem**: compressed payload appended directly to the stub
* **Mount &amp; Execute**: FUSE mounts to `/tmp/.mount_XXXXXX` and executes `AppRun`

```text
$ ./ocio-x86_64.AppImage --appimage-extract
$ ls -1 squashfs-root
AppRun
ocio.desktop
ocio.png
usr
```
<!-- .element: class="fragment" -->

Note:
Low-level mechanics of AppImage:
- An AppImage is an ELF binary followed immediately by a compressed SquashFS filesystem.
- When launched, the ELF runtime stub intercepts execution, mounts the embedded filesystem to a temporary directory in /tmp via FUSE, and executes the AppRun script inside the mount.
- AppRun sets LD_LIBRARY_PATH and launches the application.
- When terminated, the FUSE mount point is unmounted and removed.
- Demonstrating --appimage-extract proves that under the hood, it is a complete, self-sufficient filesystem root.
FUSE in a container (the demo runs in podman):
- Podman does not pass /dev/fuse, and the vanilla image has no fusermount3. A plain ./ocio.AppImage fails: "fuse: device not found ... Cannot mount AppImage, please check your FUSE setup".
- Solution 1, no FUSE: --appimage-extract-and-run (or APPIMAGE_EXTRACT_AND_RUN=1) unpacks to /tmp/appimage_extracted_* and runs AppRun from there. No image change, no extra privileges.
- Solution 2, real mount as on a desktop: podman run --device /dev/fuse --cap-add SYS_ADMIN, plus zypper in fuse3 (fusermount3) in the container. The mount appears on /tmp/.mount_ocio.A*.
- Either way, the next stop is libOpenGL.so.0: the AppImage does not bundle the GL stack, it uses the host one.

--

## Inside AppImage: The `EI_PAD` Trick

```text
$ hexdump -C -n 16 ocio-x86_64.AppImage
00000000  7f 45 4c 46 02 01 01 00  41 49 02 00 00 00 00 00  |.ELF....AI......|
```

| Byte Range | Field | Value | Purpose |
|:---:|:---:|:---:|:---|
| `00..03` | `EI_MAG` | `\x7fELF` | Standard ELF magic signature |
| `04..07` | Architecture | `02 01 01 00` | 64-bit, little-endian, System V ABI |
| **`08..0A`** | **`EI_PAD`** | **`41 49 02`** | **`AI\x02` (AppImage Type 2 magic)** |
| `0B..0F` | `EI_PAD` | `00 00 00...` | Remaining zeroed padding |

Note:
Dissecting the AppImage binary header:
- In Slide 9 we saw that every ELF binary begins with the 16-byte e_ident header.
- The ELF specification defines bytes 8 to 15 as EI_PAD: reserved padding intended for future ABI expansion, conventionally zeroed.
- AppImage Type 2 overwrites bytes 8, 9, and 10 with ASCII 'A', 'I', and 0x02.
- Why this is brilliant:
  1. Zero execution penalty: the OS kernel loader only checks bytes 0 to 3 (\x7fELF) and, like ld.so, ignores EI_PAD, so the file remains 100% executable machine code.
  2. Instant detection: desktop indexers, file managers, app managers and file(1) don't need to mount or scan the multi-megabyte SquashFS payload: reading 11 bytes gives instant identification, in O(1) time.
  3. Format versioning: generations are cleanly versioned, AI\x01 for legacy Type 1 (ISO 9660) vs AI\x02 for modern Type 2 (SquashFS + FUSE).
- The emulation caveat: Native kernels ignore EI_PAD, but container emulation (QEMU-user binfmt_misc) can trip on non-standard padding with ENOEXEC ("Exec format error"). This is why native ARM64 runners are required for reliable multi-arch builds.

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

Note:
An AppImage is a squashed directory tree, the AppDir:
- AppRun is the entry point (here a symlink to the binary).
- A .desktop file and its icon are required at the top level: appimagetool refuses to pack without them.
- usr/ is a small root filesystem: binary, bundled libraries, desktop file, icons, metainfo.
Two recipes, both in packaging/appimage/build-appimage.sh --method {linuxdeploy,appimagetool}:
- appimagetool by hand: we assemble the AppDir (CMake install, .desktop, icon, AppRun symlink). appimagetool only squashes the tree and prepends the runtime. It never looks at the dependencies: if the binary needs a library that is not on the host, nothing warns you.
- linuxdeploy (the script default): walks the DT_NEEDED tree, copies every library that is not on the AppImage excludelist into usr/lib, sets RUNPATH=$ORIGIN/../lib with patchelf, strips, and creates AppRun. appimagetool then packs the result.
- linuxdeploy and appimagetool are themselves AppImages. The builder images ship them pre-extracted, so they run without FUSE; the script downloads nothing and fails with install hints if a tool is missing.
Key message: "self-contained" is not a property of the format. It is a packaging job, and the next question is: what should go in the box?

--

## Cooking an AppImage: Step by Step

```bash
# 1. Build
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
```

```bash
# 2. Stage the AppDir
DESTDIR=AppDir cmake --install build --component ocio --prefix /usr
```
<!-- .element: class="fragment" -->

```bash
# 3. Bundle what the host is not expected to have
linuxdeploy --appdir AppDir --executable AppDir/usr/bin/ocio \
    --desktop-file ocio.desktop --icon-file ocio.png
```
<!-- .element: class="fragment" -->

```bash
# 4. Squash the AppDir and prepend the runtime
appimagetool --runtime-file /usr/lib/runtime-x86_64 AppDir ocio-x86_64.AppImage
```
<!-- .element: class="fragment" -->

Note:
The four steps that packaging/appimage/build-appimage.sh runs with the default --method linuxdeploy:
1. Build: a normal CMake Release build. Nothing AppImage-specific yet.
2. Stage: install only the ocio component (the default install also has raylib's dev files) into AppDir, with --prefix /usr because linuxdeploy expects the usr/ layout. This gives usr/bin/ocio plus the desktop file, icons and metainfo.
3. Bundle: linuxdeploy reads DT_NEEDED recursively, copies into usr/lib every library that is not on the excludelist, sets RUNPATH=$ORIGIN/../lib, strips, and creates AppRun and the top-level .desktop and icon links. For our default build it copies nothing: everything ocio needs is on the excludelist (next slide).
4. Pack: appimagetool turns the AppDir into a SquashFS image and prepends the type2 runtime, the ELF stub with the AI\x02 magic from the EI_PAD slide. We pass the runtime file explicitly, otherwise appimagetool downloads it at every build.
The hand recipe (--method appimagetool) skips step 3: we place AppRun, the .desktop file and the icon ourselves, and nobody checks the libraries.
All three tools (linuxdeploy, appimagetool, runtime) come pre-installed in the builder images; linuxdeploy and appimagetool are pre-extracted, so they run without FUSE.

--

## The Box Has an Edge

| Inside the box | Outside: the host |
|---|---|
| App binary &amp; assets | glibc: `libc`, `libm`, `ld.so` |
| Libraries the app brings | GL: `libOpenGL`, `libGLX`, `libGLdispatch` |
| | X11 / xcb, `libdrm`, ALSA |

The line is the AppImage **excludelist**: libraries assumed present on every desktop.
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
The excludelist (pkg2appimage/excludelist, applied by linuxdeploy) lists the libraries "we will assume to be present on the host system and hence should NOT be bundled inside AppImages". It contains glibc, the whole GL stack (libOpenGL, libGLX, libGLdispatch, libGL, libEGL, libdrm), X11/xcb and ALSA.
Why GL must stay outside: same argument as the Build vs. Runtime slide. GPU drivers are dynamic dispatchers that must match the host card; libglvnd loads libGLX_mesa or libGLX_nvidia from the host. A bundled Mesa works in a container and breaks on the NVIDIA proprietary driver or on a GPU newer than the bundled Mesa.
Our ocio: raylib is static, and DT_NEEDED is only libm, libOpenGL.so.0, libGLX.so.0, libc. All four are on the excludelist. So our AppImage is correct by the format's own rules: linuxdeploy finds nothing to bundle.
The error in the container is the edge of the box, not a bug in it. Installing libglvnd in the container recreates the desktop base system that AppImage assumes; on a real desktop it is already there.
The catch: AppImage never declares that base system. The excludelist is "a working document". Flatpak turns the same idea into an explicit, versioned runtime (bridge to Flatpak).
Side note: the AppImage built on Debian starts and prints --version in the same container. It is not a better box: --as-needed dropped GL from DT_NEEDED, so it fails later, when GLFW dlopen()s Xlib.

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
- Right: linuxdeploy copies libraylib into usr/lib and sets RUNPATH=$ORIGIN/../lib, so ld.so finds it inside the mount. libOpenGL and libGLX stay outside, as they should.
- Not a fix: installing raylib with the distro package manager. It turns the AppImage back into a binary that depends on the distro. On Tumbleweed it would not even work: the distro ships raylib 6.0, ocio was built against 5.5.
Takeaway: the fix for a broken box is inside the box, not on the host.
TO VERIFY before the talk: the exact soname, the error text and RUNPATH vs RPATH in the linuxdeploy output.

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

| Format | Artifact | Installed | Host Closure | Startup (CLI / GUI) | RAM |
|---|---|---|---|---|---|
| **Raw Binary** | 1.2 MB | 1.2 MB | | 3.8 ms / 123 ms *(base)* | 78 MiB |
| **RPM** | 486 KB | 1.27 MB | 36 pkgs / 226 MiB | = native | 78 MiB |
| **DEB** | 436 KB | 1.26 MB | 41 pkgs / 217 MB | = native | 78 MiB |
| **AppImage** | 1.44 MB | 1.44 MB | Host GL/X11 + FUSE | +10 ms / +5 ms | 83 MiB |
| **Flatpak** | 480 KB | 1.2 MB | ~1.1 GB runtime | +113 ms / +124 ms | 90 MiB |
<!-- .element: style="font-size: 0.68em; line-height: 1.2;" -->

Note:
Empirical measurements from the spike benchmark (warm cache, medians under Xvfb + llvmpipe):
- Systems trade-off: Delegation minimizes payload and startup by relying on the host OS; sandboxing buys portability at the price of launcher latency and runtime duplication.
- Measurement conditions: Flatpak startup toll (+113 ms) is dominated by the launcher: D-Bus proxy & helpers (namespaces: ~6 ms). Measured warm-cache under Xvfb/llvmpipe.
- Disk delegation paradox: A 486 KB RPM or 436 KB DEB asks the host for ~220 MiB of dependencies (roughly 450x its own size). Delegation does not eliminate dependencies; it shifts them to packages shared across the system.
- Flatpak runtime: The 480 KB bundle requires a ~1.1 GB runtime (Platform 669 MB + GL 462 MB), shared per branch and deduplicated by OSTree.
- AppImage floppy callback: At 1.44 MB (1,444,344 bytes), the AppImage fits on the physical 1.44 MB floppy disk from the opening gag! But it fits only because it bundles nothing but the app: OpenGL, X11, and glibc still come from the host.
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

