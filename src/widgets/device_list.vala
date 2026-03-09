/* DeviceList: a scrollable list of DeviceRows grouped into
 * "Connected", "Paired", and "Available" sections.
 * Sorts devices by connection state, then by name.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/novik133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class DeviceList : Gtk.Box {

        /* Reference to the bluetooth manager for data */
        private Manager _manager;

        /* The actual list widget */
        private Gtk.ListBox _listbox;

        /* Scrolled container to keep the list bounded */
        private Gtk.ScrolledWindow _scroll;

        /* Empty state label shown when no devices exist */
        private Gtk.Label _empty_label;

        /* Stack to switch between list and empty state */
        private Gtk.Stack _stack;

        /* Map from device path to its row widget */
        private GLib.HashTable<string, DeviceRow> _rows;

        public DeviceList (Manager manager) {
            Object (orientation: Gtk.Orientation.VERTICAL, spacing: 0);
            _manager = manager;
            _rows = new GLib.HashTable<string, DeviceRow> (str_hash, str_equal);

            build_ui ();
            connect_signals ();
            populate_existing ();
        }

        /* Construct the widget tree */
        private void build_ui () {
            _stack = new Gtk.Stack ();
            _stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

            /* List view */
            _listbox = new Gtk.ListBox ();
            _listbox.selection_mode = Gtk.SelectionMode.NONE;
            _listbox.get_style_context ().add_class ("nova-bt-device-list");
            _listbox.set_sort_func (sort_devices);

            _scroll = new Gtk.ScrolledWindow (null, null);
            _scroll.get_style_context ().add_class ("nova-bt-scroll");
            _scroll.hscrollbar_policy = Gtk.PolicyType.NEVER;
            _scroll.vscrollbar_policy = Gtk.PolicyType.AUTOMATIC;
            _scroll.min_content_height = 100;
            _scroll.max_content_height = 340;
            _scroll.propagate_natural_height = true;
            _scroll.add (_listbox);

            _stack.add_named (_scroll, "list");

            /* Empty state */
            _empty_label = new Gtk.Label ("No Bluetooth devices found.\nTurn on Bluetooth and scan for devices.");
            _empty_label.get_style_context ().add_class ("nova-bt-empty-state");
            _empty_label.justify = Gtk.Justification.CENTER;
            _empty_label.wrap = true;
            _stack.add_named (_empty_label, "empty");

            pack_start (_stack, true, true, 0);

            update_visible_child ();
        }

        /* Subscribe to manager signals for device add/remove */
        private void connect_signals () {
            _manager.device_added.connect (on_device_added);
            _manager.device_removed.connect (on_device_removed);
        }

        /* Add rows for devices that already existed before we were created */
        private void populate_existing () {
            var devices = _manager.get_devices ();
            foreach (var dev in devices) {
                add_device (dev);
            }
        }

        /* Signal handler: look up device by path and add it */
        private void on_device_added (string object_path) {
            var device = _manager.get_device (object_path);
            if (device != null) {
                add_device (device);
            }
        }

        /* Create a new row for a device */
        private void add_device (Device device) {
            if (_rows.contains (device.object_path)) return;

            var row = new DeviceRow (device);
            _rows.insert (device.object_path, row);
            _listbox.add (row);

            /* Handle forget request from the row's context menu */
            row.forget_requested.connect ((path) => {
                _manager.remove_device (path);
            });

            /* Re-sort when device properties change */
            device.changed.connect (() => {
                _listbox.invalidate_sort ();
                update_visible_child ();
            });

            update_visible_child ();
        }

        /* Remove a row when a device disappears */
        private void on_device_removed (string path) {
            var row = _rows.lookup (path);
            if (row != null) {
                _listbox.remove (row);
                _rows.remove (path);
            }
            update_visible_child ();
        }

        /* Show the list or the empty state */
        private void update_visible_child () {
            if (_rows.size () == 0) {
                _stack.visible_child_name = "empty";
            } else {
                _stack.visible_child_name = "list";
            }
        }

        /* Sort function: connected first, then paired, then available; alphabetical within each group */
        private int sort_devices (Gtk.ListBoxRow a, Gtk.ListBoxRow b) {
            var da = ((DeviceRow) a).device;
            var db = ((DeviceRow) b).device;

            int score_a = get_sort_score (da);
            int score_b = get_sort_score (db);

            if (score_a != score_b) return score_a - score_b;

            return da.name.collate (db.name);
        }

        /* Lower score = higher in list */
        private int get_sort_score (Device d) {
            if (d.connected) return 0;
            if (d.paired) return 1;
            return 2;
        }
    }
}
