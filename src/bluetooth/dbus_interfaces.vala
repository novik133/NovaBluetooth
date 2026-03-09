/* D-Bus interface definitions for BlueZ and freedesktop.
 * Vala uses these to auto-generate GDBus proxy classes,
 * allowing type-safe communication with the BlueZ daemon.
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/novik133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

/* BlueZ Adapter1: controls the local Bluetooth adapter hardware */
[DBus (name = "org.bluez.Adapter1", timeout = 120000)]
public interface BluezAdapter1 : GLib.Object {
    public abstract void start_discovery () throws GLib.Error;
    public abstract void stop_discovery () throws GLib.Error;
    public abstract void remove_device (GLib.ObjectPath device) throws GLib.Error;

    public abstract string address { owned get; }
    public abstract string name { owned get; }
    public abstract string alias { owned get; set; }
    public abstract bool powered { get; set; }
    public abstract bool discoverable { get; set; }
    public abstract bool pairable { get; set; }
    public abstract bool discovering { get; }
    public abstract uint32 discoverable_timeout { get; set; }
}

/* BlueZ Device1: represents a remote Bluetooth device */
[DBus (name = "org.bluez.Device1", timeout = 120000)]
public interface BluezDevice1 : GLib.Object {
    public abstract void connect () throws GLib.Error;
    public abstract void disconnect () throws GLib.Error;
    public abstract void pair () throws GLib.Error;
    public abstract void cancel_pairing () throws GLib.Error;

    public abstract string address { owned get; }
    public abstract string name { owned get; }
    public abstract string alias { owned get; set; }
    public abstract string icon { owned get; }
    public abstract bool paired { get; }
    public abstract bool trusted { get; set; }
    public abstract bool blocked { get; set; }
    public abstract bool connected { get; }
    public abstract bool legacy_pairing { get; }
    public abstract int16 rssi { get; }
    public abstract GLib.ObjectPath adapter { owned get; }
    [DBus (name = "UUIDs")]
    public abstract string[] uuids { owned get; }
    public abstract uint32 @class { get; }
    public abstract uint16 appearance { get; }
}

/* BlueZ AgentManager1: registers pairing agents */
[DBus (name = "org.bluez.AgentManager1", timeout = 120000)]
public interface BluezAgentManager1 : GLib.Object {
    public abstract void register_agent (GLib.ObjectPath agent, string capability) throws GLib.Error;
    public abstract void unregister_agent (GLib.ObjectPath agent) throws GLib.Error;
    public abstract void request_default_agent (GLib.ObjectPath agent) throws GLib.Error;
}

/* freedesktop ObjectManager: enumerates all BlueZ-managed objects */
[DBus (name = "org.freedesktop.DBus.ObjectManager", timeout = 120000)]
public interface FreedesktopObjectManager : GLib.Object {
    public abstract GLib.HashTable<GLib.ObjectPath, GLib.HashTable<string, GLib.HashTable<string, GLib.Variant>>> get_managed_objects () throws GLib.Error;
    public signal void interfaces_added (GLib.ObjectPath object_path, GLib.HashTable<string, GLib.HashTable<string, GLib.Variant>> interfaces);
    public signal void interfaces_removed (GLib.ObjectPath object_path, string[] interfaces);
}

/* freedesktop Properties: watches for property changes on any interface */
[DBus (name = "org.freedesktop.DBus.Properties", timeout = 120000)]
public interface FreedesktopProperties : GLib.Object {
    public abstract GLib.Variant get (string interface_name, string property_name) throws GLib.Error;
    public abstract void set (string interface_name, string property_name, GLib.Variant value) throws GLib.Error;
    public abstract GLib.HashTable<string, GLib.Variant> get_all (string interface_name) throws GLib.Error;
    public signal void properties_changed (string interface_name, GLib.HashTable<string, GLib.Variant> changed_properties, string[] invalidated_properties);
}

/* BlueZ Battery1: provides battery level for supported devices */
[DBus (name = "org.bluez.Battery1", timeout = 120000)]
public interface BluezBattery1 : GLib.Object {
    public abstract uint8 percentage { get; }
}
