#!/usr/bin/python3
"""Manage a VM's SPICE socket in Remote Viewer's recent connections."""

import subprocess
import sys

import gi

gi.require_version("Gtk", "3.0")
from gi.repository import GLib, Gtk


def main(domain: str, remove: bool = False) -> None:
    uri = f"spice+unix:///tmp/{domain}.sock"
    recent = Gtk.RecentManager.get_default()

    if remove:
        domains = subprocess.run(
            ["virsh", "-c", "qemu:///system", "list", "--all", "--name"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.splitlines()
        if domain in domains:
            print(f"Keeping Remote Viewer connection; {domain} still exists")
            return
        if not recent.has_item(uri):
            print(f"Remote Viewer connection already absent: {uri}")
            return
        if not recent.remove_item(uri):
            raise RuntimeError(f"Could not remove {uri} from Remote Viewer")
    else:
        metadata = Gtk.RecentData()
        metadata.display_name = domain
        metadata.mime_type = "application/x-spice"
        metadata.app_name = "remote-viewer"
        metadata.app_exec = "remote-viewer %u"
        metadata.is_private = False
        if not recent.add_full(uri, metadata):
            raise RuntimeError(f"Could not register {uri} with Remote Viewer")

    # GTK saves recent items on an idle timer. Keep its main loop running long
    # enough for the entry to reach recently-used.xbel before this process exits.
    loop = GLib.MainLoop()
    GLib.timeout_add(1000, loop.quit)
    loop.run()
    action = "Removed" if remove else "Registered"
    print(f"{action} Remote Viewer connection: {uri}")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1]:
        main(sys.argv[1])
    elif len(sys.argv) == 3 and sys.argv[1] == "--remove" and sys.argv[2]:
        main(sys.argv[2], remove=True)
    else:
        raise SystemExit(f"usage: {sys.argv[0]} [--remove] <domain>")
