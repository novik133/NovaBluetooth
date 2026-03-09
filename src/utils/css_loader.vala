/* CSSLoader: loads the plugin's custom stylesheet at runtime.
 * Searches standard XDG data directories for the CSS file.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/novik133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class CSSLoader {

        /* Load and apply the nova-bluetooth.css stylesheet globally */
        public static void load () {
            var provider = new Gtk.CssProvider ();
            string css_path = find_css_file ();

            if (css_path == null) {
                warning ("Could not find nova-bluetooth.css");
                return;
            }

            try {
                provider.load_from_path (css_path);

                Gtk.StyleContext.add_provider_for_screen (
                    Gdk.Screen.get_default (),
                    provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            } catch (Error e) {
                warning ("Failed to load CSS from %s: %s", css_path, e.message);
            }
        }

        /* Search standard paths for the CSS file */
        private static string? find_css_file () {
            /* Check XDG data directories */
            string[] search_dirs = GLib.Environment.get_system_data_dirs ();

            /* Also check the user data dir */
            string user_dir = GLib.Environment.get_user_data_dir ();

            /* Try user dir first */
            string user_path = GLib.Path.build_filename (user_dir, "nova-bluetooth", "nova-bluetooth.css");
            if (GLib.FileUtils.test (user_path, GLib.FileTest.EXISTS)) {
                return user_path;
            }

            /* Then system dirs */
            foreach (var dir in search_dirs) {
                string path = GLib.Path.build_filename (dir, "nova-bluetooth", "nova-bluetooth.css");
                if (GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) {
                    return path;
                }
            }

            return null;
        }
    }
}
