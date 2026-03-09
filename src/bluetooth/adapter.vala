/* Adapter model: wraps a BlueZ Adapter1 D-Bus proxy.
 * Controls power, discovery, and adapter-level settings.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/novik133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class Adapter : GLib.Object {

        /* D-Bus object path for this adapter (e.g. /org/bluez/hci0) */
        public string object_path { get; construct; }

        /* Adapter display name */
        public string name { get; set; default = "Bluetooth"; }

        /* MAC address of the adapter */
        public string address { get; set; default = ""; }

        /* Whether the adapter radio is powered on */
        public bool powered { get; set; default = false; }

        /* Whether discovery is currently running */
        public bool discovering { get; set; default = false; }

        /* Whether the adapter is discoverable to other devices */
        public bool discoverable { get; set; default = false; }

        /* D-Bus proxy for adapter operations */
        private BluezAdapter1? _proxy = null;

        /* Properties proxy for change notifications */
        private FreedesktopProperties? _props_proxy = null;

        /* Fired when adapter state changes */
        public signal void changed ();

        public Adapter (string object_path) {
            Object (object_path: object_path);
        }

        construct {
            /* Defer proxy init to the main loop so the caller
             * can connect to our 'changed' signal first */
            GLib.Idle.add (() => {
                init_proxy.begin ();
                return false;
            });
        }

        /* Acquire D-Bus proxies for the adapter */
        private async void init_proxy () {
            try {
                _proxy = yield Bus.get_proxy<BluezAdapter1> (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path
                );

                _props_proxy = yield Bus.get_proxy<FreedesktopProperties> (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path
                );

                _props_proxy.properties_changed.connect (on_properties_changed);

                sync_properties ();

            } catch (Error e) {
                warning ("Failed to init adapter proxy for %s: %s", object_path, e.message);
            }
        }

        /* Pull current state from the proxy */
        private void sync_properties () {
            if (_proxy == null) return;

            try {
                name = _proxy.alias ?? _proxy.name ?? "Bluetooth";
                address = _proxy.address ?? "";
                powered = _proxy.powered;
                discovering = _proxy.discovering;
                discoverable = _proxy.discoverable;
            } catch (Error e) {
                warning ("Failed to read adapter properties: %s", e.message);
            }

            changed ();
        }

        /* React to BlueZ property change signals */
        private void on_properties_changed (
            string iface,
            GLib.HashTable<string, GLib.Variant> changed_props,
            string[] invalidated
        ) {
            if (iface != "org.bluez.Adapter1") return;
            sync_properties ();
        }

        /* Turn the adapter on or off */
        public async void apply_powered (bool on) {
            if (_proxy == null) return;
            try {
                _proxy.powered = on;
            } catch (Error e) {
                warning ("Failed to set powered: %s", e.message);
            }
        }

        /* Begin scanning for nearby Bluetooth devices */
        public void start_discovery () {
            if (_proxy == null) return;
            try {
                _proxy.start_discovery ();
            } catch (Error e) {
                /* "Already discovering" is not a real error */
                if (!e.message.contains ("Already")) {
                    warning ("Failed to start discovery: %s", e.message);
                }
            }
        }

        /* Stop scanning */
        public void stop_discovery () {
            if (_proxy == null) return;
            try {
                _proxy.stop_discovery ();
            } catch (Error e) {
                if (!e.message.contains ("Not")) {
                    warning ("Failed to stop discovery: %s", e.message);
                }
            }
        }

        /* Remove a device from the adapter's known list */
        public void remove_device (string device_path) {
            if (_proxy == null) return;
            try {
                _proxy.remove_device (new ObjectPath (device_path));
            } catch (Error e) {
                warning ("Failed to remove device %s: %s", device_path, e.message);
            }
        }

        /* Toggle discoverable mode */
        public async void apply_discoverable (bool val) {
            if (_proxy == null) return;
            try {
                _proxy.discoverable = val;
            } catch (Error e) {
                warning ("Failed to set discoverable: %s", e.message);
            }
        }

        public bool is_ready () {
            return _proxy != null;
        }
    }
}
