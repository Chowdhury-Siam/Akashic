import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError


spec = importlib.util.spec_from_file_location('sqlite_asset', Path(__file__).with_name('prepare_sqlite_asset.py'))
sqlite = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sqlite)


class SqliteAssetTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.root = Path(directory.name)
        self.payload = b'verified sqlite fixture'
        self.checksum = hashlib.sha256(self.payload).hexdigest()
        self.destination = self.root / 'cache/libsqlite3.so'
        self.url = 'https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-3.5.2/fixture.so'

    def package(self, root_uri):
        config = self.root / '.dart_tool/package_config.json'
        config.parent.mkdir()
        config.write_text(json.dumps({'packages': [{'name': 'sqlite3', 'rootUri': root_uri}]}))
        package = self.root / 'pub cache/sqlite3-3.5.2'
        source = package / 'lib/src/hook/asset_hashes.dart'
        source.parent.mkdir(parents=True)
        source.write_text("const String? releaseTag = 'sqlite3-3.5.2';\n" +
                          f"const hashes = {{'libsqlite3.x64.linux.so': '{self.checksum}', " +
                          f"'libsqlite3.arm64.linux.so': '{'a' * 64}'}};\n")
        return package

    def test_resolved_package_paths_and_both_architectures(self):
        self.package('../pub%20cache/sqlite3-3.5.2/')
        url, checksum, path = sqlite.asset_details(self.root, 'x64')
        self.assertTrue(url.endswith('/sqlite3-3.5.2/libsqlite3.x64.linux.so'))
        self.assertEqual(checksum, self.checksum)
        self.assertEqual(path, self.root / '.dart_tool/hooks_runner/shared/sqlite3/build' /
                         f'download-{self.checksum[:8]}/libsqlite3.so')
        arm_url, arm_hash, arm_path = sqlite.asset_details(self.root, 'arm64')
        self.assertTrue(arm_url.endswith('/libsqlite3.arm64.linux.so'))
        self.assertEqual(arm_hash, 'a' * 64)
        self.assertNotEqual(arm_path, path)

    def test_absolute_package_uri(self):
        self.package((self.root / 'pub cache/sqlite3-3.5.2').as_uri() + '/')
        self.assertEqual(sqlite.asset_details(self.root, 'x64')[1], self.checksum)

    def test_verified_cache_needs_no_network(self):
        self.destination.parent.mkdir()
        self.destination.write_bytes(self.payload)
        with patch.object(sqlite, 'urlopen', side_effect=AssertionError('unnecessary download')):
            sqlite.fetch_verified(self.url, self.checksum, self.destination)

    def test_corrupt_cache_is_replaced_with_verified_download(self):
        self.destination.parent.mkdir()
        self.destination.write_bytes(b'corrupt')
        with patch.object(sqlite, 'urlopen', return_value=io.BytesIO(self.payload)):
            sqlite.fetch_verified(self.url, self.checksum, self.destination)
        self.assertEqual(self.destination.read_bytes(), self.payload)
        self.assertEqual(list(self.destination.parent.glob('*.tmp')), [])

    def test_transient_http_error_retries_then_succeeds(self):
        failure = HTTPError(self.url, 503, 'Unavailable', {}, None)
        with patch.object(sqlite, 'urlopen', side_effect=[failure, io.BytesIO(self.payload)]) as fetch, \
                patch.object(sqlite.time, 'sleep'):
            sqlite.fetch_verified(self.url, self.checksum, self.destination)
        self.assertEqual(fetch.call_count, 2)
        self.assertEqual(self.destination.read_bytes(), self.payload)

    def test_bad_hash_never_becomes_a_cached_asset(self):
        with patch.object(sqlite, 'urlopen', side_effect=lambda *a, **kw: io.BytesIO(b'corrupt')), \
                patch.object(sqlite.time, 'sleep'):
            with self.assertRaisesRegex(ValueError, 'SHA-256 mismatch'):
                sqlite.fetch_verified(self.url, self.checksum, self.destination, attempts=2)
        self.assertFalse(self.destination.exists())
        self.assertEqual(list(self.destination.parent.glob('*.tmp')), [])

    def test_interrupted_stream_does_not_leave_a_partial_asset(self):
        class Interrupted(io.BytesIO):
            def read(self, size):
                if self.tell():
                    raise OSError('connection interrupted')
                return super().read(size)

        with patch.object(sqlite, 'urlopen', return_value=Interrupted(b'partial')):
            with self.assertRaisesRegex(OSError, 'interrupted'):
                sqlite.fetch_verified(self.url, self.checksum, self.destination, attempts=1)
        self.assertFalse(self.destination.exists())
        self.assertEqual(list(self.destination.parent.glob('*.tmp')), [])

    def test_missing_trusted_arch_hash_fails_before_download(self):
        self.package('../pub%20cache/sqlite3-3.5.2/')
        with self.assertRaisesRegex(ValueError, 'no trusted hash'):
            sqlite.asset_details(self.root, 'riscv64')


if __name__ == '__main__':
    unittest.main()
