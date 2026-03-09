Name:           nova-bluetooth
Version:        0.1.0
Release:        1%{?dist}
Summary:        Modern Bluetooth indicator for the XFCE4 panel
License:        GPL-2.0-or-later
URL:            https://github.com/novik133/NovaBluetooth
Source0:        %{url}/archive/v%{version}/%{name}-%{version}.tar.gz

BuildRequires:  gcc
BuildRequires:  meson >= 0.56.0
BuildRequires:  ninja-build
BuildRequires:  vala >= 0.40
BuildRequires:  pkgconfig(glib-2.0) >= 2.56
BuildRequires:  pkgconfig(gobject-2.0) >= 2.56
BuildRequires:  pkgconfig(gtk+-3.0) >= 3.22
BuildRequires:  pkgconfig(libxfce4panel-2.0) >= 4.14
BuildRequires:  pkgconfig(libxfce4ui-2) >= 4.14
BuildRequires:  pkgconfig(libxfconf-0) >= 4.14
BuildRequires:  xfce4-dev-tools
BuildRequires:  git
BuildRequires:  autoconf
BuildRequires:  automake
BuildRequires:  libtool
BuildRequires:  make

Requires:       bluez

%description
Nova Bluetooth is a native XFCE4 panel plugin that provides a modern
Bluetooth device manager. It communicates directly with BlueZ over D-Bus
without relying on any external programs. Supports device discovery,
connection, disconnection, pairing, battery level display, and live
status updates.

%prep
%autosetup -n NovaBluetooth-%{version}

%build
%meson
%meson_build

%install
%meson_install

%files
%license LICENSE
%doc README.md CHANGELOG.md
%{_libdir}/xfce4/panel/plugins/libnova-bluetooth.so
%{_datadir}/xfce4/panel/plugins/nova-bluetooth.desktop
%{_datadir}/nova-bluetooth/nova-bluetooth.css

%changelog
* Sun Mar 09 2026 Kamil 'Novik' Nowicki <noviktech.com> - 0.1.0-1
- Initial release
