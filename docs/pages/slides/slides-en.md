# Packathon

### Software Packaging &amp; Distribution on Linux

<p style="color: #888; font-size: 0.7em; margin-top: 30px;">Linux Day Trieste 2026</p>

Note:
Leave ocio running live on a secondary screen or split window.
Opening gag:
"The organizers invited me here today to talk about packaging and release engineering. But let's be honest: I'm really here to show you my 15-minute vibecoded app that will change your life forever."
Move the mouse, show the eye tracking the cursor, press V to toggle version.
"Now that you've seen it, I know you all want it. But I don't have a server or a distribution pipeline. So I decided to distribute it the classic way."
Pull the physical 3.5" floppy disk out of your backpack:
"If you leave me your postal address and a stamp after the talk, I will mail you a copy."

---

## Slides

<div style="margin-top: 30px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 15px;">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=https://michelepagot.github.io/packathon/" alt="Slide QR Code" style="border-radius: 12px; border: 3px solid rgba(255,255,255,0.4);" />
  <p style="font-size: 0.85em; margin: 0;"><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
  <div style="margin-top: 5px;">
    <a href="https://codespaces.new/michelepagot/packathon?quickstart=1" target="_blank" rel="noopener noreferrer">
      <img src="https://github.com/codespaces/badge.svg" alt="Open in GitHub Codespaces" style="border: none; box-shadow: none; vertical-align: middle;" />
    </a>
  </div>
</div>

Note:
Pause to allow the audience to scan the QR code.

---

## Speaker

<div style="margin-top: 40px; font-size: 1.1em; line-height: 1.8;">

* **Michele Pagot**
* **SUSE**: Quality Engineering (QE)
* GitHub: [`@michelepagot`](https://github.com/michelepagot) · [`@mpagot`](https://github.com/mpagot)

</div>

---

## Disclaimer

<div style="font-size: 0.85em; text-align: left; margin-top: 30px; line-height: 1.8;">

* Not a distribution package maintainer by trade.
* Engineering investigation into upstream packaging constraints before software lands on test benches.

</div>

Note:
"I am not a package maintainer by trade. I work at the receiving end of release pipelines: testing, validating, and auditing artifacts on complete systems. This talk was born to understand what happens upstream before software reaches our test benches."

---

## Agenda

<!-- .slide: style="font-size: 0.68em;" -->

<div style="display: flex; gap: 50px; text-align: left; max-width: 900px; margin: 30px auto 0 auto; line-height: 1.8;">
<div style="flex: 1;">

1. **Census**
2. **Perspectives**
3. **Dependencies**
4. **Formats**
5. **Delegation**: RPM &amp; DEB *(Demo)*

</div>
<div style="flex: 1;">

6. **AppImage**, **Flatpak**, **Permissions**
7. **Release** &amp; **Updates**
8. **Signatures** &amp; **SBOM**
9. **Synthesis**, **Metrics**, **Q&amp;A**

</div>
</div>

---

## Census

<!-- .slide: style="font-size: 0.88em;" -->

<ol style="line-height: 1.8;">
  <li class="fragment">Who uses Linux daily?</li>
  <li class="fragment">Who installs software exclusively via official distro repos?<br>
  <small style="color: #aaa;">(APT, Zypper, DNF, Pacman, AUR... Emerge, Slackpkg, urpmi)</small></li>
  <li class="fragment">Who uses universal formats: Flatpak, AppImage, or Snap?</li>
  <li class="fragment"><code>curl | sh</code></li>
  <li class="fragment">Who regularly compiles from source?<br>
  <small style="color: #aaa;">(<code>git clone &amp;&amp; cmake &amp;&amp; make &amp;&amp; sudo make install</code>)</small></li>
</ol>

Note:
Go through the 5 questions looking at the room:
1. 100% hands.
2. Official repos: blind trust in maintainers.
3. Flatpak/AppImage: freshness vs surrendering to dependencies.
4. curl | sh: pragmatism vs supply-chain blindness.
5. Compilation: /usr/local purists.

---

## Perspectives

<div style="font-size: 1.2em; line-height: 2.2; margin-top: 40px; text-align: left; max-width: 500px; margin-left: auto; margin-right: auto;">

* **User**
* **Developer**
* **Maintainer**

</div>

Note:
Present the three perspectives one by one via fragments:

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

---

## Dependencies

> *"Works on my machine (and compiles)"*

<div style="font-size: 0.78em; text-align: left; margin-top: 25px;">

<div class="fragment">

```text
/ocio: error while loading shared libraries: libOpenGL.so.0:
cannot open shared object file: No such file or directory
$ echo $?
127
```

</div>

<div class="fragment" style="margin-top: 20px;">

```text
$ ldd ./ocio
    linux-vdso.so.1 (0x00007ffe315f6000)
    libm.so.6 => /lib64/libm.so.6 (0x00007f9c8f2b0000)
    libOpenGL.so.0 => not found
    libGLX.so.0 => not found
    libc.so.6 => /lib64/libc.so.6 (0x00007f9c8f0b0000)
    /lib64/ld-linux-x86-64.so.2 (0x00007f9c8f3b0000)
```

</div>

</div>

Note:
Test command in minimal container:
$ podman run --rm -v ./build/bin/ocio:/ocio:ro,Z registry.opensuse.org/opensuse/tumbleweed:latest /ocio

Systems reality:
- A dynamically linked ELF binary is an incomplete contract with the OS.
- execve() succeeds: the kernel maps the binary and hands control to the interpreter named in PT_INTERP (/lib64/ld-linux-x86-64.so.2).
- The dynamic linker, in userspace, scans the DT_NEEDED entries in the ELF dynamic section.
- Resolves paths: RPATH/RUNPATH, /etc/ld.so.cache, glibc-hwcaps subdirs, /lib64, /usr/lib64.
- The first missing library (libOpenGL.so.0) makes ld.so print the error and call exit_group(127).
- The C code never executed: the process died in the loader, before main(). The kernel did its job; the userspace contract was broken. Packaging is the discipline that ensures this contract is fulfilled everywhere.

---

## Formats

<div style="font-size: 0.82em; margin-top: 30px;">

| Target | Mechanism |
|---|---|
| **Standalone Tarball** | Compressed archive (`.tar.gz`) with assets and `.desktop` |
| **RPM (`.rpm`)** | CPIO payload for Fedora/openSUSE/RHEL |
| **Debian (`.deb`)** | Standard `ar` archive via CPack |
| **AppImage** | Single executable with SquashFS mounted via FUSE |
| **Flatpak** | Bubblewrap sandbox on Freedesktop runtime |
| **OCI Container** | Complete userspace image run by Podman |
| **Source compilation** | Controlled CMake matrix (`FETCH`, `SYSTEM`, `LOCAL`) |

</div>

---

## Inside an RPM

<div style="font-size: 0.6em; text-align: left; margin-top: 15px;">

```text
$ file ocio-0.1.0-1.x86_64.rpm
ocio-0.1.0-1.x86_64.rpm: RPM v3.0 bin i386/x86_64
```

```text
+--------+-------------+-------------+------------------------------+
| Lead   | Signature   | Header      | Payload                      |
| magic  | digests,    | name, deps, | cpio archive, zstd           |
|        | GPG (none)  | file list   | the files                    |
+--------+-------------+-------------+------------------------------+
```

<div class="fragment">

```text
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | file -
/dev/stdin: ASCII cpio archive (SVR4 with no CRC)
$ rpm2cpio ocio-0.1.0-1.x86_64.rpm | cpio -idmv
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```

</div>
</div>

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

---

## Inside an RPM

<div style="display: flex; gap: 20px; font-size: 0.6em; margin-top: 20px; text-align: left;">
<div style="flex: 1;">
<h4>Payload: files</h4>

```text
$ rpm -qlp ocio-0.1.0-1.x86_64.rpm
/usr/bin/ocio
/usr/share/applications/ocio.desktop
/usr/share/icons/hicolor/256x256/apps/ocio.png
/usr/share/icons/hicolor/scalable/apps/ocio.svg
/usr/share/metainfo/org.packathon.ocio.metainfo.xml
```

</div>
<div class="fragment" style="flex: 1;">
<h4>Header: metadata</h4>

```text
$ rpm -qp --requires ocio-0.1.0-1.x86_64.rpm
libOpenGL.so.0()(64bit)
libGLX.so.0()(64bit)
libc.so.6(GLIBC_2.34)(64bit)
libm.so.6(GLIBC_2.43)(64bit)
...
$ rpm -qp --provides ocio-0.1.0-1.x86_64.rpm
ocio = 0.1.0-1
application(ocio.desktop)
```

</div>
</div>

Note:
rpm can query both halves of the file without installing it (-p = package file).
Payload (directories omitted from the listing):
- /usr/bin/ocio: the binary, in a directory that is already in $PATH.
- .desktop + icons: how the app appears in the desktop menu.
- metainfo XML: how software centers (GNOME Software, Discover) describe it.
Header, on the fragment:
- Look at the Requires: libOpenGL.so.0, libGLX.so.0. This is exactly the DT_NEEDED list from the error two slides ago.
- Nobody wrote these lines. rpmbuild's dependency generator reads the ELF (DT_NEEDED + glibc symbol versions) and writes them into the header automatically.
- Provides: what this package offers to others (a name, a version, a desktop application).
- Park GLIBC_2.43: we come back to it in the Delegation slide.

---

## Following libOpenGL.so.0

<div style="font-size: 0.7em; text-align: left; margin-top: 25px;">

```text
$ readelf -d ocio | grep OpenGL                                  # the binary
 (NEEDED)  Shared library: [libOpenGL.so.0]
```

<div class="fragment" style="margin-top: 20px;">

```text
$ rpm -qp --requires ocio-0.1.0-1.x86_64.rpm | grep OpenGL        # the package
libOpenGL.so.0()(64bit)
```

</div>
</div>

<p class="fragment" style="margin-top: 30px; font-size: 0.85em;">
<strong>486 KB</strong> package &rarr; <strong>36</strong> packages &rarr; <strong>52.6 MiB</strong> download
</p>

Note:
Follow one single string from the error message down to the repository.
1. The binary says: I need libOpenGL.so.0.
2. The package repeats it, in a form the package manager can query.
3. The repository answers: libglvnd provides it. The name from the error message now has an owner.
4. But libglvnd has its own requirements (libX11, Mesa-dri), which have their own, and so on.
Result on a vanilla Tumbleweed container: 36 new packages (ocio included), 52.6 MiB of downloads, for a 486 KB package.
One sentence on the solver, no more: "Some requirements have alternative providers; choosing one consistent set among tens of thousands of packages is a logic problem (SAT), and zypper solves it in milliseconds with libsolv." Deep dive only if asked in Q&A.
Note for Fedora users: the equivalent of zypper se --provides is dnf provides.

---

## Demo rpm

RPM installation in a *vanilla* openSUSE Tumbleweed container:

```bash
$ podman run --rm -v "$PWD/dist/ocio-0.1.0-1.x86_64.rpm:/ocio.rpm:ro,Z" \
    registry.opensuse.org/opensuse/tumbleweed:latest \
    sh -c "zypper --non-interactive in --allow-unsigned-rpm /ocio.rpm && ocio --version"
```

<p style="margin-top: 35px; font-size: 0.85em; text-align: left; color: #ffb74d;">* <code>--allow-unsigned-rpm</code></p>

Note:
[Live Terminal]: Switch to full-screen terminal tab with Ctrl+Tab (or Alt+Tab).
Run the live demo or display the command in terminal.
What zypper does, in order (visible in its output):
- Resolve: computes the 36 packages.
- Retrieve: downloads them (ocio itself from the "Plain RPM files cache").
- Verify: checks signatures. Here it cannot: our package is unsigned.
- Check for file conflicts: no two packages may own the same path.
- Install: unpack files into /usr, record every file in the RPM database.
Critical detail of the asterisk: --allow-unsigned-rpm. rpm -qi ocio shows "Signature: (none)" and "Build Host: e246f0b7ceaf" (a random container ID): nothing proves who built this package. This one ships no scriptlets (rpm -qp --scripts is empty), but the next unsigned RPM could, and scriptlets run as root. Foreshadow the Signatures section.

---

## After install

<div style="display: flex; gap: 20px; font-size: 0.58em; margin-top: 20px; text-align: left;">
<div style="flex: 1;">
<h4>Resolved</h4>

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

</div>
<div class="fragment" style="flex: 1;">
<h4>Recorded</h4>

```text
$ rpm -qf /usr/lib64/libOpenGL.so.0
libglvnd-1.7.0-2.4.x86_64
$ rpm -V ocio && echo clean
clean
$ rpm -e --test libglvnd
error: Failed dependencies:
  libOpenGL.so.0()(64bit) is needed by
    (installed) ocio-0.1.0-1.x86_64
  ...
```

</div>
</div>

Note:
Left: the same ldd as the Dependencies slide. Every "not found" is now a path in /lib64. The loader also follows the libraries' own dependencies (libGLdispatch, libX11, libxcb).
Right: installing is copying files plus keeping a record.
- rpm -qf: every file on the system has a known owner.
- rpm -V: verifies installed files against the digests in the database. Optional live moment: append a byte to ocio.desktop and rerun, output becomes "S.5....T. /usr/share/applications/ocio.desktop" (Size, digest (5), mTime changed).
- rpm -e --test: the database refuses to remove a library that others still need. This is what keeps the system from breaking.

---

## Launch

<div style="font-size: 0.8em; text-align: left; margin-top: 25px;">

`$ ocio`

1. **Shell**: `$PATH` lookup &rarr; `/usr/bin/ocio` <small>(`command -v ocio`)</small>
2. **Kernel**: `execve()` &rarr; `PT_INTERP` &rarr; `ld.so`
3. **ld.so**: `DT_NEEDED` &rarr; `/lib64/libOpenGL.so.0` found
4. `main()`

</div>

<p class="fragment" style="margin-top: 25px; font-size: 0.85em;">
Same path as the failed run. The package manager is <strong>not involved</strong> at launch.
</p>

<p class="fragment" style="margin-top: 15px; font-size: 0.85em; color: #4fc3f7;">
<em>Who else is present when the application starts?</em>
</p>

Note:
Answer the question explicitly: what does the OS do when we run an app installed by an RPM? Nothing special.
- The shell finds the binary through $PATH (/usr/bin is always there).
- The kernel loads it and hands control to the dynamic linker, exactly like in the failed run.
- The only difference: this time the files exist, because the package manager put them there beforehand.
- RPM is an installer and a bookkeeper, not a runtime. After installation it leaves the scene.
The last question is the bridge to the next section: with AppImage and Flatpak, someone else is present at launch (a FUSE mount, a sandbox).

---

## Delegation

* **Philosophy**: Package carries payload only; dependencies delegated to the distribution.

<div class="fragment" style="display: flex; gap: 20px; font-size: 0.78em; margin-top: 25px; text-align: left;">
<div style="flex: 1; border-left: 3px solid #81c784; padding-left: 15px;">
<h4>Advantages</h4>
<ul>
  <li>Minimal payload: 486 KB (52.6 MiB delegated).</li>
  <li>Shared libraries: one <code>libglvnd</code>, patched once for every app.</li>
  <li>Ownership &amp; verification: <code>rpm -qf</code>, <code>rpm -V</code>.</li>
</ul>
</div>
<div style="flex: 1; border-left: 3px solid #e57373; padding-left: 15px;">
<h4>Constraints</h4>
<ul>
  <li>ABI coupling: <code>libm.so.6(GLIBC_2.43)</code>.</li>
  <li>Strict packaging policies (FHS, <code>%files</code>, scriptlets).</li>
  <li>One build per target distro.</li>
</ul>
</div>
</div>

Note:
Recap: every bullet refers to something the audience has just seen.
- 486 KB vs 52.6 MiB: the distribution carries the weight.
- libglvnd is shared by ocio, Mesa, and every other GL application (rpm -q --whatrequires libglvnd): a CVE is fixed once, for all of them.
- GLIBC_2.43 in the Requires: this package installs only where glibc >= 2.43 exists. Built on Tumbleweed, it is useless on an older LTS. The price of delegation is coupling.

---

## DEB

<div style="font-size: 0.6em; text-align: left; margin-top: 15px;">

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

<div class="fragment">

```text
$ dpkg-deb -I ocio_0.1.0_amd64.deb | grep Depends
 Depends: libc6 (>= 2.17), libgl1, libx11-6
```

```text
$ dpkg-deb -c ocio_0.1.0_amd64.deb
./usr/bin/ocio
./usr/share/applications/ocio.desktop
...
```

</div>
</div>

Note:
Anatomy of a .deb file:
- Uses no proprietary container: it is a standard Unix ar archive (the same archive format used for static libraries .a).
- Contains exactly three files:
  1. debian-binary: text string with the format version ("2.0\n").
  2. control.tar: compressed archive with package metadata (control file, md5sums, postinst/prerm scriptlets).
  3. data.tar: compressed archive containing the actual payload files to unpack onto the filesystem.
- dpkg-deb -I: inspects control metadata. Notice Depends: libc6, libgl1, libx11-6. In Debian, this is generated by dpkg-shlibdeps scanning DT_NEEDED symbols.
- dpkg-deb -c: lists files in data.tar without extracting.
- In a vanilla debian:bookworm-slim container, apt-get install /ocio.deb resolves the tree and downloads 40 packages.

---

## Dialects

<!-- .slide: style="font-size: 0.65em;" -->

| Dimension | RPM Ecosystem | DEB Ecosystem |
|---|---|---|
| **Container** | Compressed CPIO (zstd/gzip) | Standard `ar` archive (`control.tar` + `data.tar`) |
| **Low-level tool** | `rpm` | `dpkg` |
| **Package manager** | `zypper` / `dnf` | `apt` |
| **Dependency generator** | `find-requires` (from `DT_NEEDED`) | `dpkg-shlibdeps` (`symbols` files) |
| **Payload inspection** | `rpm -qlp FILE.rpm` | `dpkg-deb -c FILE.deb` |
| **Metadata inspection** | `rpm -qp --requires FILE.rpm` | `dpkg-deb -I FILE.deb` |
| **Integrity audit** | `rpm -V PACKAGE` | `debsums PACKAGE` |

Note:
Two dialects, identical engineering principles:
- Both RPM and DEB cleanly separate the file payload from control metadata.
- Both use automated tools to map ELF DT_NEEDED entries into package dependency declarations.
- Both delegate resolution to high-level managers (zypper/dnf with libsolv, apt with its dependency engine).
- Conclusion of the Delegation section: we have seen how distributions carry the weight of dependencies. Now we look at the counter-move: those who refuse to delegate.

---

## AppImage

<div style="font-size: 0.78em; text-align: left; max-width: 800px; margin: 25px auto;">

* ELF runtime stub + compressed **SquashFS** filesystem
* Userspace mounting via **FUSE** and `AppRun` execution
* Host `glibc` dependency: building on newer distros breaks backwards compatibility

```text
$ ./ocio-x86_64.AppImage --appimage-extract
$ ls -1 squashfs-root
AppRun
ocio
ocio.desktop
ocio.png
```

</div>

Note:
How AppImage works:
- The file is an ELF binary (runtime stub) that encapsulates an appended SquashFS compressed image.
- On launch, the runtime mounts itself into a temporary directory in /tmp via FUSE and invokes AppRun.
- Requires no root privileges and no installation: download and run directly with chmod +x.
- The glibc limitation: bundles application libraries, but NOT the C library or the kernel ABI. Compiling on a newer distro fixes higher GLIBC symbols, preventing execution on older LTS systems.
- The --appimage-extract flag extracts the payload, allowing execution even where FUSE is unavailable.

---

## Flatpak

<div style="font-size: 0.78em; text-align: left; max-width: 800px; margin: 25px auto;">

* Versioned shared runtime: `org.freedesktop.Platform`
* System isolation via **Bubblewrap** (`bwrap`)
* Immutable and reproducible filesystem, decoupled from host

```text
$ flatpak run --command=sh org.packathon.ocio
[org.packathon.ocio ~]$ ls /
app  bin  dev  etc  lib  lib64  proc  run  sys  usr  var
[org.packathon.ocio ~]$ which ocio
/app/bin/ocio
```

</div>

Note:
How Flatpak works:
- Radical decoupling from host OS: the app does not see host /usr, but an isolated virtual environment mounted from a versioned shared runtime (Freedesktop Platform).
- Isolation via Bubblewrap (bwrap): uses Linux kernel namespaces (mount, PID, network, IPC) and seccomp to sandbox the binary.
- Path layout: /app contains the application files, /usr contains the immutable Freedesktop runtime libraries.
- Bridge to next slide: because the sandbox is isolated, accessing the display server, GPU, and audio requires explicit permissions in the manifest finish-args.

---

## Permissions

Not trusting the host requires explicit re-declaration of every hardware capability:

```yaml
# packaging/flatpak/org.packathon.ocio.yml
finish-args:
  - --socket=x11        # Display server X11
  - --socket=wayland    # Wayland compositor socket
  - --device=dri        # GPU acceleration (/dev/dri)
  - --share=ipc         # Shared memory (MIT-SHM)
```

* In host containers (Podman):  
  `--net=host --ipc=host -v /tmp/.X11-unix:/tmp/.X11-unix --device /dev/dri`
* **Consequence**: Complexity shifts from dynamic symbol resolution to IPC socket and portal configuration.

---

## Release

> *"CPack outputs multiple formats in one command. But a file is not a distribution channel."*

<div class="fragment" style="margin-top: 20px; text-align: left; font-size: 0.8em; line-height: 1.8;">
<h4>CPack vs Build Services (OBS / Koji)</h4>
<ul>
  <li><strong>CPack</strong>: Compiles on the developer's dirty host; bakes local paths and build artifacts into package headers.</li>
  <li><strong>Open Build Service (OBS)</strong>:
    <ul>
      <li>Builds in <strong>network-isolated, reproducible chroots</strong>.</li>
      <li>Automatic dependency-graph triggered rebuilds.</li>
      <li>Enforced test suites (<code>%check</code>) and policy checks (<code>rpmlint</code>).</li>
      <li>Automated GPG signing by the build infrastructure.</li>
    </ul>
  </li>
</ul>
</div>

---

## Updates

Update capabilities are governed by the **channel**, not the file format:

<ul style="font-size: 0.82em; text-align: left; line-height: 1.8;">
  <li class="fragment"><strong><code>.deb</code> / <code>.rpm</code> via repository</strong>: Native OS updates (<code>apt upgrade</code>, <code>zypper dup</code>).</li>
  <li class="fragment"><strong>Manually installed package (<code>dpkg -i</code> / <code>rpm -i</code>)</strong>: Orphaned artifact; no future security patches.</li>
  <li class="fragment"><strong>Flatpak via Flathub</strong>: <strong>OSTree</strong> repository; block-level static deltas (atomic updates).</li>
  <li class="fragment"><strong>AppImage</strong>: Static; requires <code>.upd_info</code> in ELF header to enable <code>zsync</code> updates.</li>
</ul>

<p class="fragment" style="margin-top: 25px; font-size: 0.8em; color: #ff8a80;">
<em>A binary without an update channel is a perpetual security liability.</em>
</p>

---

## Signatures

Why `--allow-unsigned-rpm` is unacceptable: no proof of origin, and scriptlets (when present) execute as **root**.

<div style="font-size: 0.78em; text-align: left; margin-top: 20px;">

| Ecosystem | Signature Target | Runtime Validation |
|---|---|---|
| **APT** | Repository metadata (`Release.gpg`) | Mandatory pre-unpack verification |
| **RPM** | Package header + `repomd.xml` | GPG keyring verification in RPM database |
| **Flatpak** | Commit &amp; Summary in OSTree | Cryptographic validation on every pull |
| **AppImage** | Embedded ELF block (`--appimage-signature`) | **No automatic validation** at runtime |

</div>

<p class="fragment" style="margin-top: 20px; font-size: 0.8em;">
<strong>2026 Reality</strong>: <em>Sigstore / Keyless</em> (OIDC) for upstream releases; traditional GPG keyrings remain mandatory for distro package managers.
</p>

---

## SBOM

* Modern languages (Rust, Go): deterministic lockfiles (`Cargo.lock`, `go.sum`).
* **In C with CMake, there is no universal lockfile**:
  * `raylib` vendored at build time via Git (`FetchContent`, static archive).
  * System stack (X11, OpenGL, glibc) resolved at runtime by the distro.

<div class="fragment" style="margin-top: 20px; text-align: left; font-size: 0.82em; background: rgba(255,255,255,0.05); padding: 15px; border-radius: 8px;">
<p>A C SBOM is split across build time and install time. Only an isolated, observable build service (e.g. OBS) can reconstruct the complete dependency graph.</p>
</div>

---

## Synthesis

<div style="font-size: 0.72em;">

| Format | Who Resolves Dependencies | Host Coupling | Model |
|---|---|---|---|
| **Tarball** | Developer (static) + Host (dynamic) | Undefined / Fragile | Direct `execve` |
| **`.deb` / `.rpm`** | **Distribution** (SAT solver) | Full | Native `execve` on `/usr` |
| **AppImage** | **Bundle** (SquashFS payload) | Loose (glibc/FUSE) | FUSE mount + `execve` |
| **Flatpak** | **Shared Runtime** (Freedesktop) | Decoupled | Bubblewrap + Portals |
| **OCI Container** | **Complete Userspace Image** | Minimal (kernel/DRI) | Namespaces + cgroups |

</div>

<p style="margin-top: 25px; font-size: 0.8em; color: #4fc3f7;">
<em>Every packaging choice arbitrates responsibility between developer, maintainer, and operating system.</em>
</p>

---

## Metrics

<!-- .slide: style="font-size: 0.75em;" -->

<div style="font-size: 0.75em;">

| Solution | Disk Footprint (Payload + Deps) | Cold Startup Overhead |
|---|---|---|
| **Raw Binary** | *[TBD: size MB]* | 0 ms (Baseline: *[TBD ms]*) |
| **Native .rpm / .deb** | *[TBD: size KB]* (+ host libraries) | ~0 ms (Shared in pagecache) |
| **Standalone Tarball** | *[TBD: size MB]* | ~0 ms |
| **AppImage** | *[TBD: size MB]* | +*[TBD ms]* (FUSE &amp; SquashFS) |
| **Flatpak** | *[TBD: size MB]* (+ ~500 MB base) | +*[TBD ms]* (bwrap &amp; IPC portals) |
| **OCI Container** | *[TBD: size MB]* | +*[TBD ms]* (Overlayfs &amp; rootless) |
| **Source Build** | *[TBD: size MB]* (+ toolchain) | 0 ms (post-compilation) |

</div>

<p style="margin-top: 25px; font-size: 0.85em; text-align: left;">
<strong>Systems trade-off:</strong> Portability and sandboxing come at the cost of cold-start latency and duplicate disk space.
</p>

---

## Boundaries

<div style="font-size: 0.82em; text-align: left; line-height: 1.8;">

* **Out-of-scope ecosystems**:
  * **Snap**: `snapd` dependency, Ubuntu kernel AppArmor ties.
  * **Nix / Guix**: Purely functional store (`/nix/store`), fundamentally distinct paradigm.
  * **Arch / AUR**: User-facing build recipes, not distributed binaries.
* **The AppImage glibc baseline**:
  * Building on newer distros sets high minimum `GLIBC_2.XX` symbols: bundle fails on conservative systems.
  * Remediation: containerized builds against older LTS baselines.

</div>

<p style="margin-top: 25px; font-size: 0.82em; color: #ffb74d;">
<em>These are real-world engineering boundaries, not oversights.</em>
</p>

---

## Q&A

<div style="display: flex; justify-content: center; align-items: center; gap: 50px; margin-top: 35px;">
  <img src="https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=https://michelepagot.github.io/packathon/" alt="Repository QR Code" style="border-radius: 8px; border: 2px solid rgba(255,255,255,0.3);" />
  <div style="text-align: left; font-size: 0.85em;">
    <p><strong>Slides &amp; Code:</strong></p>
    <p><a href="https://michelepagot.github.io/packathon/" target="_blank">michelepagot.github.io/packathon</a></p>
    <p><a href="https://github.com/michelepagot/packathon" target="_blank">github.com/michelepagot/packathon</a></p>
    <p style="margin-top: 20px; color: #81c784;"><strong>Open Q&amp;A</strong></p>
  </div>
</div>
