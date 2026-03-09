# All Vala source files for the plugin, organized by module
nova_bt_sources = files(
  # Main plugin entry point
  'plugin.vala',

  # Bluetooth backend
  'bluetooth/dbus_interfaces.vala',
  'bluetooth/manager.vala',
  'bluetooth/adapter.vala',
  'bluetooth/device.vala',

  # UI widgets
  'widgets/indicator_button.vala',
  'widgets/popover_menu.vala',
  'widgets/device_list.vala',
  'widgets/device_row.vala',

  # Utilities
  'utils/css_loader.vala',
)

# Build the shared library that the XFCE panel loads
shared_module(
  'nova-bluetooth',
  sources: nova_bt_sources,
  dependencies: [
    glib_dep,
    gobject_dep,
    gtk3_dep,
    libxfce4panel_dep,
    libxfce4ui_dep,
    libxfconf_dep,
  ],
  vala_args: [
    '--pkg', 'posix',
    '--vapidir', meson.project_source_root() / 'vapi',
    '--pkg', 'libxfconf-0',
    '--pkg', 'libxfce4ui-2',
    '--pkg', 'libxfce4panel-2.0',
  ],
  install: true,
  install_dir: panel_pluginsdir,
)
