project(
  'nova-bluetooth',
  ['vala', 'c'],
  version: '0.1.0',
  license: 'GPL-2.0-or-later',
  meson_version: '>= 0.56.0',
  default_options: [
    'warning_level=2',
  ],
)

# Project-wide constants
plugin_name = 'nova-bluetooth'
plugin_id = 'nova-bluetooth'
prefix = get_option('prefix')
libdir = get_option('libdir')

# Required dependencies
glib_dep = dependency('glib-2.0', version: '>= 2.56')
gobject_dep = dependency('gobject-2.0', version: '>= 2.56')
gtk3_dep = dependency('gtk+-3.0', version: '>= 3.22')
libxfce4panel_dep = dependency('libxfce4panel-2.0', version: '>= 4.14')
libxfce4ui_dep = dependency('libxfce4ui-2', version: '>= 4.14')
libxfconf_dep = dependency('libxfconf-0', version: '>= 4.14')

# Determine the panel plugin install directory
panel_pluginsdir = libxfce4panel_dep.get_variable(
  pkgconfig: 'pluginsdir',
  default_value: join_paths(prefix, libdir, 'xfce4', 'panel', 'plugins'),
)

# Subdirectories
subdir('data')
subdir('src')
