Name:           flux
Version:        1.34.1
Release:        1%{?dist}
Summary:        Advanced daemon for X11 desktops and window managers

License:        GPL-3.0-only
URL:            https://github.com/itz-me-zappex/flux
Source0:        %{url}/archive/refs/tags/v%{version}.tar.gz

BuildRequires:  libXres-devel, libX11-devel, libXext-devel, xorg-x11-proto-devel, make, gcc
Requires:       bash, util-linux, cpulimit, coreutils, libXres, libX11, libXext, less
Recommends:     mangohud, mangohud.i686, libnotify, pulseaudio-utils

%description
An advanced automation daemon for X11 desktops and window managers.
Designed to limit FPS/CPU usage and run commands on window focus and unfocus events.
Provides gaming-oriented features.
Written mostly in Bash and partially in C.

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

%post
groupadd -r flux
echo "Group 'flux' has been created, you may want to add your user to there by 'sudo usermod -aG flux \$USER' to bypass scheduling policy changing restrictions."

%postun
groupdel flux
echo "Group 'flux' has been removed."

%changelog
* Tue Oct 21 2025 ZaPPeX - %{version}-%{release}
- Initial RPM packaging of flux
