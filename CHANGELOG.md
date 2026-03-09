# Changelog

All notable changes to Nova Bluetooth will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-03-09

### Added

- Native XFCE4 panel plugin built with Vala and GTK3
- Direct BlueZ D-Bus backend using ObjectManager for adapter and device tracking
- Bluetooth adapter power toggle from the popover menu
- Device discovery with automatic 30-second scan timeout
- Connect, disconnect, and pair Bluetooth devices from the popover
- Live property change tracking via D-Bus PropertiesChanged signals
- Battery level display for devices supporting the BlueZ Battery1 interface
- Adaptive panel icon reflecting Bluetooth state (disabled, active, connected)
- Modern popover UI with header, device list, scan controls, and footer
- Device list sorted by connection state (connected, paired, available) then by name
- GTK3 CSS stylesheet using theme color references for panel appearance integration
- Threaded D-Bus operations to keep the UI responsive during connect/disconnect
- XFCE panel right-click about dialog with project information
- Desktop file for XFCE panel plugin discovery
- Packaging support for Debian, Fedora, and Arch Linux
- GitHub Actions CI workflow for building on Debian, Fedora, and Arch Linux

[0.1.0]: https://github.com/novik133/NovaBluetooth/releases/tag/v0.1.0
