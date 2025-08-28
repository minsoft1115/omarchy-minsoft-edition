#!/usr/bin/env python3
import asyncio
import subprocess
import fcntl
from dbus_next.aio import MessageBus
from dbus_next import BusType
from dbus_next.message import Message
from dbus_next.constants import MessageType

# DBus constants for BlueZ
BLUEZ = 'org.bluez'
OBJMGR = 'org.freedesktop.DBus.ObjectManager'
PROPS = 'org.freedesktop.DBus.Properties'
DEV_IFACE = 'org.bluez.Device1'

# App/notification config
APP_NAME = 'bt-hook'     # For swaync categorization
ICON = 'bluetooth'       # Icon name or absolute path
URGENCY_ON = 'normal'
URGENCY_OFF = 'low'

# Single-instance lock (fcntl)
LOCK_FILE_PATH = '/tmp/bt-hook.lock'
_lock_fh = None


def acquire_lock_or_exit():
    """Acquire exclusive file lock to prevent multiple instances."""
    global _lock_fh
    _lock_fh = open(LOCK_FILE_PATH, 'w')
    try:
        fcntl.flock(_lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        # Another instance holds the lock
        print(f"[ERROR] {APP_NAME} is already running.")
        raise SystemExit(1)


def notify(summary: str, body: str, urgency: str = 'normal', icon: str = ICON, app_name: str = APP_NAME):
    """Send a notification using notify-send."""
    subprocess.run(
        ['notify-send', '-a', app_name, '-i', icon, '-u', urgency, summary, body],
        check=False
    )


async def dbus_get(bus: MessageBus, path: str, iface: str, prop: str):
    """Generic helper to get a property from DBus."""
    msg = Message(
        destination=BLUEZ,
        path=path,
        interface=PROPS,
        member='Get',
        signature='ss',
        body=[iface, prop]
    )
    reply = await bus.call(msg)
    if reply.message_type == MessageType.METHOD_RETURN:
        val = reply.body[0]
        return getattr(val, 'value', val)  # Unwrap Variant if needed
    return None


async def fetch_initial_names(bus: MessageBus):
    """Get initial mapping of device object paths to display names."""
    names = {}
    msg = Message(
        destination=BLUEZ,
        path='/',
        interface=OBJMGR,
        member='GetManagedObjects'
    )
    reply = await bus.call(msg)
    if reply.message_type == MessageType.METHOD_RETURN:
        objects = reply.body[0]
        for path, ifaces in objects.items():
            dev = ifaces.get(DEV_IFACE)
            if dev:
                alias_v = dev.get('Alias')
                name_v = dev.get('Name')
                alias = getattr(alias_v, 'value', alias_v)
                name = getattr(name_v, 'value', name_v)
                display = alias or name
                if isinstance(display, str) and display:
                    names[path] = display
    return names


async def main():
    # Enforce single instance
    acquire_lock_or_exit()

    # Connect to the system bus
    bus = await MessageBus(bus_type=BusType.SYSTEM).connect()

    # Cache device names
    name_cache = await fetch_initial_names(bus)

    async def handle_notify(dev_path: str, connected: bool):
        """Send a connect/disconnect notification for the given device path."""
        # Get name from cache or query DBus
        display = name_cache.get(dev_path)
        if not display:
            alias = await dbus_get(bus, dev_path, DEV_IFACE, 'Alias')
            name = await dbus_get(bus, dev_path, DEV_IFACE, 'Name')
            display = alias or name or 'Unknown device'
            if isinstance(display, str):
                name_cache[dev_path] = display

        if connected:
            notify('Bluetooth Connected', f'{display} connected', urgency=URGENCY_ON)
        else:
            notify('Bluetooth Disconnected', f'{display} disconnected', urgency=URGENCY_OFF)

    def on_signal(msg: Message):
        """Handle PropertiesChanged signals for Bluetooth devices."""
        if msg.message_type != MessageType.SIGNAL:
            return
        if msg.interface != PROPS or msg.member != 'PropertiesChanged':
            return
        if len(msg.body) < 3:
            return

        iface, changed, _invalidated = msg.body
        if iface != DEV_IFACE:
            return

        connected_v = changed.get('Connected')
        if connected_v is None:
            return

        connected = getattr(connected_v, 'value', connected_v)
        asyncio.create_task(handle_notify(msg.path, connected))

    # Add match rule to only receive BlueZ PropertiesChanged signals
    await bus.call(Message(
        destination='org.freedesktop.DBus',
        path='/org/freedesktop/DBus',
        interface='org.freedesktop.DBus',
        member='AddMatch',
        signature='s',
        body=[f"type='signal',interface='{PROPS}',sender='{BLUEZ}'"]
    ))

    bus.add_message_handler(on_signal)

    # Keep running forever
    await asyncio.get_event_loop().create_future()


if __name__ == '__main__':
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
