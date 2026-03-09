/* PopoverMenu: the dropdown that appears when clicking the panel button.
 * Contains the power toggle, scan controls, and the device list.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/noviktech133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class PopoverMenu : Gtk.Box {

        /* Bluetooth manager reference */
        private Manager _manager;

        /* Header widgets */
        private Gtk.Box _header_box;
        private Gtk.Label _header_title;
        private Gtk.Switch _power_switch;

        /* Scan status area */
        private Gtk.Box _scan_bar;
        private Gtk.Spinner _scan_spinner;
        private Gtk.Label _scan_label;

        /* Device list widget */
        private DeviceList _device_list;

        /* Footer with action buttons */
        private Gtk.Box _footer_box;
        private Gtk.Button _scan_button;

        /* Track whether we are updating the switch programmatically */
        private bool _updating_switch = false;

        public PopoverMenu (Manager manager) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            _manager = manager;

            build_header ();
            build_scan_bar ();
            build_device_list ();
            build_footer ();
            connect_signals ();
            update_state ();
        }

        /* Top bar: "Bluetooth" label and power toggle */
        private void build_header () {
            _header_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            _header_box.get_style_context ().add_class ("nova-bt-header");

            _header_title = new Gtk.Label ("Bluetooth");
            _header_title.get_style_context ().add_class ("nova-bt-header-title");
            _header_title.halign = Gtk.Align.START;
            _header_title.hexpand = true;
            _header_box.pack_start (_header_title, true, true, 0);

            _power_switch = new Gtk.Switch ();
            _power_switch.valign = Gtk.Align.CENTER;
            _power_switch.state_set.connect (on_power_toggled);
            _header_box.pack_end (_power_switch, false, false, 0);

            pack_start (_header_box, false, false, 0);
        }

        /* Status bar shown during scanning */
        private void build_scan_bar () {
            _scan_bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            _scan_bar.get_style_context ().add_class ("nova-bt-scan-bar");
            _scan_bar.no_show_all = true;

            _scan_spinner = new Gtk.Spinner ();
            _scan_spinner.get_style_context ().add_class ("nova-bt-spinner");
            _scan_bar.pack_start (_scan_spinner, false, false, 0);

            _scan_label = new Gtk.Label ("Scanning for devices...");
            _scan_label.halign = Gtk.Align.START;
            _scan_bar.pack_start (_scan_label, true, true, 0);

            pack_start (_scan_bar, false, false, 0);
        }

        /* Main area: the device list */
        private void build_device_list () {
            _device_list = new DeviceList (_manager);
            pack_start (_device_list, true, true, 0);
        }

        /* Bottom bar with scan button */
        private void build_footer () {
            _footer_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            _footer_box.get_style_context ().add_class ("nova-bt-footer");

            _scan_button = new Gtk.Button.with_label ("Scan for devices");
            _scan_button.get_style_context ().add_class ("nova-bt-scan-button");
            _scan_button.hexpand = true;
            _scan_button.clicked.connect (on_scan_clicked);
            _footer_box.pack_start (_scan_button, true, true, 0);

            pack_end (_footer_box, false, false, 0);
        }

        /* Wire up manager signals to keep the UI in sync */
        private void connect_signals () {
            _manager.adapter_changed.connect (update_state);
            _manager.state_changed.connect (update_state);
        }

        /* Refresh all controls based on current adapter state */
        private void update_state () {
            bool available = _manager.is_available ();
            bool powered = _manager.is_powered ();
            bool discovering = _manager.is_discovering ();

            /* Update power switch without triggering callback */
            _updating_switch = true;
            _power_switch.active = powered;
            _power_switch.sensitive = available;
            _updating_switch = false;

            /* Show/hide scan bar */
            if (discovering) {
                _scan_bar.visible = true;
                _scan_bar.show_all ();
                _scan_spinner.start ();
                _scan_button.label = "Stop scanning";
            } else {
                _scan_bar.visible = false;
                _scan_spinner.stop ();
                _scan_button.label = "Scan for devices";
            }

            /* Disable controls when Bluetooth is off */
            _scan_button.sensitive = powered;
            _device_list.sensitive = powered;

            if (!available) {
                _header_title.label = "Bluetooth (unavailable)";
            } else if (!powered) {
                _header_title.label = "Bluetooth (off)";
            } else {
                _header_title.label = "Bluetooth";
            }
        }

        /* Handle power switch toggle */
        private bool on_power_toggled (bool state) {
            if (_updating_switch) return false;
            _manager.toggle_power ();
            return false;
        }

        /* Handle scan button click */
        private void on_scan_clicked () {
            if (_manager.is_discovering ()) {
                _manager.stop_scan ();
            } else {
                _manager.start_scan ();
            }
        }
    }
}
