/* Manager: central coordinator for BlueZ interactions.
 * Discovers adapters and devices by introspecting the BlueZ
 * D-Bus object tree, then watches for changes via signal
 * subscriptions on the system bus. Avoids the unreliable
 * GetManagedObjects nested HashTable parsing in Vala.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/noviktech133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class Manager : GLib.Object {

        /* The currently active adapter (first one found) */
        public Adapter? adapter { get; private set; default = null; }

        /* All known devices keyed by their D-Bus object path */
        private GLib.HashTable<string, Device> _devices;

        /* System bus connection for signal subscriptions */
        private GLib.DBusConnection? _bus = null;

        /* Signal subscription IDs so we can unsubscribe later */
        private uint _added_sub_id = 0;
        private uint _removed_sub_id = 0;

        /* Timeout ID for auto-stopping discovery */
        private uint _discovery_timeout_id = 0;

        /* Emitted when a device is added (passes object path) */
        public signal void device_added (string object_path);

        /* Emitted when a device is removed */
        public signal void device_removed (string object_path);

        /* Emitted when the adapter changes state */
        public signal void adapter_changed ();

        /* Emitted when overall state changes */
        public signal void state_changed ();

        public Manager () {
            _devices = new GLib.HashTable<string, Device> (str_hash, str_equal);
        }

        /* Call after all signal handlers are connected */
        public void start () {
            initialize.begin ();
        }

        /* Connect to the system bus, subscribe to BlueZ signals,
         * then enumerate existing adapters and devices */
        private async void initialize () {
            try {
                _bus = yield Bus.@get (BusType.SYSTEM);

                /* Subscribe to InterfacesAdded from BlueZ ObjectManager */
                _added_sub_id = _bus.signal_subscribe (
                    "org.bluez",
                    "org.freedesktop.DBus.ObjectManager",
                    "InterfacesAdded",
                    null, null,
                    GLib.DBusSignalFlags.NONE,
                    on_interfaces_added_raw
                );

                /* Subscribe to InterfacesRemoved */
                _removed_sub_id = _bus.signal_subscribe (
                    "org.bluez",
                    "org.freedesktop.DBus.ObjectManager",
                    "InterfacesRemoved",
                    null, null,
                    GLib.DBusSignalFlags.NONE,
                    on_interfaces_removed_raw
                );

                /* Walk the BlueZ object tree to find existing objects */
                yield discover_bluez_objects ();

                state_changed ();

            } catch (Error e) {
                warning ("Nova Bluetooth: failed to connect to system bus: %s", e.message);
            }
        }

        /* Introspect /org/bluez and its children to find adapters and devices.
         * This is more reliable than parsing GetManagedObjects in Vala. */
        private async void discover_bluez_objects () {
            /* Introspect /org/bluez to find adapter paths like /org/bluez/hci0 */
            var adapter_paths = yield introspect_children ("/org/bluez");

            foreach (var apath in adapter_paths) {
                string full_adapter = "/org/bluez/" + apath;

                /* Check if this path has the Adapter1 interface */
                if (yield has_interface (full_adapter, "org.bluez.Adapter1")) {
                    if (adapter == null) {
                        create_adapter (full_adapter);
                    }
                }

                /* Introspect adapter children for device paths */
                var dev_paths = yield introspect_children (full_adapter);
                foreach (var dpath in dev_paths) {
                    string full_device = full_adapter + "/" + dpath;

                    if (yield has_interface (full_device, "org.bluez.Device1")) {
                        create_device (full_device);
                    }
                }
            }
        }

        /* Introspect a D-Bus path and return its child node names */
        private async string[] introspect_children (string path) {
            string[] children = {};
            try {
                var result = yield _bus.call (
                    "org.bluez", path,
                    "org.freedesktop.DBus.Introspectable",
                    "Introspect",
                    null, new GLib.VariantType ("(s)"),
                    GLib.DBusCallFlags.NONE, 5000
                );

                string xml;
                result.get ("(s)", out xml);

                /* Simple XML parsing: find <node name="..."/> entries */
                int pos = 0;
                while (true) {
                    int idx = xml.index_of ("<node name=\"", pos);
                    if (idx < 0) break;
                    int start = idx + 12;
                    int end = xml.index_of ("\"", start);
                    if (end < 0) break;
                    children += xml.substring (start, end - start);
                    pos = end + 1;
                }
            } catch (Error e) {
                /* Path might not exist, that's fine */
            }
            return children;
        }

        /* Check if a D-Bus object implements a given interface */
        private async bool has_interface (string path, string iface_name) {
            try {
                var result = yield _bus.call (
                    "org.bluez", path,
                    "org.freedesktop.DBus.Introspectable",
                    "Introspect",
                    null, new GLib.VariantType ("(s)"),
                    GLib.DBusCallFlags.NONE, 5000
                );

                string xml;
                result.get ("(s)", out xml);

                return xml.contains ("name=\"" + iface_name + "\"");
            } catch {
                return false;
            }
        }

        /* Raw signal handler for InterfacesAdded */
        private void on_interfaces_added_raw (
            GLib.DBusConnection conn,
            string? sender,
            string object_path,
            string interface_name,
            string signal_name,
            GLib.Variant parameters
        ) {
            /* parameters = (object_path, dict<string, dict<string,variant>>) */
            string path_str = parameters.get_child_value (0).get_string ();
            var ifaces_variant = parameters.get_child_value (1);

            var iter = ifaces_variant.iterator ();
            GLib.Variant? entry = null;
            bool has_adapter = false;
            bool has_device = false;

            while ((entry = iter.next_value ()) != null) {
                string iface_key = entry.get_child_value (0).get_string ();
                if (iface_key == "org.bluez.Adapter1") has_adapter = true;
                if (iface_key == "org.bluez.Device1") has_device = true;
            }

            if (has_adapter && adapter == null) {
                create_adapter (path_str);
                adapter_changed ();
                state_changed ();
            }

            if (has_device) {
                create_device (path_str);
            }
        }

        /* Raw signal handler for InterfacesRemoved */
        private void on_interfaces_removed_raw (
            GLib.DBusConnection conn,
            string? sender,
            string object_path,
            string interface_name,
            string signal_name,
            GLib.Variant parameters
        ) {
            /* parameters = (object_path, array<string>) */
            string path_str = parameters.get_child_value (0).get_string ();
            var ifaces_array = parameters.get_child_value (1);

            for (size_t i = 0; i < ifaces_array.n_children (); i++) {
                string iface_key = ifaces_array.get_child_value (i).get_string ();

                if (iface_key == "org.bluez.Adapter1" &&
                    adapter != null && adapter.object_path == path_str) {
                    adapter = null;
                    adapter_changed ();
                    state_changed ();
                }

                if (iface_key == "org.bluez.Device1" && _devices.contains (path_str)) {
                    _devices.remove (path_str);
                    device_removed (path_str);
                }
            }
        }

        /* Instantiate an Adapter wrapper and listen for its changes */
        private void create_adapter (string path) {
            adapter = new Adapter (path);
            adapter.changed.connect (() => {
                adapter_changed ();
                state_changed ();
            });
        }

        /* Instantiate a Device wrapper */
        private void create_device (string path) {
            if (_devices.contains (path)) return;

            var dev = new Device (path);
            _devices.insert (path, dev);
            device_added (path);
        }

        /* Return a list of all currently known devices */
        public GLib.List<weak Device> get_devices () {
            return _devices.get_values ();
        }

        /* Get a specific device by its object path */
        public Device? get_device (string path) {
            return _devices.lookup (path);
        }

        /* Start a 30-second discovery scan, then auto-stop */
        public void start_scan () {
            if (adapter == null || !adapter.powered) return;

            adapter.start_discovery ();
            state_changed ();

            /* Auto-stop after 30 seconds to save power */
            if (_discovery_timeout_id != 0) {
                GLib.Source.remove (_discovery_timeout_id);
            }
            _discovery_timeout_id = GLib.Timeout.add_seconds (30, () => {
                stop_scan ();
                _discovery_timeout_id = 0;
                return false;
            });
        }

        /* Stop the current discovery scan */
        public void stop_scan () {
            if (adapter == null) return;

            if (_discovery_timeout_id != 0) {
                GLib.Source.remove (_discovery_timeout_id);
                _discovery_timeout_id = 0;
            }

            adapter.stop_discovery ();
            state_changed ();
        }

        /* Toggle adapter power */
        public void toggle_power () {
            if (adapter == null) return;
            adapter.apply_powered.begin (!adapter.powered);
        }

        /* Remove a device from BlueZ (unpair) */
        public void remove_device (string path) {
            if (adapter == null) return;
            adapter.remove_device (path);
        }

        /* Check if Bluetooth is available and powered */
        public bool is_available () {
            return adapter != null;
        }

        public bool is_powered () {
            return adapter != null && adapter.powered;
        }

        public bool is_discovering () {
            return adapter != null && adapter.discovering;
        }
    }
}
