# =============================================================================
# RPM Specification for ocio (Manual Packaging Demonstration)
# =============================================================================
# This spec file demonstrates the canonical distribution method of packaging
# a CMake C application directly with rpmbuild, completely bypassing CPack.
#
# Highlights:
# 1. Unbundling policy: Depends on system raylib-devel rather than vendoring.
# 2. Native RPM macros: Uses %%cmake, %%cmake_build, and %%cmake_install.
# 3. Automatic dependency resolution: rpmbuild's find-requires automatically
#    extracts shared library dependencies (libraylib.so, libGL.so, libc.so).
# 4. Standard XDG desktop integration: .desktop file, icons, and AppStream XML.
# =============================================================================

# Support optional multi-source offline builds (e.g. for hermetic OBS builds)
%bcond_with vendored_raylib

Name:           ocio
Version:        0.1.0
Release:        1%{?dist}
Summary:        Raylib interactive eye-tracking educational demo
License:        MIT
URL:            https://github.com/example/ocio
Source0:        %{name}-%{version}.tar.gz
%if %{with vendored_raylib}
Source1:        raylib-5.5.tar.gz
%endif

BuildRequires:  cmake >= 3.16
BuildRequires:  gcc
BuildRequires:  pkgconfig
BuildRequires:  libX11-devel
BuildRequires:  Mesa-libGL-devel
BuildRequires:  alsa-devel

%if %{with vendored_raylib}
# Multi-source hermetic mode does not require system raylib-devel
%else
BuildRequires:  raylib-devel >= 5.0
%endif

%description
Ocio is an interactive educational demonstration that tracks the mouse pointer
with an animated eye, illustrating real-time rendering, velocity damping, and
canonical operating system packaging pipelines without relying on high-level
abstractions like CPack.

%prep
%if %{with vendored_raylib}
%autosetup -a 1
mkdir -p build/_deps
mv raylib-5.5 build/_deps/raylib-src
%else
%autosetup
%endif

%build
%if %{with vendored_raylib}
%cmake -DRAYLIB_MODE=LOCAL -DENABLE_CPACK=OFF
%else
%cmake -DRAYLIB_MODE=SYSTEM -DENABLE_CPACK=OFF
%endif
%cmake_build

%install
%cmake_install

%files
%license LICENSE
%doc README.md
%{_bindir}/ocio
%{_datadir}/applications/ocio.desktop
%{_datadir}/icons/hicolor/256x256/apps/ocio.png
%{_datadir}/icons/hicolor/scalable/apps/ocio.svg
%{_datadir}/metainfo/org.packathon.ocio.metainfo.xml

%changelog
* Wed Sep 16 2026 Packathon Maintainers <maintainers@packathon.org> - 0.1.0-1
- Initial manual RPM packaging without CPack
