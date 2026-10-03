r"""Exercise the real Inno UI with an isolated fixture, install ID and shortcuts.

Run on Windows: python check_windows_gui.py --compiler C:\path\to\ISCC.exe
The fixture never runs Flutter or reads the user's Yutaka data.
"""
import argparse
import ctypes as C
from ctypes import wintypes as W
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid


class MouseInput(C.Structure):
    # Fixed-width Win32 fields also keep the layout testable on LP64 hosts.
    _fields_ = [("dx", C.c_int32), ("dy", C.c_int32), ("mouseData", C.c_uint32),
                ("dwFlags", C.c_uint32), ("time", C.c_uint32), ("dwExtraInfo", C.c_size_t)]


class KeyboardInput(C.Structure):
    _fields_ = [("wVk", C.c_uint16), ("wScan", C.c_uint16), ("dwFlags", C.c_uint32),
                ("time", C.c_uint32), ("dwExtraInfo", C.c_size_t)]


class HardwareInput(C.Structure):
    _fields_ = [("uMsg", C.c_uint32), ("wParamL", C.c_uint16), ("wParamH", C.c_uint16)]


class InputPayload(C.Union):
    _fields_ = [("mouse", MouseInput), ("keyboard", KeyboardInput), ("hardware", HardwareInput)]


class Input(C.Structure):
    _fields_ = [("type", C.c_uint32), ("payload", InputPayload)]


def wait_for(check, message, timeout=25):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = check()
        if result:
            return result
        time.sleep(0.05)
    raise AssertionError(message)


class Windows:
    def __init__(self):
        self.api = C.WinDLL("user32", use_last_error=True)
        self.callback = C.WINFUNCTYPE(W.BOOL, W.HWND, W.LPARAM)
        self.api.EnumWindows.argtypes = [self.callback, W.LPARAM]
        self.api.EnumChildWindows.argtypes = [W.HWND, self.callback, W.LPARAM]
        self.api.GetWindowTextW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
        self.api.GetClassNameW.argtypes = [W.HWND, W.LPWSTR, C.c_int]
        self.api.IsWindowVisible.argtypes = [W.HWND]
        self.api.IsWindowEnabled.argtypes = [W.HWND]
        self.api.GetWindowThreadProcessId.argtypes = [W.HWND, C.POINTER(W.DWORD)]
        self.api.SendMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
        self.api.SendMessageW.restype = C.c_ssize_t
        self.api.SendMessageTimeoutW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM,
                                                W.UINT, W.UINT, C.POINTER(C.c_size_t)]
        self.api.SendMessageTimeoutW.restype = C.c_ssize_t
        self.api.PostMessageW.argtypes = [W.HWND, W.UINT, W.WPARAM, W.LPARAM]
        self.api.GetClientRect.argtypes = [W.HWND, C.POINTER(W.RECT)]
        self.api.ClientToScreen.argtypes = [W.HWND, C.POINTER(W.POINT)]
        self.api.SetCursorPos.argtypes = [C.c_int, C.c_int]
        self.api.SendInput.argtypes = [W.UINT, C.POINTER(Input), C.c_int]
        self.api.SendInput.restype = W.UINT
        self.api.GetAncestor.argtypes = [W.HWND, W.UINT]
        self.api.GetAncestor.restype = W.HWND
        self.api.SetForegroundWindow.argtypes = [W.HWND]
        self.api.GetForegroundWindow.restype = W.HWND
        self.api.GetWindowLongW.argtypes = [W.HWND, C.c_int]
        self.api.GetWindowLongW.restype = C.c_long

    def caption(self, handle):
        # Cross-process GetWindowText reads the stored window caption without
        # sending to the UI thread. Use it for labels/buttons and diagnostics,
        # including while a synchronous Install handler is still working.
        value = C.create_unicode_buffer(2048)
        self.api.GetWindowTextW(handle, value, len(value))
        return value.value

    def text(self, handle):
        value = C.create_unicode_buffer(2048)
        if self.kind(handle) == "TNewPathEdit":
            # GetWindowText cannot read an edit's contents in another process.
            # Only explicit path checks need this message, while setup is idle.
            result = C.c_size_t()
            sent = self.api.SendMessageTimeoutW(handle, 0x000D, len(value),
                                               C.cast(value, C.c_void_p).value,
                                               0x0002, 1000, C.byref(result))  # WM_GETTEXT
            assert sent, "Install location did not respond"
            return value.value
        return self.caption(handle)

    def kind(self, handle):
        value = C.create_unicode_buffer(256)
        self.api.GetClassNameW(handle, value, len(value))
        return value.value

    def pid(self, handle):
        result = W.DWORD()
        self.api.GetWindowThreadProcessId(handle, C.byref(result))
        return result.value

    def windows(self, parent=None):
        found = []

        @self.callback
        def collect(handle, _):
            if self.api.IsWindowVisible(handle):
                found.append(handle)
            return True

        if parent is None:
            self.api.EnumWindows(collect, 0)
        else:
            self.api.EnumChildWindows(parent, collect, 0)
        return found

    def control(self, parent, caption):
        # Do not query edit contents just to find a button or status label: a
        # one-second WM_GETTEXT timeout would abort the overall completion wait.
        return next((h for h in self.windows(parent) if self.caption(h) == caption), None)

    def click(self, handle):
        self._click_mouse(handle, checkbox=False)

    def click_checkbox(self, handle, selected):
        root = self.api.GetAncestor(handle, 2)
        before = "TEST DESKTOP SHORTCUT: " + str(int(not selected))
        after = "TEST DESKTOP SHORTCUT: " + str(int(selected))
        assert self.control(root, before), "Unexpected initial desktop shortcut checkbox state"
        self._click_mouse(handle, checkbox=True)
        wait_for(lambda: self.control(root, after),
                 "Desktop shortcut checkbox did not change to " + str(selected), 5)

    def _click_mouse(self, handle, checkbox):
        assert handle and self.api.IsWindowEnabled(handle), "Control is missing or disabled"
        root = self.api.GetAncestor(handle, 2)  # GA_ROOT
        assert root and self.api.IsWindowEnabled(root), "Setup window is disabled by a modal dialog"
        self.api.SetForegroundWindow(root)
        wait_for(lambda: self.api.GetForegroundWindow() == root,
                 "Could not activate the window before clicking " + self.caption(handle), 5)
        bounds = W.RECT()
        assert self.api.GetClientRect(handle, C.byref(bounds)), C.get_last_error()
        width, height = bounds.right - bounds.left, bounds.bottom - bounds.top
        assert width > 1 and height > 1, "Control has no clickable area"
        # Styled controls need their real hover/press path after modal Browse.
        # Click the checkbox glyph or the button center with the cursor inside.
        x, y = min(width // 2, height // 2) if checkbox else width // 2, height // 2
        screen = W.POINT(x, y)
        assert self.api.ClientToScreen(handle, C.byref(screen)), C.get_last_error()
        assert self.api.SetCursorPos(screen.x, screen.y), C.get_last_error()
        position = (y << 16) | x

        if checkbox:
            # Send actual system input so the native control/style hook sees
            # mouse button state, capture and normal notifications. Successful
            # delivery of hand-made WM_LBUTTON messages is not proof of a toggle.
            events = (Input * 2)()
            events[0].payload.mouse.dwFlags = 0x0002  # MOUSEEVENTF_LEFTDOWN
            events[1].payload.mouse.dwFlags = 0x0004  # MOUSEEVENTF_LEFTUP
            assert self.api.SendInput(2, events, C.sizeof(Input)) == 2, "Checkbox mouse input was not injected"
            return

        def send_mouse(message, buttons):
            result = C.c_size_t()
            sent = self.api.SendMessageTimeoutW(handle, message, buttons, position,
                                               0x0002, 2000, C.byref(result))
            assert sent, "Control did not process mouse message " + hex(message)

        send_mouse(0x0200, 0)  # WM_MOUSEMOVE
        send_mouse(0x0201, 1)  # WM_LBUTTONDOWN, MK_LBUTTON
        # Release invokes OnClick. Browse and Install can run modal or
        # synchronous work, so do not wait for their handler to return.
        assert self.api.PostMessageW(handle, 0x0202, 0, position), C.get_last_error()

    def set_text(self, handle, text):
        value = C.create_unicode_buffer(text)
        self.api.SendMessageW(handle, 0x000C, 0, C.cast(value, C.c_void_p).value)  # WM_SETTEXT

    def dump(self, parent):
        return "\n".join(f"{self.kind(h)} enabled={bool(self.api.IsWindowEnabled(h))} "
                         f"style=0x{self.api.GetWindowLongW(h, -16) & 0xffffffff:08x} {self.caption(h)!r}"
                         for h in self.windows(parent))

    def dump_related(self, parent):
        process_id = self.pid(parent)
        dialogs = [parent] + [h for h in self.windows()
                              if h != parent and self.pid(h) == process_id]
        return "\n\n".join(f"{self.kind(h)} {self.caption(h)!r}\n{self.dump(h)}"
                           for h in dialogs)


def build_fixture(root, supplied):
    payload = root / "payload"
    payload.mkdir()
    app = payload / "Yutaka.exe"
    if supplied:
        shutil.copy2(supplied, app)
        return payload
    compiler = Path(os.environ["WINDIR"]) / "Microsoft.NET/Framework64/v4.0.30319/csc.exe"
    if not compiler.is_file():
        compiler = Path(os.environ["WINDIR"]) / "Microsoft.NET/Framework/v4.0.30319/csc.exe"
    source = root / "fixture.cs"
    source.write_text('''using System;
using System.IO;
public static class Fixture {
    public static void Main() {
        File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                      "launched.txt"), "launched");
    }
}
''')
    subprocess.run([str(compiler), "/nologo", "/target:winexe", "/out:" + str(app), str(source)], check=True)
    return payload


def run(compiler, fixture, logs):
    repo = Path(__file__).resolve().parents[3]
    api = Windows()
    name = "Yutaka setup test " + uuid.uuid4().hex
    shell = C.WinDLL("shell32", use_last_error=True)
    shell.SHGetFolderPathW.argtypes = [W.HWND, C.c_int, W.HANDLE, W.DWORD, W.LPWSTR]
    desktop = C.create_unicode_buffer(260)
    assert shell.SHGetFolderPathW(None, 0x10, None, 0, desktop) == 0
    shortcut = Path(desktop.value) / (name + ".lnk")
    with tempfile.TemporaryDirectory(prefix="yutaka-windows-ui-") as directory:
        root = Path(directory)
        output = root / "output"
        output.mkdir()
        payload = build_fixture(root, fixture)
        built = subprocess.run([
            str(compiler), "/Qp", "/DSourceDir=" + str(payload), "/DOutputDir=" + str(output),
            "/DIconFile=" + str(repo / "assets/icons/app_icon.ico"),
            "/DBrandDir=" + str(repo / "tools/installers/assets"), "/DMyAppVersion=0.0.1",
            "/DMyAppName=" + name, "/DInstallerTestAppId=" + name,
            str(repo / "tools/installers/windows/yutaka.iss"),
        ], text=True, capture_output=True)
        assert built.returncode == 0, built.stdout + built.stderr
        installer = output / "YutakaSetup.exe"
        destination = root / "My Apps/Yutaka"
        process = None
        window = None

        def open_setup(log_name, desktop_selected=None):
            nonlocal process, window
            arguments = [str(installer), "/SP-", "/DIR=" + str(destination),
                         "/LOG=" + str(root / log_name)]
            if desktop_selected is not None:
                arguments.append("/TASKS=" + ("desktopicon" if desktop_selected else "!desktopicon"))
            process = subprocess.Popen(arguments)
            window = wait_for(lambda: next((h for h in api.windows()
                                           if api.kind(h) == "TWizardForm" and name in api.caption(h)), None),
                              "Setup window did not appear")
            install = wait_for(lambda: api.control(window, "Install Yutaka"), "Install control missing")
            wait_for(lambda: api.api.IsWindowEnabled(install),
                     "Install is disabled: startup did not reach the directory page")
            for caption in ("Browse…", "Create a desktop shortcut", "Cancel", "×"):
                handle = api.control(window, caption)
                assert handle and api.api.IsWindowEnabled(handle), f"{caption} is missing or disabled"
            assert api.control(window, "READY TO INSTALL"), api.dump(window)
            if desktop_selected is not None:
                assert api.control(window, "TEST DESKTOP SHORTCUT: " + str(int(desktop_selected))), \
                    "Command-line desktop shortcut choice did not initialize the custom checkbox"
            return install

        def finish_process():
            process.wait(timeout=15)
            assert process.returncode == 0, f"Setup exited with {process.returncode}"

        try:
            def accept_cancel():
                for dialog in api.windows():
                    if api.pid(dialog) == api.pid(window) and dialog != window:
                        yes = next((h for h in api.windows(dialog)
                                    if api.caption(h).replace("&", "") == "Yes"), None)
                        if yes:
                            api.click(yes)
                            return True
                return process.poll() is not None

            # Both custom controls and the window close path must reach Inno's
            # cancellation decision before any files or shortcuts are installed.
            for index, caption in enumerate(("×", "Cancel", None)):
                open_setup(f"cancel-{index}.log")
                if caption is None:
                    api.api.PostMessageW(window, 0x0010, 0, 0)  # WM_CLOSE
                else:
                    api.click(api.control(window, caption))
                wait_for(accept_cancel, f"{caption or 'Window close'} did not offer cancellation")
                process.wait(timeout=15)
                assert not (destination / "Yutaka.exe").exists(), "Cancel installed the app"
                assert not shortcut.exists(), "Cancel created a shortcut"

            # Start selected, then use the visible checkbox to turn it off.
            # Verify the resulting installation, not a styled control's raw
            # BM_GETCHECK value. Initial /TASKS options are deliberately opposite
            # to the expected final result, so a lost click cannot pass the test.
            install = open_setup("install.log", desktop_selected=True)
            edit = next((h for h in api.windows(window) if api.kind(h) == "TNewPathEdit"), None)
            assert edit and api.api.IsWindowEnabled(edit), "Install location is disabled"
            api.set_text(edit, "relative-folder")
            api.click(install)
            wait_for(lambda: api.control(window, "INSTALLATION NOT STARTED"), "Invalid path was accepted")
            assert not (destination / "Yutaka.exe").exists()
            api.set_text(edit, str(destination))
            api.click(api.control(window, "Browse…"))
            dialog = wait_for(lambda: next((h for h in api.windows() if h != window and
                                            api.pid(h) == api.pid(window) and
                                            api.api.IsWindowEnabled(h) and
                                            api.api.GetForegroundWindow() == h), None), "Browse did not open a folder picker")
            api.api.PostMessageW(dialog, 0x0010, 0, 0)  # WM_CLOSE: cancel picker
            wait_for(lambda: not api.api.IsWindowVisible(dialog) and api.api.IsWindowEnabled(window),
                     "Folder picker did not close")
            assert api.text(edit) == str(destination), "Cancelling Browse changed the location"
            checkbox = api.control(window, "Create a desktop shortcut")
            api.click_checkbox(checkbox, selected=False)
            api.click(install)
            wait_for(lambda: api.control(window, "INSTALLATION COMPLETE"), "Install did not complete", 60)
            assert (destination / "Yutaka.exe").is_file(), "Custom install location was not used"
            assert not shortcut.exists(), "Deselected desktop shortcut was created"
            api.click(api.control(window, "Done"))
            finish_process()

            # Reinstall over the same directory; preserve data and test Launch.
            backup = destination / "user-backup.yutakabackup"
            backup.write_bytes(b"preserve-financial-backup")
            database = root / "user-data/finance.db"
            database.parent.mkdir()
            database.write_bytes(b"preserve-financial-data")
            install = open_setup("upgrade.log")
            # Start deselected and turn it on; this must create the real .lnk.
            api.click_checkbox(api.control(window, "Create a desktop shortcut"), selected=True)
            api.click(install)
            wait_for(lambda: api.control(window, "Launch Yutaka"), "Upgrade did not complete", 60)
            assert backup.read_bytes() == b"preserve-financial-backup"
            assert database.read_bytes() == b"preserve-financial-data"
            assert shortcut.is_file(), "Selecting the checkbox did not create a desktop shortcut"
            api.click(api.control(window, "Launch Yutaka"))
            wait_for(lambda: (destination / "launched.txt").is_file(), "Launch did not open the installed fixture")
            finish_process()

            # An upgrade must remember the saved selection, even if the user
            # removed the shortcut between installs. Do not pass /TASKS here.
            shortcut.unlink()
            install = open_setup("remembered-shortcut.log")
            assert api.control(window, "TEST DESKTOP SHORTCUT: 1"), "Upgrade forgot the visible checkbox selection"
            api.click(install)
            wait_for(lambda: api.control(window, "INSTALLATION COMPLETE"), "Remembered-choice upgrade did not complete", 60)
            assert shortcut.is_file(), "Upgrade did not restore the saved shortcut selection"
            assert backup.read_bytes() == b"preserve-financial-backup"
            assert database.read_bytes() == b"preserve-financial-data"
            api.click(api.control(window, "Done"))
            finish_process()
            print("Windows setup UI passed: enabled controls, close/cancel, path validation, Browse, shortcut selection/deselection and saved choice, install, upgrade, preservation and Launch.")
        except BaseException:
            if window:
                diagnostic = api.dump_related(window)
                (root / "ui-failure.log").write_text(diagnostic, encoding="utf-8")
                print(diagnostic, file=sys.stderr)
            raise
        finally:
            if process and process.poll() is None:
                subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                process.wait(timeout=15)
            # Only our unique fixture ID and shortcuts are registered/uninstalled.
            uninstall = destination / "unins000.exe"
            if uninstall.is_file():
                subprocess.run([str(uninstall), "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"], timeout=30, check=True)
            if logs:
                logs.mkdir(parents=True, exist_ok=True)
                for log in root.glob("*.log"):
                    shutil.copy2(log, logs / log.name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--compiler", type=Path, required=True)
    parser.add_argument("--fixture-exe", type=Path, help="Optional native fixture that writes launched.txt next to itself")
    parser.add_argument("--logs", type=Path)
    args = parser.parse_args()
    if sys.platform != "win32":
        parser.error("This check requires Windows (or Windows Python under Wine).")
    run(args.compiler.resolve(), args.fixture_exe, args.logs)
