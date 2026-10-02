import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest


spec = importlib.util.spec_from_file_location('native_inputs', Path(__file__).with_name('native_input_timestamps.py'))
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


class NativeInputTimestampTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root / '.ci-cache/native-inputs.json'

    def source(self, name, content='original'):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def test_unchanged_regenerated_input_keeps_cached_timestamp(self):
        path = self.source('windows/runner/main.cpp')
        old = path.stat().st_mtime_ns
        native.capture(self.root, 'windows', self.manifest)
        os.utime(path, ns=(old, old + 10_000_000_000))
        self.assertEqual(native.restore(self.root, 'windows', self.manifest), 1)
        self.assertEqual(path.stat().st_mtime_ns, old)

    def test_changed_and_new_sources_are_not_marked_up_to_date(self):
        changed = self.source('macos/Runner/AppDelegate.swift')
        native.capture(self.root, 'macos', self.manifest)
        changed.write_text('updated code')
        added = self.source('macos/Runner/new.mm')
        timestamps = [p.stat().st_mtime_ns for p in (changed, added)]
        self.assertEqual(native.restore(self.root, 'macos', self.manifest), 0)
        self.assertEqual([p.stat().st_mtime_ns for p in (changed, added)], timestamps)

    def test_native_plugins_are_included_but_other_platforms_are_not(self):
        self.source('.pub-cache/hosted/pub.dev/plugin-1.0/windows/plugin.cpp')
        self.source('.pub-cache/hosted/pub.dev/plugin-1.0/darwin/plugin.m')
        self.source('.pub-cache/hosted/pub.dev/plugin-1.0/macos/plugin.swift')
        self.source('.pub-cache/hosted/pub.dev/plugin-1.0/lib/plugin.dart')
        self.assertEqual(native.capture(self.root, 'windows', self.manifest), 1)
        self.assertEqual(native.capture(self.root, 'macos', self.manifest), 2)

    def test_wrong_platform_and_corrupt_manifests_fall_back_to_cold_build(self):
        self.source('windows/runner/main.cpp')
        native.capture(self.root, 'windows', self.manifest)
        self.assertEqual(native.restore(self.root, 'macos', self.manifest), 0)
        self.manifest.write_text('broken json')
        self.assertEqual(native.restore(self.root, 'windows', self.manifest), 0)

    def test_manifest_cannot_modify_unrelated_files(self):
        outside = self.source('private.cpp')
        before = outside.stat().st_mtime_ns
        self.manifest.parent.mkdir(parents=True)
        self.manifest.write_text(json.dumps({
            'platform': 'windows',
            'files': {'../private.cpp': {'sha256': native.fingerprint(outside), 'mtime_ns': 1}},
        }))
        self.assertEqual(native.restore(self.root, 'windows', self.manifest), 0)
        self.assertEqual(outside.stat().st_mtime_ns, before)


if __name__ == '__main__':
    unittest.main()
