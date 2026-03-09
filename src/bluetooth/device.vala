/* Device model: wraps a BlueZ Device1 D-Bus proxy into a GObject
 * with observable properties for the UI layer to bind against.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/noviktech133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class Device : GLib.Object {

        /* D-Bus object path uniquely identifying this device in BlueZ */
        public string object_path { get; construct; }

        /* Human-readable name shown in the device list */
        public string name { get; set; default = "Unknown"; }

        /* Hardware MAC address */
        public string address { get; set; default = ""; }

        /* Icon name hint from BlueZ (e.g. "audio-card", "input-mouse") */
        public string icon { get; set; default = "bluetooth"; }

        /* Whether the device is currently paired */
        public bool paired { get; set; default = false; }

        /* Whether the device is currently connected */
        public bool connected { get; set; default = false; }

        /* Whether the device is trusted */
        public bool trusted { get; set; default = false; }

        /* Signal strength, -1 means unknown */
        public int16 rssi { get; set; default = -1; }

        /* Battery percentage, -1 means unavailable */
        public int battery_percentage { get; set; default = -1; }

        /* Bluetooth device class for categorisation */
        public uint32 device_class { get; set; default = 0; }

        /* The D-Bus proxy for direct BlueZ calls */
        private BluezDevice1? _proxy = null;

        /* Properties proxy for listening to changes */
        private FreedesktopProperties? _props_proxy = null;

        /* Emitted when any property changes so the UI can refresh */
        public signal void changed ();

        public Device (string object_path) {
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

        /* Connect to BlueZ D-Bus proxy for this device */
        private async void init_proxy () {
            try {
                _proxy = yield Bus.get_proxy<BluezDevice1> (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path
                );

                _props_proxy = yield Bus.get_proxy<FreedesktopProperties> (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path
                );

                /* Listen for property changes on this device */
                _props_proxy.properties_changed.connect (on_properties_changed);

                /* Pull initial values from the proxy */
                sync_properties ();

            } catch (Error e) {
                warning ("Failed to init device proxy for %s: %s", object_path, e.message);
            }
        }

        /* Read current property values from the BlueZ proxy */
        private void sync_properties () {
            if (_proxy == null) return;

            try {
                name = _proxy.name ?? _proxy.alias ?? "Unknown";
                address = _proxy.address ?? "";
                icon = map_icon (_proxy.icon);
                paired = _proxy.paired;
                connected = _proxy.connected;
                trusted = _proxy.trusted;
                device_class = _proxy.@class;

                try {
                    rssi = _proxy.rssi;
                } catch {
                    rssi = -1;
                }
            } catch (Error e) {
                warning ("Failed to read properties for %s: %s", object_path, e.message);
            }

            /* Try reading battery level if available */
            fetch_battery.begin ();

            changed ();
        }

        /* Try to get battery info from the Battery1 interface */
        private async void fetch_battery () {
            try {
                var battery = yield Bus.get_proxy<BluezBattery1> (
                    BusType.SYSTEM,
                    "org.bluez",
                    object_path
                );
                int new_pct = (int) battery.percentage;
                if (new_pct != battery_percentage) {
                    battery_percentage = new_pct;
                    changed ();
                }
            } catch {
                if (battery_percentage != -1) {
                    battery_percentage = -1;
                    changed ();
                }
            }
        }

        /* Called when BlueZ emits a property change for this device */
        private void on_properties_changed (
            string iface,
            GLib.HashTable<string, GLib.Variant> changed,
            string[] invalidated
        ) {
            if (iface != "org.bluez.Device1" && iface != "org.bluez.Battery1") return;

            /* Re-read everything — simple and reliable */
            sync_properties ();
        }

        /* Map BlueZ icon hint to a GTK icon name */
        private string map_icon (string? bluez_icon) {
            if (bluez_icon == null || bluez_icon == "") return "bluetooth";

            switch (bluez_icon) {
                case "audio-card":
                case "audio-headphones":
                case "audio-headset":
                    return "audio-headphones";
                case "input-keyboard":
                    return "input-keyboard";
                case "input-mouse":
                    return "input-mouse";
                case "input-gaming":
                    return "input-gaming";
                case "input-tablet":
                    return "input-tablet";
                case "phone":
                    return "phone";
                case "computer":
                    return "computer";
                case "camera-photo":
                    return "camera-photo";
                case "printer":
                    return "printer";
                default:
                    return "bluetooth";
            }
        }

        /* Ask BlueZ to connect to this device */
        public bool connect_device () {
            if (_proxy == null) return false;
            try {
                _proxy.connect ();
                return true;
            } catch (Error e) {
                warning ("Connect failed for %s: %s", address, e.message);
                return false;
            }
        }

        /* Ask BlueZ to disconnect this device */
        public bool disconnect_device () {
            if (_proxy == null) return false;
            try {
                _proxy.disconnect ();
                return true;
            } catch (Error e) {
                warning ("Disconnect failed for %s: %s", address, e.message);
                return false;
            }
        }

        /* Ask BlueZ to pair with this device */
        public bool pair_device () {
            if (_proxy == null) return false;
            try {
                _proxy.pair ();
                return true;
            } catch (Error e) {
                warning ("Pair failed for %s: %s", address, e.message);
                return false;
            }
        }

        /* Toggle trusted state */
        public void apply_trusted (bool val) {
            if (_proxy == null) return;
            try {
                _proxy.trusted = val;
            } catch (Error e) {
                warning ("Set trusted failed for %s: %s", address, e.message);
            }
        }

        /* Returns a user-friendly status string */
        public string get_status_text () {
            if (connected) return "Connected";
            if (paired) return "Paired";
            return "Available";
        }
    }
}
