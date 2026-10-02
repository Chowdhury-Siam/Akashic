#!/usr/bin/env python3
"""Keep unchanged native inputs older than cached compiler outputs in CI.

Checkout, flutter create and pub get give unchanged sources new timestamps.
Restore a previous timestamp only after checking the file's SHA-256 content.
Changed or newly added files retain their timestamps and rebuild normally.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path


SUFFIXES = {
    '.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp', '.hxx', '.m', '.mm',
    '.swift', '.cmake', '.xcconfig', '.pbxproj', '.plist', '.entitlements',
    '.storyboard', '.xib', '.rc', '.ico', '.png', '.json', '.podspec',
}
SKIP_DIRS = {'.git', 'build', 'example', 'examples', 'test', 'tests'}


def inputs(root, platform):
    roots = [root / platform, root / '.pub-cache']
    for source in roots:
        if not source.is_dir():
            continue
        for directory, dirs, files in os.walk(source, followlinks=False):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            parent = Path(directory)
            relative = parent.relative_to(root)
            if source.name == '.pub-cache':
                # Hash just native plugin inputs, including Apple's shared darwin tree.
                if platform not in relative.parts and not (
                    platform == 'macos' and 'darwin' in relative.parts
                ):
                    continue
            for name in sorted(files):
                path = parent / name
                if path.is_symlink() or not path.is_file():
                    continue
                if path.suffix.lower() in SUFFIXES or name in {'CMakeLists.txt', 'Podfile', 'Podfile.lock'}:
                    yield path


def fingerprint(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def restore(root, platform, manifest):
    if not manifest.is_file():
        return 0
    try:
        data = json.loads(manifest.read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return 0  # A missing/corrupt manifest simply means a normal cold build.
    if not isinstance(data, dict) or data.get('platform') != platform:
        return 0
    entries = data.get('files')
    if not isinstance(entries, dict):
        return 0
    count = 0
    # Enumerate actual permitted inputs; never follow arbitrary manifest paths.
    for path in inputs(root, platform):
        entry = entries.get(path.relative_to(root).as_posix())
        if not isinstance(entry, dict):
            continue
        mtime = entry.get('mtime_ns')
        if not isinstance(mtime, int) or isinstance(mtime, bool) or mtime <= 0:
            continue
        if entry.get('sha256') != fingerprint(path):
            continue
        os.utime(path, ns=(path.stat().st_atime_ns, mtime))
        count += 1
    return count


def capture(root, platform, manifest):
    records = {
        path.relative_to(root).as_posix(): {
            'sha256': fingerprint(path),
            'mtime_ns': path.stat().st_mtime_ns,
        }
        for path in inputs(root, platform)
    }
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps({'platform': platform, 'files': records}), encoding='utf-8')
    return len(records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['restore', 'capture'])
    parser.add_argument('--platform', required=True, choices=['windows', 'macos'])
    parser.add_argument('--root', type=Path, default=Path.cwd())
    parser.add_argument('--manifest', type=Path, required=True)
    args = parser.parse_args()
    operation = restore if args.mode == 'restore' else capture
    count = operation(args.root.resolve(), args.platform, args.manifest)
    print(f'{args.mode}: {count} native input timestamps ({args.platform})')


if __name__ == '__main__':
    main()
