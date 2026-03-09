/* Plugin: main entry point for the XFCE panel plugin.
 * Registers with the panel framework and wires up the
 * Bluetooth manager, indicator button, and CSS styling.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Website: http://noviktech.com
 * Repository: https://github.com/noviktech133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    /* The XFCE panel calls this function to create the plugin */
    public class Plugin : Xfce.PanelPlugin {

        /* Core bluetooth manager instance */
        private Manager? _manager = null;

        /* The button widget added to the panel */
        private IndicatorButton? _button = null;

        public override void @construct () {
            /* Load custom CSS before creating any widgets */
            CSSLoader.load ();

            /* Create the Bluetooth backend */
            _manager = new Manager ();

            /* Create the panel indicator button (connects signals to manager) */
            _button = new IndicatorButton (this, _manager);

            /* Add the button to the panel */
            add (_button);
            show_all ();

            /* Start BlueZ discovery now that all UI is connected */
            _manager.start ();

            /* Tell XFCE we want a small, square button */
            set_small (true);

            /* Handle plugin destruction gracefully */
            destroy.connect (() => {
                /* Stop discovery if running when plugin is removed */
                if (_manager != null && _manager.is_discovering ()) {
                    _manager.stop_scan ();
                }
            });

            /* Handle right-click context menu (standard XFCE plugin menu) */
            menu_show_about ();
            about.connect (show_about_dialog);
        }

        /* Show the standard about dialog */
        private void show_about_dialog () {
            Gtk.show_about_dialog (null,
                "program-name", "Nova Bluetooth",
                "version", "0.1.0",
                "comments", "Modern Bluetooth indicator for the XFCE panel",
                "website", "https://github.com/noviktech133/NovaBluetooth",
                "copyright", "Copyright (c) Kamil 'Novik' Nowicki",
                "authors", new string[] { "Kamil 'Novik' Nowicki" },
                "license-type", Gtk.License.GPL_2_0,
                "logo-icon-name", "bluetooth-active",
                null
            );
        }
    }
}

/* Module entry point called by the XFCE panel loader.
 * This C-compatible function creates our plugin type. */
[ModuleInit]
public Type xfce_panel_module_init (TypeModule module) {
    return typeof (NovaBluetooth.Plugin);
}
