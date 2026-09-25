#!/usr/bin/env python3
import sys
import time

import dbus

DESKTOP_ID = "org.DankMaterialShell"
DISTANCE_THRESHOLD = 1000
MAX_WAIT_SECONDS = 25
POLL_INTERVAL_SECONDS = 1.0


def fail(message):
    print(message, file=sys.stderr, flush=True)
    sys.exit(1)


def main():
    try:
        bus = dbus.SystemBus()
        manager = bus.get_object("org.freedesktop.GeoClue2", "/org/freedesktop/GeoClue2/Manager")
        manager_iface = dbus.Interface(manager, "org.freedesktop.GeoClue2.Manager")
        client_path = manager_iface.GetClient()
        client = bus.get_object("org.freedesktop.GeoClue2", client_path)

        properties = dbus.Interface(client, "org.freedesktop.DBus.Properties")
        properties.Set("org.freedesktop.GeoClue2.Client", "DesktopId", dbus.String(DESKTOP_ID))
        properties.Set("org.freedesktop.GeoClue2.Client", "DistanceThreshold", dbus.UInt32(DISTANCE_THRESHOLD))

        client_iface = dbus.Interface(client, "org.freedesktop.GeoClue2.Client")
        client_iface.Start()

        deadline = time.time() + MAX_WAIT_SECONDS
        location_path = "/"
        while time.time() < deadline:
            location_path = properties.Get("org.freedesktop.GeoClue2.Client", "Location")
            if str(location_path) != "/":
                break
            time.sleep(POLL_INTERVAL_SECONDS)

        if str(location_path) == "/":
            fail("geoclue: no location fix within %ds" % MAX_WAIT_SECONDS)

        location = bus.get_object("org.freedesktop.GeoClue2", location_path)
        location_properties = dbus.Interface(location, "org.freedesktop.DBus.Properties")
        lat = float(location_properties.Get("org.freedesktop.GeoClue2.Location", "Latitude"))
        lon = float(location_properties.Get("org.freedesktop.GeoClue2.Location", "Longitude"))
        acc = float(location_properties.Get("org.freedesktop.GeoClue2.Location", "Accuracy"))

        try:
            client_iface.Stop()
        except dbus.exceptions.DBusException:
            pass

        print("%.6f,%.6f,%.1f" % (lat, lon, acc), flush=True)
        sys.exit(0)
    except dbus.exceptions.DBusException as error:
        fail("geoclue: %s" % (error.get_dbus_message() or error))


if __name__ == "__main__":
    main()