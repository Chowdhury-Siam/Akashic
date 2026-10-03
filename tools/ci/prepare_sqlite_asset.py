#!/usr/bin/env python3
"""Prefetch the resolved sqlite3 package's verified Linux binary for build hooks.

Run after flutter pub get. Use the package's own release tag and SHA-256 values,
and populate its documented shared hook cache without changing dependencies.
"""

import argparse
import hashlib
from http.client import HTTPException
import json
from pathlib import Path
import re
import sys
import tempfile
import time
from urllib.parse import unquote, urljoin, urlparse
from urllib.request import Request, urlopen


def sqlite_package(root):
    config = root / '.dart_tool/package_config.json'
    packages = json.loads(config.read_text(encoding='utf-8'))['packages']
    package = next((p for p in packages if p['name'] == 'sqlite3'), None)
    if package is None:
        raise ValueError('sqlite3 is not resolved; run flutter pub get first')
    uri = urlparse(urljoin(config.as_uri(), package['rootUri']))
    if uri.scheme != 'file' or uri.netloc not in ('', 'localhost'):
        raise ValueError('Expected a local sqlite3 package root')
    return Path(unquote(uri.path))


def asset_details(root, arch):
    source = (sqlite_package(root) / 'lib/src/hook/asset_hashes.dart').read_text(encoding='utf-8')
    tag = re.search(r"const String\? releaseTag\s*=\s*'([^']+)';", source)
    if tag is None or not re.fullmatch(r'sqlite3-[0-9]+\.[0-9]+\.[0-9]+(?:[-+][A-Za-z0-9.-]+)?', tag[1]):
        raise ValueError('Cannot determine sqlite3 release tag from the resolved package')
    filename = f'libsqlite3.{arch}.linux.so'
    checksum = re.search(r"'" + re.escape(filename) + r"'\s*:\s*'([0-9a-f]{64})'", source)
    if checksum is None:
        raise ValueError(f'Resolved sqlite3 package has no trusted hash for {filename}')
    # sqlite3/doc/hook.md documents this shared cache; the hook rechecks the hash.
    destination = (root / '.dart_tool/hooks_runner/shared/sqlite3/build' /
                   f'download-{checksum[1][:8]}' / 'libsqlite3.so')
    url = f'https://github.com/simolus3/sqlite3.dart/releases/download/{tag[1]}/{filename}'
    return url, checksum[1], destination


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def fetch_verified(url, checksum, destination, attempts=4):
    if destination.is_file():
        if sha256(destination) == checksum:
            print(f'Using verified SQLite cache: {destination}', flush=True)
            return
        destination.unlink()
        print('Discarded corrupt SQLite cache entry', flush=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, attempts + 1):
        temporary = None
        try:
            print(f'Downloading SQLite ({attempt}/{attempts}): {url}', flush=True)
            request = Request(url, headers={'User-Agent': 'Yutaka CI SQLite asset preparation'})
            with urlopen(request, timeout=60) as response, tempfile.NamedTemporaryFile(
                dir=destination.parent, prefix='sqlite-', suffix='.tmp', delete=False
            ) as stream:
                temporary = Path(stream.name)
                for chunk in iter(lambda: response.read(1024 * 1024), b''):
                    stream.write(chunk)
            actual = sha256(temporary)
            if actual != checksum:
                raise ValueError(f'SQLite SHA-256 mismatch: expected {checksum}, received {actual}')
            temporary.replace(destination)
            print(f'Prepared verified SQLite binary: {destination}', flush=True)
            return
        except (OSError, HTTPException, ValueError) as error:
            print(f'SQLite download attempt {attempt} failed: {error}', file=sys.stderr, flush=True)
            if attempt == attempts:
                raise
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
        time.sleep(2 ** (attempt - 1))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--arch', choices=['x64', 'arm64'], required=True)
    args = parser.parse_args()
    fetch_verified(*asset_details(args.root.resolve(), args.arch))


if __name__ == '__main__':
    main()
