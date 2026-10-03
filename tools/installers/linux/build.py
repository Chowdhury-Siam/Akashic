#!/usr/bin/env python3
"""Pack a native setup UI and an AppImage into a checksum-verified .run file."""
import argparse
import hashlib
import shutil
import tarfile
import tempfile
from pathlib import Path

HEADER = r'''#!/usr/bin/env bash
set -euo pipefail
MODE=gui
PREFIX="$HOME/.local/opt/yutaka"
SHORTCUT=false
while (( $# )); do
  case "$1" in
    --help|-h)
      echo 'Yutaka Setup — @VERSION@ (@ARCH@)'
      echo 'Run without arguments for the graphical installer.'
      echo 'Terminal: bash installer.run --install [--prefix /absolute/folder] [--desktop-shortcut]'
      exit 0 ;;
    --install) MODE=terminal; shift ;;
    --prefix) (( $# >= 2 )) || { echo 'Missing folder after --prefix' >&2; exit 2; }; PREFIX="$2"; shift 2 ;;
    --desktop-shortcut) SHORTCUT=true; shift ;;
    *) echo "Unknown option: $1. Use --help." >&2; exit 2 ;;
  esac
done
case "$(uname -m)" in @MACHINE@) ;; *) echo 'This installer is for @ARCH@. Download the matching Linux architecture.' >&2; exit 1 ;; esac
WORK="$(mktemp -d "${TMPDIR:-/tmp}/yutaka-setup.XXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
trap 'exit 130' INT TERM
tail -n +@LINE@ "$0" > "$WORK/payload.tar"
echo '@SHA@  payload.tar' | (cd "$WORK" && sha256sum --check --status) || {
  echo 'The installer is incomplete or corrupted. Download it again.' >&2; exit 1;
}
tar -xf "$WORK/payload.tar" -C "$WORK"
rm "$WORK/payload.tar"
if [[ "$MODE" == terminal ]]; then
  bash "$WORK/install.sh" "$WORK" "$PREFIX" "$SHORTCUT"
else
  if ! "$WORK/setup" "$WORK"; then
    echo 'Graphical setup could not start or complete. GTK 3 is required.' >&2
    echo 'You can also use: bash installer.run --install' >&2
    exit 1
  fi
fi
exit 0
__YUTAKA_PAYLOAD__
'''


def build(appimage, setup, icon, backend, output, version, arch):
    paths = {"Yutaka.AppImage": appimage, "setup": setup, "icon.png": icon, "install.sh": backend}
    for path in paths.values():
        if not path.is_file() or not path.stat().st_size:
            raise ValueError(f"Missing installer input: {path}")
    if arch not in ("x64", "arm64"):
        raise ValueError(f"Unsupported architecture: {arch}")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as directory:
        archive = Path(directory) / "payload.tar"
        # AppImages are already compressed; avoid slow double compression.
        with tarfile.open(archive, "w") as tar:
            for name, path in paths.items():
                info = tar.gettarinfo(str(path), arcname=name)
                info.uid = info.gid = info.mtime = 0
                info.uname = info.gname = ""
                info.mode = 0o755 if name in ("setup", "install.sh", "Yutaka.AppImage") else 0o644
                with path.open("rb") as stream:
                    tar.addfile(info, stream)
        digest = hashlib.sha256()
        with archive.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        checksum = digest.hexdigest()
        header = (HEADER.replace("@VERSION@", version).replace("@ARCH@", arch)
                  .replace("@MACHINE@", "x86_64" if arch == "x64" else "aarch64|arm64")
                  .replace("@SHA@", checksum))
        header = header.replace("@LINE@", str(header.count("\n") + 1))
        with output.open("wb") as stream, archive.open("rb") as payload:
            stream.write(header.encode("utf-8"))
            shutil.copyfileobj(payload, stream)
    output.chmod(0o755)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("appimage", "setup", "icon", "output"):
        parser.add_argument(f"--{name}", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--arch", required=True, choices=("x64", "arm64"))
    args = parser.parse_args()
    build(args.appimage, args.setup, args.icon, Path(__file__).with_name("install.sh"), args.output, args.version, args.arch)


if __name__ == "__main__":
    main()
