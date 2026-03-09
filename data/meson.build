# Install the .desktop file so the XFCE panel can discover the plugin
desktop_file = configure_file(
  input: 'nova-bluetooth.desktop.in',
  output: 'nova-bluetooth.desktop',
  configuration: {
    'PLUGIN_NAME': plugin_name,
  },
  install: true,
  install_dir: join_paths(get_option('datadir'), 'xfce4', 'panel', 'plugins'),
)

# Install CSS theme file for the plugin's modern styling
install_data(
  'nova-bluetooth.css',
  install_dir: join_paths(get_option('datadir'), 'nova-bluetooth'),
)
