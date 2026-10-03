"""Exercise the real signed-bundle install backend on macOS with temporary folders."""
import hashlib
import os
import plistlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

BACKEND = Path(__file__).resolve().parents[1] / "macos/install.sh"


@unittest.skipUnless(sys.platform == "darwin", "Requires macOS ditto and codesign")
class MacInstallerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.fixture.cleanup)
        source = Path(cls.fixture.name) / "main.c"
        source.write_text("int main(void) { return 0; }\n")
        cls.binary = Path(cls.fixture.name) / "Yutaka"
        subprocess.run(["xcrun", "clang", str(source), "-o", str(cls.binary)], check=True)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home with ' quotes $ and %"
        self.home.mkdir()
        self.destination = self.home / "Applications"
        self.payload = self.root / "resources"
        self.payload.mkdir()
        app = self.root / "Yutaka.app"
        (app / "Contents/MacOS").mkdir(parents=True)
        shutil.copy2(self.binary, app / "Contents/MacOS/Yutaka")
        with (app / "Contents/Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleIdentifier": "com.yutaka.siam", "CFBundleExecutable": "Yutaka",
                          "CFBundlePackageType": "APPL", "CFBundleName": "Yutaka",
                          "CFBundleVersion": "1", "CFBundleShortVersionString": "1.0.0"}, stream)
        subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-", str(app)], check=True, capture_output=True)
        subprocess.run(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent",
                        str(app), str(self.payload / "payload.zip")], check=True)
        digest = hashlib.sha256((self.payload / "payload.zip").read_bytes()).hexdigest()
        (self.payload / "payload.sha256").write_text(digest + "\n")
        self.env = {**os.environ, "HOME": str(self.home)}

    def install(self):
        return subprocess.run(["bash", str(BACKEND), str(self.payload), str(self.destination)],
                              env=self.env, text=True, capture_output=True)

    def test_signed_bundle_install_and_upgrade_preserve_user_data(self):
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        database = self.home / "Library/Application Support/com.yutaka.siam/finance.db"
        database.parent.mkdir(parents=True)
        database.write_bytes(b"financial-data")
        unrelated = self.destination / "backup.yutakabackup"
        unrelated.write_bytes(b"backup")
        result = self.install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(database.read_bytes(), b"financial-data")
        self.assertEqual(unrelated.read_bytes(), b"backup")
        self.assertIn("PROGRESS:100:", result.stdout)
        self.assertFalse(list(self.destination.glob(".yutaka-*")))
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict",
                        str(self.destination / "Yutaka.app")], check=True, capture_output=True)

    def test_corruption_is_rejected_before_installing(self):
        with (self.payload / "payload.zip").open("ab") as stream:
            stream.write(b"corruption")
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("corrupted", result.stderr)
        self.assertFalse(self.destination.exists())

    def test_an_unrelated_app_is_not_replaced(self):
        target = self.destination / "Yutaka.app/Contents"
        target.mkdir(parents=True)
        with (target / "Info.plist").open("wb") as stream:
            plistlib.dump({"CFBundleIdentifier": "example.other-app"}, stream)
        original = (target / "Info.plist").read_bytes()
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another app", result.stderr)
        self.assertEqual((target / "Info.plist").read_bytes(), original)

    def test_concurrent_install_is_rejected(self):
        (self.destination / ".yutaka-setup.lock").mkdir(parents=True)
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another Yutaka setup", result.stderr)
        self.assertFalse((self.destination / "Yutaka.app").exists())

    def test_failed_final_move_restores_previous_bundle(self):
        self.assertEqual(self.install().returncode, 0)
        target = self.destination / "Yutaka.app/Contents/MacOS/Yutaka"
        original = target.read_bytes()
        commands = self.root / "commands"
        commands.mkdir()
        helper = commands / "mv"
        helper.write_text('''#!/bin/bash
case "$1" in */.yutaka-stage.*/Yutaka.app) echo 'Simulated move failure' >&2; exit 1;; esac
exec /bin/mv "$@"
''')
        helper.chmod(0o755)
        self.env["PATH"] = str(commands) + os.pathsep + self.env["PATH"]
        result = self.install()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(target.read_bytes(), original)
        self.assertFalse(list(self.destination.glob(".yutaka-*")))


if __name__ == "__main__":
    unittest.main()
