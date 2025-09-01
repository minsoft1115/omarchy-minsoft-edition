#!/usr/bin/env python3
import dbus
import dbus.service
import dbus.mainloop.glib
from gi.repository import GLib

BUS_NAME = 'org.minsoft1115.BatteryThreshold'
OBJECT_PATH = '/org/minsoft1115/BatteryThreshold'

class BatteryThresholdService(dbus.service.Object):
    def __init__(self, bus):
        dbus.service.Object.__init__(self, bus, OBJECT_PATH)

    @dbus.service.method(BUS_NAME, in_signature='su', out_signature='s')
    def SetThreshold(self, battery_id, value):
        print(f"Battery {battery_id} threshold set to {value}%")

        script_path = "/usr/local/sbin/set-battery-threshold.sh"

        try:
            result = subprocess.run(
                [script_path, battery_id, str(value)],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            output = result.stdout.strip()
            return output
        except subprocess.CalledProcessError as e:
            error_msg = e.stderr.strip()
            print(f"Error executing script: {error_msg}")
            return f"Error: {error_msg}"

def main():
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

    system_bus = dbus.SystemBus()
    name = dbus.service.BusName(BUS_NAME, system_bus)
    service = BatteryThresholdService(system_bus)

    loop = GLib.MainLoop()
    print("BatteryThresholdService running...")
    loop.run()

if __name__ == '__main__':
    main()

