#!/usr/bin/env python3
"""Build a small universal AppKit setup app around the already signed Yutaka app."""
import argparse
import hashlib
import plistlib
import shutil
import subprocess
import tempfile
from pathlib import Path

SOURCE = Path(__file__).resolve().parent


def build(application, icon, output, version):
    if application.name != "Yutaka.app":
        raise ValueError("The built app must be named Yutaka.app.")
    if output.exists():
        raise FileExistsError(f"Setup output already exists: {output}")
    with (application / "Contents/Info.plist").open("rb") as stream:
        app_info = plistlib.load(stream)
    if app_info.get("CFBundleIdentifier") != "com.yutaka.siam":
        raise ValueError("The payload must be the Yutaka app bundle.")
    contents = output / "Contents"
    resources = contents / "Resources"
    binaries = contents / "MacOS"
    resources.mkdir(parents=True)
    binaries.mkdir()
    icon_name = app_info.get("CFBundleIconFile", "AppIcon.icns")
    if not Path(icon_name).suffix:
        icon_name += ".icns"
    shutil.copy2(application / "Contents/Resources" / icon_name, resources / "AppIcon.icns")
    shutil.copy2(icon, resources / "icon.png")
    shutil.copy2(SOURCE / "install.sh", resources / "install.sh")
    subprocess.run(["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(application), str(resources / "payload.zip")], check=True)
    digest = hashlib.sha256()
    with (resources / "payload.zip").open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    (resources / "payload.sha256").write_text(digest.hexdigest() + "\n")
    info = {"CFBundleName": "Yutaka Setup", "CFBundleDisplayName": "Yutaka Setup",
            "CFBundleIdentifier": "com.yutaka.siam.setup", "CFBundleExecutable": "YutakaSetup",
            "CFBundlePackageType": "APPL", "CFBundleIconFile": "AppIcon.icns",
            "CFBundleShortVersionString": version, "CFBundleVersion": app_info.get("CFBundleVersion", "1"),
            "LSMinimumSystemVersion": "10.15", "NSHighResolutionCapable": True}
    with (contents / "Info.plist").open("wb") as stream:
        plistlib.dump(info, stream)
    sdk = subprocess.check_output(["xcrun", "--sdk", "macosx", "--show-sdk-path"], text=True).strip()
    with tempfile.TemporaryDirectory() as directory:
        slices = []
        for arch, minimum in [("arm64", "11.0"), ("x86_64", "10.15")]:
            binary = Path(directory) / arch
            subprocess.run(["xcrun", "swiftc", "-swift-version", "5", "-O", "-sdk", sdk,
                            "-target", f"{arch}-apple-macos{minimum}", "-module-name", "YutakaSetup",
                            str(SOURCE / "main.swift"), "-o", str(binary)], check=True)
            slices.append(str(binary))
        subprocess.run(["lipo", "-create", *slices, "-output", str(binaries / "YutakaSetup")], check=True)
    print(output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("app", "icon", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()
    build(args.app.resolve(), args.icon.resolve(), args.output.resolve(), args.version)
