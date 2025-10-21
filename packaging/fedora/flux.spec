Name:           flux
Version:        1.31.0.1
Release:        1%{?dist}
Summary:        Advanced daemon for X11 desktops and window managers

License:        GPL-3.0-only
URL:            https://github.com/itz-me-zappex/flux
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  libXres-devel, libX11-devel, libXext-devel, xorg-x11-proto-devel, make, gcc
Requires:       bash, util-linux, cpulimit, coreutils, libXres, libX11, libXext, less
Recommends:     mangohud, mangohud.i686, libnotify, pulseaudio-utils

%description
Advanced daemon for X11 desktops and window managers,
designed to automatically limit FPS/CPU usage of
unfocused windows and run commands on focus and unfocus events.
Written in Bash and partially in C.

%prep
%autosetup -n flux-%{version}

%build
make

%install
make PREFIX=%{buildroot}/usr install
mkdir -p %{buildroot}/etc/security/limits.d
install -Dm644 10-flux.conf %{buildroot}/etc/security/limits.d/

%files
%license LICENSE
%doc README.md
/usr/bin/flux
/usr/lib/flux/*
/etc/security/limits.d/10-flux.conf

%changelog
* Tue Oct 21 2025 ZaPPeX - %{version}-%{release}
- Initial RPM packaging of flux
