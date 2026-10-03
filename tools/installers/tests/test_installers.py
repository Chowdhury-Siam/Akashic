"""Exercise installation and extraction against a temporary HOME; no real app data."""
import importlib.util
import os
import platform
import plistlib
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
INSTALLERS = ROOT / "tools/installers"
BACKEND = INSTALLERS / "linux/install.sh"
spec = importlib.util.spec_from_file_location("linux_setup_build", INSTALLERS / "linux/build.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class InstallerTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home with ' quotes $ and %"
        self.home.mkdir()
        self.payload = self.root / "payload"
        self.payload.mkdir()
        self.app = self.payload / "Yutaka.AppImage"
        self.app.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$APPIMAGE_EXTRACT_AND_RUN" "$@"\n')
        (self.payload / "icon.png").write_bytes(b"test-icon")
        self.install = self.home / ".local/opt/yutaka"
        self.env = {**os.environ, "HOME": str(self.home), "XDG_DATA_HOME": str(self.home / "data"),
                    "XDG_CACHE_HOME": str(self.home / "cache")}

    def install_app(self, folder=None, shortcut=False):
        return subprocess.run(["bash", str(BACKEND), str(self.payload), str(folder or self.install),
                               "true" if shortcut else "false"], env=self.env, text=True, capture_output=True)

    def package(self):
        setup = self.payload / "setup"
        setup.write_text("#!/bin/sh\nexit 0\n")
        output = self.root / "Yutaka-Setup.run"
        arch = "arm64" if platform.machine() in ("aarch64", "arm64") else "x64"
        builder.build(self.app, setup, self.payload / "icon.png", BACKEND, output, "1.0.1262", arch)
        return output

    def test_install_and_launcher_handle_special_characters(self):
        result = self.install_app()
        self.assertEqual(result.returncode, 0, result.stderr)
        launcher = self.home / ".local/bin/yutaka"
        launched = subprocess.run([str(launcher), "a b", "$literal"], env=self.env, text=True, capture_output=True)
        self.assertEqual(launched.returncode, 0, launched.stderr)
        self.assertEqual(launched.stdout.splitlines(), ["1", "a b", "$literal"])
        desktop = self.home / "data/applications/yutaka.desktop"
        self.assertIn("Icon=yutaka", desktop.read_text())
        if subprocess.run(["bash", "-c", "command -v desktop-file-validate"], capture_output=True).returncode == 0:
            validated = subprocess.run(["desktop-file-validate", str(desktop)], text=True, capture_output=True)
            self.assertEqual(validated.returncode, 0, validated.stdout + validated.stderr)
        self.assertIn("PROGRESS:100:", result.stdout)
        self.assertFalse((self.home / "cache/yutaka-installer.lock").exists())

    def test_upgrade_preserves_financial_data_and_unrelated_files(self):
        self.assertEqual(self.install_app().returncode, 0)
        database = self.home / "data/yutaka/finance.db"
        database.parent.mkdir(parents=True)
        database.write_bytes(b"user-financial-data")
        unrelated = self.install / "user-backup.json"
        unrelated.write_bytes(b"keep-backup")
        self.app.write_bytes(b"new-appimage")
        result = self.install_app()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.install / "Yutaka.AppImage").read_bytes(), b"new-appimage")
        self.assertEqual(database.read_bytes(), b"user-financial-data")
        self.assertEqual(unrelated.read_bytes(), b"keep-backup")

    def test_incomplete_payload_does_not_overwrite_installed_app(self):
        self.assertEqual(self.install_app().returncode, 0)
        previous = (self.install / "Yutaka.AppImage").read_bytes()
        self.app.write_bytes(b"")
        self.assertNotEqual(self.install_app().returncode, 0)
        self.assertEqual((self.install / "Yutaka.AppImage").read_bytes(), previous)

    def test_lock_rejects_concurrent_installation(self):
        lock = self.home / "cache/yutaka-installer.lock"
        lock.mkdir(parents=True)
        result = self.install_app()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another Yutaka installer", result.stderr)
        self.assertTrue(lock.exists())
        self.assertFalse(self.install.exists())

    def test_relative_and_root_folders_are_rejected(self):
        for folder in (Path("relative"), Path("/"), self.home):
            result = self.install_app(folder)
            self.assertNotEqual(result.returncode, 0, str(folder))

    def test_custom_location_and_optional_desktop_shortcut(self):
        # Control xdg-user-dir independently of the runner's desktop configuration.
        commands = self.root / "commands"
        commands.mkdir()
        helper = commands / "xdg-user-dir"
        helper.write_text('#!/bin/sh\nprintf "%s/Desktop\\n" "$HOME"\n')
        helper.chmod(0o755)
        self.env["PATH"] = str(commands) + os.pathsep + self.env["PATH"]
        custom = self.home / "My Apps/Yutaka"
        result = self.install_app(custom, shortcut=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((custom / "Yutaka.AppImage").is_file())
        self.assertTrue(os.access(self.home / "Desktop/Yutaka.desktop", os.X_OK))
        self.assertEqual((self.home / "data/yutaka-installer-location").read_text().strip(), str(custom))

    def test_packaged_terminal_install_round_trip(self):
        package = self.package()
        help_result = subprocess.run(["bash", str(package), "--help"], env=self.env, text=True, capture_output=True)
        self.assertEqual(help_result.returncode, 0, help_result.stderr)
        result = subprocess.run(["bash", str(package), "--install"], env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.install / "Yutaka.AppImage").read_bytes(), self.app.read_bytes())

    def test_corrupt_package_fails_before_installing(self):
        package = self.package()
        data = bytearray(package.read_bytes())
        data[-1] ^= 1
        package.write_bytes(data)
        result = subprocess.run(["bash", str(package), "--install"], env=self.env, text=True, capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("corrupted", result.stderr)
        self.assertFalse(self.install.exists())

    def test_macos_layout_uses_built_app_icon_and_signed_bundle(self):
        app = self.root / "Generated.app"
        resources = app / "Contents/Resources"
        resources.mkdir(parents=True)
        with (app / "Contents/Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleIconFile": "RealAppIcon"}, stream)
        (resources / "RealAppIcon.icns").write_bytes(b"icon")
        setup = self.root / "Yutaka Setup.app"
        (setup / "Contents/MacOS").mkdir(parents=True)
        (setup / "Contents/MacOS/YutakaSetup").write_bytes(b"universal-setup")
        with patch.dict(os.environ, {"YUTAKA_MACOS_APP": str(app), "YUTAKA_MACOS_SETUP": str(setup), "YUTAKA_INSTALLER_ASSETS": str(INSTALLERS / "assets")}):
            # dmgbuild executes settings as Python source; it need not set __file__.
            settings = {}
            exec(compile((INSTALLERS / "macos/settings.py").read_text(), "settings.py", "exec"), settings)
        self.assertEqual(settings["files"], [(str(setup.resolve()), "Yutaka Setup.app")])
        self.assertEqual(settings["icon"], str(resources / "RealAppIcon.icns"))
        self.assertEqual(settings["symlinks"], {})
        self.assertTrue(Path(settings["background"]).is_file())
        width, height = settings["window_rect"][1]
        for x, y in settings["icon_locations"].values():
            self.assertTrue(0 < x < width and 0 < y < height)


if __name__ == "__main__":
    unittest.main()
