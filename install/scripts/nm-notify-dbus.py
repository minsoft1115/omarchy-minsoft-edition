#!/usr/bin/env python3
"""
Per-interface network connect/disconnect notifier with:
- fcntl file lock to prevent multiple instances
- Initial state snapshot on startup
- Event-based notify only when state changes
- Two-stage connected check: Link-Ready / Internet-Ready
- Ignore "fake disconnect" during reconnect process
- Optional default route requirement (per-interface or system-wide)
- Intermediate states logged but not notified
"""

import sys
import subprocess
import fcntl
from datetime import datetime
from typing import Dict, Any, Optional

from pyroute2 import IPRoute
from pyroute2.netlink.rtnl import ifinfmsg
from pyroute2.netlink.rtnl.ifinfmsg import IFF_RUNNING

APP = "net-hook"
ICON_ON = "network-transmit-receive"
ICON_OFF = "network-offline"

LOCK_FILE_PATH = "/tmp/net-hook.lock"  # for fcntl lock
_lock_fh = None

# Cache last known per-interface state: "connected", "disconnected", "intermediate"
state_cache: Dict[str, str] = {}

# Config flags
REQUIRE_DEFAULT_ROUTE = False       # True = require per-interface default route for connected
SYSTEM_WIDE_DEFAULT_OK = True       # True = any default route counts as Internet-ready


# ---------- Lock ----------
def acquire_lock_or_exit():
    """Acquire exclusive lock or exit if another instance is running"""
    global _lock_fh
    _lock_fh = open(LOCK_FILE_PATH, "w")
    try:
        fcntl.flock(_lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print(f"[ERROR] {APP} already running")
        sys.exit(1)


# ---------- Utility functions ----------
def log(*args):
    """Print timestamped log message"""
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    print(f"[{ts}] [NETLINK]", *args, flush=True)


def notify(title: str, body: str, icon: str):
    """Send desktop notification"""
    log("NOTIFY:", title, "|", body)
    try:
        subprocess.run(["notify-send", "-a", APP, "-i", icon, title, body], check=False)
    except Exception as e:
        log("[ERR] notify-send failed:", e)


def ifname(ip: IPRoute, idx: int) -> str:
    """Resolve interface index to name string"""
    try:
        for link in ip.get_links(idx):
            for k, v in link.get("attrs", []):
                if k == "IFLA_IFNAME":
                    return v
    except Exception:
        pass
    return f"if{idx}"


def read_sys(path: str) -> Optional[str]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except Exception:
        return None


def read_operstate(name: str) -> Optional[str]:
    return read_sys(f"/sys/class/net/{name}/operstate")


def read_carrier(name: str) -> bool:
    return read_sys(f"/sys/class/net/{name}/carrier") == "1"


def has_default_route(ip: IPRoute, idx: int) -> bool:
    """Check if default route exists via this interface (IPv4 or IPv6)"""
    try:
        for r in ip.get_routes(family=2, oif=idx):
            if r.get("dst_len", 0) == 0:
                return True
        for r in ip.get_routes(family=10, oif=idx):
            if r.get("dst_len", 0) == 0:
                return True
    except Exception:
        pass
    return False


def has_any_default(ip: IPRoute) -> bool:
    """Check if any default route exists in system routing tables"""
    try:
        for r in ip.get_routes(family=2):
            if r.get("dst_len", 0) == 0:
                return True
        for r in ip.get_routes(family=10):
            if r.get("dst_len", 0) == 0:
                return True
    except Exception:
        pass
    return False


# ---------- State classification ----------
def classify_state(ip: IPRoute, name: str, idx: int) -> str:
    """
    Return "connected", "disconnected", or "intermediate"
    """
    oper = read_operstate(name)
    carrier_ok = read_carrier(name)
    flags = 0
    try:
        links = ip.get_links(idx)
        if links:
            flags = links[0].get("flags", 0)
    except Exception:
        pass
    flag_run = bool(flags & IFF_RUNNING)

    # Link-Ready stage
    link_ready = (oper == "up") and carrier_ok and flag_run

    # Internet-Ready stage
    def_ok = has_default_route(ip, idx)
    internet_ready = link_ready and (
        def_ok or
        (SYSTEM_WIDE_DEFAULT_OK and has_any_default(ip)) or
        (not REQUIRE_DEFAULT_ROUTE)
    )

    if (not carrier_ok) or (oper in ("down", "lowerlayerdown", "notpresent")):
        return "disconnected"

    if internet_ready:
        return "connected"

    return "intermediate"


def is_real_disconnect(ip: IPRoute, name: str, idx: int) -> bool:
    """Return True only if definitely disconnected (no link, carrier down)"""
    oper = read_operstate(name)
    carrier_ok = read_carrier(name)
    return (not carrier_ok) and (oper in ("down", "lowerlayerdown", "notpresent"))


# ---------- Event handling ----------
def handle_link(ip: IPRoute, msg: Dict[str, Any]):
    idx = msg.get("index")
    name = ifname(ip, idx)
    if name == "lo" or name.startswith(("veth", "docker", "br-", "tap")):
        return

    current = classify_state(ip, name, idx)
    prev = state_cache.get(name)
    log(f"EVENT {name}: current={current}, prev={prev}")

    # state change only
    if current == prev:
        log(f"INFO {name}: state unchanged, skip notify")
        return

    if current == "connected":
        notify(f"{name} Connected", name, ICON_ON)
        state_cache[name] = "connected"
        return

    if current == "disconnected":
        if is_real_disconnect(ip, name, idx):
            notify(f"{name} Disconnected", name, ICON_OFF)
            state_cache[name] = "disconnected"
        else:
            log(f"INFO {name}: fake disconnect ignored (cache stays {prev})")
        return

    log(f"INFO {name}: intermediate (no notify)")
    state_cache[name] = "intermediate"


# ---------- Init and main ----------
def init_state_cache():
    with IPRoute() as ip:
        for link in ip.get_links():
            idx = link.get("index")
            name = None
            for k, v in link.get("attrs", []):
                if k == "IFLA_IFNAME":
                    name = v
                    break
            if not name or name == "lo" or name.startswith(("veth", "docker", "br-", "tap")):
                continue
            state_cache[name] = classify_state(ip, name, idx)
            log(f"INIT {name}: state={state_cache[name]}")


def main():
    acquire_lock_or_exit()
    init_state_cache()
    with IPRoute() as ip:
        ip.bind()
        log("Listening for RTNL link events...")
        while True:
            try:
                for msg in ip.get():
                    if msg["header"]["type"] in (ifinfmsg.RTM_NEWLINK, ifinfmsg.RTM_DELLINK):
                        handle_link(ip, msg)
            except KeyboardInterrupt:
                break
            except Exception as e:
                log("[ERR]", e)


if __name__ == "__main__":
    main()
