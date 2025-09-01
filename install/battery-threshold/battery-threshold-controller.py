#!/usr/bin/env python3

import dbus

bus = dbus.SystemBus()
proxy = bus.get_object('org.minsoft1115.BatteryThreshold', '/org/example/BatteryThreshold')
iface = dbus.Interface(proxy, 'org.minsoft1115.BatteryThreshold')

battery_id = "BAT1"
value = 80

response = iface.SetThreshold(battery_id, value)
print(response)

