/* DeviceRow: a single row in the device list showing icon, name,
 * status, battery level, action button, and overflow menu.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/noviktech133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class DeviceRow : Gtk.ListBoxRow {

        /* The device model this row represents */
        public Device device { get; construct; }

        /* Signal to request device removal from the manager */
        public signal void forget_requested (string object_path);

        /* Widgets composing the row layout */
        private Gtk.Image _icon;
        private Gtk.Label _name_label;
        private Gtk.Label _status_label;
        private Gtk.Label _battery_label;
        private Gtk.Button _action_button;
        private Gtk.Button _menu_button;
        private Gtk.Box _main_box;
        private Gtk.Box _info_box;
        private Gtk.Spinner _spinner;

        /* Track whether an async operation is in flight */
        private bool _busy = false;

        public DeviceRow (Device device) {
            Object (device: device);
        }

        construct {
            /* Root horizontal box */
            _main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            _main_box.get_style_context ().add_class ("nova-bt-device-row");
            _main_box.margin_start = 4;
            _main_box.margin_end = 4;
            _main_box.margin_top = 2;
            _main_box.margin_bottom = 2;

            /* Device icon on the left */
            _icon = new Gtk.Image.from_icon_name (device.icon, Gtk.IconSize.LARGE_TOOLBAR);
            _icon.get_style_context ().add_class ("nova-bt-device-icon");
            _icon.pixel_size = 22;
            _main_box.pack_start (_icon, false, false, 0);

            /* Vertical box for name + status */
            _info_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
            _info_box.valign = Gtk.Align.CENTER;

            _name_label = new Gtk.Label (device.name);
            _name_label.get_style_context ().add_class ("nova-bt-device-name");
            _name_label.halign = Gtk.Align.START;
            _name_label.ellipsize = Pango.EllipsizeMode.END;
            _name_label.max_width_chars = 18;
            _info_box.pack_start (_name_label, false, false, 0);

            _status_label = new Gtk.Label (device.get_status_text ());
            _status_label.get_style_context ().add_class ("nova-bt-device-status");
            _status_label.halign = Gtk.Align.START;
            _info_box.pack_start (_status_label, false, false, 0);

            _main_box.pack_start (_info_box, true, true, 0);

            /* Battery label (hidden if not available) */
            _battery_label = new Gtk.Label ("");
            _battery_label.get_style_context ().add_class ("nova-bt-battery");
            _battery_label.valign = Gtk.Align.CENTER;
            _battery_label.no_show_all = true;
            _main_box.pack_start (_battery_label, false, false, 0);

            /* Spinner shown during connect/disconnect operations */
            _spinner = new Gtk.Spinner ();
            _spinner.no_show_all = true;
            _spinner.valign = Gtk.Align.CENTER;
            _main_box.pack_start (_spinner, false, false, 0);

            /* Action button: connect or disconnect */
            _action_button = new Gtk.Button ();
            _action_button.get_style_context ().add_class ("nova-bt-action-button");
            _action_button.valign = Gtk.Align.CENTER;
            _action_button.clicked.connect (on_action_clicked);
            _main_box.pack_end (_action_button, false, false, 0);

            /* Overflow menu button (...) for Forget / Info */
            _menu_button = new Gtk.Button ();
            _menu_button.get_style_context ().add_class ("nova-bt-menu-button");
            _menu_button.valign = Gtk.Align.CENTER;
            _menu_button.relief = Gtk.ReliefStyle.NONE;
            _menu_button.image = new Gtk.Image.from_icon_name (
                "view-more-horizontal-symbolic",
                Gtk.IconSize.MENU
            );
            _menu_button.clicked.connect (show_context_menu);
            _main_box.pack_end (_menu_button, false, false, 0);

            add (_main_box);

            /* Listen for property changes on the device */
            device.changed.connect (update_ui);

            /* Initial UI update */
            update_ui ();

            show_all ();
        }

        /* Refresh all widget states from the device model */
        private void update_ui () {
            _name_label.label = device.name;
            _icon.icon_name = device.icon;

            /* Build status string */
            string status = device.get_status_text ();
            if (device.battery_percentage >= 0) {
                status += "  %d%%".printf (device.battery_percentage);
            }
            _status_label.label = status;

            /* Battery label for separate display */
            if (device.battery_percentage >= 0) {
                _battery_label.label = "%d%%".printf (device.battery_percentage);
                _battery_label.visible = true;
            } else {
                _battery_label.visible = false;
            }

            /* Action button label depends on state */
            if (device.connected) {
                _action_button.label = "Disconnect";
            } else if (device.paired) {
                _action_button.label = "Connect";
            } else {
                _action_button.label = "Pair";
            }

            /* Connected styling */
            var ctx = _main_box.get_style_context ();
            if (device.connected) {
                ctx.add_class ("connected");
            } else {
                ctx.remove_class ("connected");
            }

            _action_button.sensitive = !_busy;
        }

        /* Show a popover with device info and actions */
        private void show_context_menu () {
            var popover = new Gtk.Popover (_menu_button);
            popover.constrain_to = Gtk.PopoverConstraint.NONE;
            popover.position = Gtk.PositionType.BOTTOM;
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);
            box.margin = 8;

            /* Device info section */
            var info_label = new Gtk.Label (null);
            info_label.use_markup = true;
            info_label.halign = Gtk.Align.START;
            info_label.wrap = true;
            info_label.max_width_chars = 28;

            var sb = new GLib.StringBuilder ();
            sb.append ("<b>%s</b>\n".printf (GLib.Markup.escape_text (device.name)));
            sb.append ("Address: %s\n".printf (device.address));
            sb.append ("Status: %s\n".printf (device.get_status_text ()));
            sb.append ("Paired: %s\n".printf (device.paired ? "Yes" : "No"));
            sb.append ("Trusted: %s".printf (device.trusted ? "Yes" : "No"));
            if (device.battery_percentage >= 0) {
                sb.append ("\nBattery: %d%%".printf (device.battery_percentage));
            }
            info_label.label = sb.str;
            box.pack_start (info_label, false, false, 0);

            /* Separator */
            box.pack_start (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), false, false, 4);

            /* Forget button (only for paired devices) */
            if (device.paired) {
                var forget_btn = new Gtk.Button.with_label ("Forget device");
                forget_btn.get_style_context ().add_class ("destructive-action");
                forget_btn.clicked.connect (() => {
                    popover.popdown ();
                    forget_requested (device.object_path);
                });
                box.pack_start (forget_btn, false, false, 0);
            }

            popover.add (box);
            popover.show_all ();
        }

        /* Handle click on the connect/disconnect/pair button */
        private void on_action_clicked () {
            if (_busy) return;
            _busy = true;
            _spinner.visible = true;
            _spinner.start ();
            _action_button.sensitive = false;

            /* Run blocking D-Bus calls in a thread to keep the UI responsive */
            new GLib.Thread<void*> ("bt-action", () => {
                if (device.connected) {
                    device.disconnect_device ();
                } else if (device.paired) {
                    device.connect_device ();
                } else {
                    device.pair_device ();
                }

                /* Return to the main thread to update the UI */
                GLib.Idle.add (() => {
                    finish_action ();
                    return false;
                });

                return null;
            });
        }

        /* Reset busy state after an action completes */
        private void finish_action () {
            _busy = false;
            _spinner.stop ();
            _spinner.visible = false;
            update_ui ();
        }
    }
}
