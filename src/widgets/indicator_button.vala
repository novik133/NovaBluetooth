/* IndicatorButton: the panel button widget that sits in the XFCE panel.
 * Shows a Bluetooth icon whose appearance changes based on state.
 * Opens a popup window with device controls when clicked.
 *
 * GtkPopover does not work inside XFCE panel plugins because
 * the panel window is too small. Instead we use a separate GtkWindow
 * with POPUP_MENU type hint, positioned via
 * xfce_panel_plugin_position_widget().
 *
 * Author: Kamil 'Novik' Nowicki <noviktech.com>
 * Repository: https://github.com/noviktech133/NovaBluetooth
 * License: GPL-2.0-or-later
 */

namespace NovaBluetooth {

    public class IndicatorButton : Gtk.ToggleButton {

        /* Bluetooth manager powering this indicator */
        private Manager _manager;

        /* Icon shown in the panel */
        private Gtk.Image _icon;

        /* Popup window shown on click (not a GtkPopover) */
        private Gtk.Window _popup;

        /* Content inside the popup */
        private PopoverMenu _popup_menu;

        /* Reference to the XFCE panel plugin for positioning */
        private Xfce.PanelPlugin _plugin;

        /* Track popup visibility to prevent block_autohide imbalance */
        private bool _popup_visible = false;

        public IndicatorButton (Xfce.PanelPlugin plugin, Manager manager) {
            _plugin = plugin;
            _manager = manager;

            build_button ();
            build_popup ();
            connect_signals ();
            update_icon ();
        }

        /* Build the toggle button for the panel */
        private void build_button () {
            get_style_context ().add_class ("nova-bt-panel-button");
            relief = Gtk.ReliefStyle.NONE;

            /* Panel icon */
            _icon = new Gtk.Image.from_icon_name (
                "bluetooth-active",
                Gtk.IconSize.BUTTON
            );
            add (_icon);

            /* Adjust icon size to match panel */
            int size = _plugin.get_size () / (int) _plugin.get_nrows ();
            int icon_size = (int) (size * 0.7);
            _icon.pixel_size = icon_size.clamp (16, 48);

            /* Register with the panel so right-click menu works */
            _plugin.add_action_widget (this);

            show_all ();
        }

        /* Build the popup window that appears on click */
        private void build_popup () {
            _popup = new Gtk.Window (Gtk.WindowType.TOPLEVEL);
            _popup.type_hint = Gdk.WindowTypeHint.POPUP_MENU;
            _popup.decorated = false;
            _popup.resizable = false;
            _popup.skip_taskbar_hint = true;
            _popup.skip_pager_hint = true;
            _popup.set_keep_above (true);
            _popup.stick ();

            /* Set a fixed width */
            _popup.set_default_size (320, -1);

            /* Enable RGBA visual for true rounded corners */
            _popup.set_app_paintable (true);
            var screen = _popup.get_screen ();
            var visual = screen.get_rgba_visual ();
            if (visual != null) {
                _popup.set_visual (visual);
            }

            /* Custom draw: transparent window + rounded opaque background */
            _popup.draw.connect ((cr) => {
                int w = _popup.get_allocated_width ();
                int h = _popup.get_allocated_height ();
                double radius = 10.0;

                /* Clear to fully transparent */
                cr.set_source_rgba (0, 0, 0, 0);
                cr.set_operator (Cairo.Operator.SOURCE);
                cr.paint ();
                cr.set_operator (Cairo.Operator.OVER);

                /* Draw rounded rectangle path */
                cr.new_sub_path ();
                cr.arc (w - radius, radius, radius, -Math.PI / 2.0, 0);
                cr.arc (w - radius, h - radius, radius, 0, Math.PI / 2.0);
                cr.arc (radius, h - radius, radius, Math.PI / 2.0, Math.PI);
                cr.arc (radius, radius, radius, Math.PI, 3.0 * Math.PI / 2.0);
                cr.close_path ();

                /* Fill with theme background */
                var style = _popup.get_style_context ();
                Gdk.RGBA bg;
                style.lookup_color ("theme_bg_color", out bg);
                cr.set_source_rgba (bg.red, bg.green, bg.blue, bg.alpha);
                cr.fill_preserve ();

                /* Draw border */
                Gdk.RGBA border_color;
                if (!style.lookup_color ("borders", out border_color)) {
                    border_color = { 0.5, 0.5, 0.5, 0.3 };
                }
                cr.set_source_rgba (border_color.red, border_color.green, border_color.blue, border_color.alpha);
                cr.set_line_width (1.0);
                cr.stroke ();

                /* Propagate draw to children */
                return false;
            });

            _popup.get_style_context ().add_class ("nova-bt-popup");

            /* Build the menu content with internal padding */
            _popup_menu = new PopoverMenu (_manager);
            _popup.add (_popup_menu);

            /* Close on Escape key */
            _popup.key_press_event.connect ((event) => {
                if (event.keyval == Gdk.Key.Escape) {
                    hide_popup ();
                    return true;
                }
                return false;
            });

            /* Close on click outside the popup.
             * With the seat grab, clicks outside are delivered to us
             * with coordinates outside our allocation. */
            _popup.button_press_event.connect ((event) => {
                int w = _popup.get_allocated_width ();
                int h = _popup.get_allocated_height ();
                if (event.x < 0 || event.y < 0 || event.x > w || event.y > h) {
                    hide_popup ();
                    return true;
                }
                return false;
            });
        }

        /* Wire up signals */
        private void connect_signals () {
            _manager.adapter_changed.connect (update_icon);
            _manager.state_changed.connect (update_icon);

            /* React to panel size changes */
            _plugin.size_changed.connect ((size) => {
                int icon_size = (int) (size / (int) _plugin.get_nrows () * 0.7);
                _icon.pixel_size = icon_size.clamp (16, 48);
                return true;
            });

            /* Toggle popup when the panel button is toggled */
            toggled.connect (() => {
                if (active) {
                    show_popup ();
                } else {
                    hide_popup ();
                }
            });
        }

        /* Show the popup window, positioned next to the panel button */
        private void show_popup () {
            if (_popup_visible) return;
            _popup_visible = true;

            /* Let the panel know we need to stay visible */
            _plugin.block_autohide (true);

            /* Show content first so the window gets a proper size */
            _popup_menu.show_all ();
            _popup.show_all ();

            /* Use XFCE's positioning helper to place the window
             * adjacent to the panel, accounting for panel position
             * (top, bottom, left, right) */
            int x, y;
            _plugin.position_widget (_popup, this, out x, out y);

            /* Clamp to screen bounds so the popup doesn't go off-screen */
            var display = _popup.get_screen ();
            int monitor_num = display.get_monitor_at_window (this.get_window ());
            Gdk.Rectangle monitor_geo;
            display.get_monitor_geometry (monitor_num, out monitor_geo);

            int popup_w, popup_h;
            _popup.get_size (out popup_w, out popup_h);

            if (x + popup_w > monitor_geo.x + monitor_geo.width) {
                x = monitor_geo.x + monitor_geo.width - popup_w - 4;
            }
            if (x < monitor_geo.x) {
                x = monitor_geo.x + 4;
            }
            if (y + popup_h > monitor_geo.y + monitor_geo.height) {
                y = monitor_geo.y + monitor_geo.height - popup_h - 4;
            }
            if (y < monitor_geo.y) {
                y = monitor_geo.y + 4;
            }

            _popup.move (x, y);
            _popup.present ();

            /* Grab pointer and keyboard so we get Escape and
             * can detect clicks outside the popup */
            _popup.grab_focus ();
            var gdk_win = _popup.get_window ();
            if (gdk_win != null) {
                var seat = Gdk.Display.get_default ().get_default_seat ();
                seat.grab (
                    gdk_win,
                    Gdk.SeatCapabilities.KEYBOARD | Gdk.SeatCapabilities.POINTER,
                    true, null, null, null
                );
            }
        }

        /* Hide the popup and reset button state */
        private void hide_popup () {
            if (!_popup_visible) return;
            _popup_visible = false;

            /* Release the grab */
            var seat = Gdk.Display.get_default ().get_default_seat ();
            seat.ungrab ();

            _popup.hide ();
            _plugin.block_autohide (false);

            /* Reset toggle without re-triggering the signal */
            if (active) {
                active = false;
            }
        }

        /* Update the panel icon based on Bluetooth state */
        private void update_icon () {
            var ctx = _icon.get_style_context ();

            /* Remove all state classes first */
            ctx.remove_class ("nova-bt-icon-disabled");
            ctx.remove_class ("nova-bt-icon-active");
            ctx.remove_class ("nova-bt-icon-connected");

            if (!_manager.is_available ()) {
                _icon.icon_name = "bluetooth-disabled";
                ctx.add_class ("nova-bt-icon-disabled");
                set_tooltip_text ("Bluetooth unavailable");
                return;
            }

            if (!_manager.is_powered ()) {
                _icon.icon_name = "bluetooth-disabled";
                ctx.add_class ("nova-bt-icon-disabled");
                set_tooltip_text ("Bluetooth off");
                return;
            }

            /* Check if any device is connected */
            bool has_connected = false;
            var devices = _manager.get_devices ();
            foreach (var dev in devices) {
                if (dev.connected) {
                    has_connected = true;
                    break;
                }
            }

            if (has_connected) {
                _icon.icon_name = "bluetooth-active";
                ctx.add_class ("nova-bt-icon-connected");
                set_tooltip_text ("Bluetooth: connected");
            } else {
                _icon.icon_name = "bluetooth-active";
                ctx.add_class ("nova-bt-icon-active");
                set_tooltip_text ("Bluetooth: on");
            }
        }
    }
}
