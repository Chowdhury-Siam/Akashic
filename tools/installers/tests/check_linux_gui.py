#!/usr/bin/env python3
"""Drive the real GTK setup with keyboard events inside Xvfb and temporary HOME."""
import argparse
import ctypes as C
import ctypes.util
import os
import shutil
import subprocess
import tempfile
import time
from pathlib import Path


class WindowAttributes(C.Structure):
    _fields_ = [
        (name, C.c_int) for name in ("x", "y", "width", "height", "border_width", "depth")
    ] + [
        ("visual", C.c_void_p), ("root", C.c_ulong),
        ("class_", C.c_int), ("bit_gravity", C.c_int), ("win_gravity", C.c_int), ("backing_store", C.c_int),
        ("backing_planes", C.c_ulong), ("backing_pixel", C.c_ulong), ("save_under", C.c_int),
        ("colormap", C.c_ulong), ("map_installed", C.c_int), ("map_state", C.c_int),
        ("all_event_masks", C.c_long), ("your_event_mask", C.c_long), ("do_not_propagate_mask", C.c_long),
        ("override_redirect", C.c_int), ("screen", C.c_void_p),
    ]


def wait_for(condition, message, seconds=8):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if condition():
            return
        time.sleep(.05)
    raise AssertionError(message)


def check(setup, icon, screenshots=None, xtst=None):
    x = C.CDLL(ctypes.util.find_library("X11"))
    xtst_path = xtst or ctypes.util.find_library("Xtst")
    if not xtst_path:
        raise RuntimeError("The GUI check requires libXtst.")
    t = C.CDLL(xtst_path)
    x.XOpenDisplay.argtypes = [C.c_char_p]
    x.XOpenDisplay.restype = C.c_void_p
    display = x.XOpenDisplay(os.environ["DISPLAY"].encode())
    if not display:
        raise RuntimeError("Start this check with xvfb-run.")
    x.XDefaultRootWindow.argtypes = [C.c_void_p]
    x.XDefaultRootWindow.restype = C.c_ulong
    root = x.XDefaultRootWindow(display)
    x.XQueryTree.argtypes = [C.c_void_p, C.c_ulong, C.POINTER(C.c_ulong), C.POINTER(C.c_ulong), C.POINTER(C.POINTER(C.c_ulong)), C.POINTER(C.c_uint)]
    x.XFetchName.argtypes = [C.c_void_p, C.c_ulong, C.POINTER(C.c_char_p)]
    x.XGetWindowAttributes.argtypes = [C.c_void_p, C.c_ulong, C.POINTER(WindowAttributes)]
    x.XFree.argtypes = [C.c_void_p]
    x.XSetInputFocus.argtypes = [C.c_void_p, C.c_ulong, C.c_int, C.c_ulong]
    x.XFlush.argtypes = [C.c_void_p]
    x.XCloseDisplay.argtypes = [C.c_void_p]
    x.XKeysymToKeycode.argtypes = [C.c_void_p, C.c_ulong]
    x.XKeysymToKeycode.restype = C.c_uint
    t.XTestFakeKeyEvent.argtypes = [C.c_void_p, C.c_uint, C.c_int, C.c_ulong]

    def key(symbol):
        code = x.XKeysymToKeycode(display, symbol)
        t.XTestFakeKeyEvent(display, code, 1, 0)
        t.XTestFakeKeyEvent(display, code, 0, 0)
        x.XFlush(display)

    def focus():
        root_return, parent = C.c_ulong(), C.c_ulong()
        children, count = C.POINTER(C.c_ulong)(), C.c_uint()
        x.XQueryTree(display, root, C.byref(root_return), C.byref(parent), C.byref(children), C.byref(count))
        found = None
        for index in range(count.value):
            name = C.c_char_p()
            if x.XFetchName(display, children[index], C.byref(name)) and name.value:
                if name.value in (b"Install Yutaka", b"Yutaka Setup"):
                    attributes = WindowAttributes()
                    x.XGetWindowAttributes(display, children[index], C.byref(attributes))
                    if attributes.map_state == 2 and attributes.width >= 800 and attributes.height >= 500:
                        found = children[index]
                x.XFree(name)
        x.XFree(children)
        if found is None:
            return False
        x.XSetInputFocus(display, found, 2, 0)
        x.XFlush(display)
        return True

    def screenshot(name):
        if screenshots:
            screenshots.mkdir(parents=True, exist_ok=True)
            subprocess.run(["import", "-display", os.environ["DISPLAY"], "-window", "root", str(screenshots / name)], check=True)

    try:
        with tempfile.TemporaryDirectory(prefix="yutaka-gui-") as directory:
            root_folder = Path(directory)
            payload, home = root_folder / "payload", root_folder / "home"
            payload.mkdir(); home.mkdir()
            shutil.copy2(icon, payload / "icon.png")
            backend = Path(__file__).resolve().parents[1] / "linux/install.sh"
            shutil.copy2(backend, payload / "install-real.sh")
            (payload / "Yutaka.AppImage").write_text("#!/bin/bash\nexit 0\n")
            (payload / "fail-first").touch()
            (payload / "install.sh").write_text('''#!/bin/bash
if [ -f "$1/fail-first" ]; then
  touch "$1/started-first"
  echo 'PROGRESS:10:Preparing installation'
  sleep 0.5
  echo 'ERROR: Test failure. Try again.' >&2
  touch "$1/failed-first"
  exit 1
fi
exec bash "$1/install-real.sh" "$@"
''')
            environment = {**os.environ, "HOME": str(home), "XDG_DATA_HOME": str(home / "data"), "XDG_CACHE_HOME": str(home / "cache")}
            database = home / "data/yutaka/finance.db"
            database.parent.mkdir(parents=True)
            database.write_bytes(b"keep-financial-data")
            ui = subprocess.Popen([str(setup), str(payload)], env=environment)
            try:
                wait_for(focus, "Setup window did not appear")
                time.sleep(.15)
                screenshot("custom-setup-preview.png")
                key(0xff0d)
                wait_for(lambda: (payload / "started-first").exists(), "Install button did not start the backend")
                key(0xff1b)
                time.sleep(.1)
                assert ui.poll() is None, "Escape closed a busy installation"
                screenshot("custom-setup-installing.png")
                wait_for(lambda: (payload / "failed-first").exists(), "Failure fixture did not finish")
                time.sleep(.15)
                screenshot("custom-setup-error.png")
                (payload / "fail-first").unlink()

                def retry():
                    if (home / ".local/opt/yutaka/Yutaka.AppImage").is_file():
                        return True
                    key(0xff0d)
                    return False

                wait_for(retry, "Retry did not install the app")
                assert database.read_bytes() == b"keep-financial-data"
                time.sleep(.15)
                screenshot("custom-setup-success.png")

                def close():
                    if ui.poll() is not None:
                        return True
                    key(0xff1b)
                    return False

                wait_for(close, "Completed setup did not close")
                assert ui.returncode == 0
            finally:
                if ui.poll() is None:
                    ui.terminate(); ui.wait(timeout=5)
    finally:
        x.XCloseDisplay(display)
    print("GTK install, busy-close protection, failure/retry, completion and data preservation passed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--setup", type=Path, required=True)
    parser.add_argument("--icon", type=Path, required=True)
    parser.add_argument("--screenshots", type=Path)
    parser.add_argument("--xtst-library")
    args = parser.parse_args()
    check(args.setup.resolve(), args.icon.resolve(), args.screenshots, args.xtst_library)
