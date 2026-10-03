#!/usr/bin/env bash
# Called by the native setup app. Replace only Yutaka.app, never user data.
set -euo pipefail
PAYLOAD="${1:?Missing setup resources}"
DESTINATION="${2:?Missing Applications folder}"
fail() { echo "ERROR: $*" >&2; exit 1; }
progress() { echo "PROGRESS:$1:$2"; }
[[ "$DESTINATION" = /* && "$DESTINATION" != / && "$DESTINATION" != "$HOME" ]] || fail "Choose an Applications folder."
[[ "$DESTINATION" != *$'\n'* && "$DESTINATION" != *$'\r'* ]] || fail "The folder name cannot contain line breaks."
[[ -s "$PAYLOAD/payload.zip" && -s "$PAYLOAD/payload.sha256" ]] || fail "The setup package is incomplete. Download it again."
EXPECTED="$(cat "$PAYLOAD/payload.sha256")"
[[ "$EXPECTED" =~ ^[a-f0-9]{64}$ ]] || fail "The setup checksum is invalid."
ACTUAL="$(/usr/bin/shasum -a 256 "$PAYLOAD/payload.zip" | cut -d ' ' -f 1)"
[[ "$ACTUAL" = "$EXPECTED" ]] || fail "The setup package is corrupted. Download it again."
mkdir -p "$DESTINATION"
DESTINATION="$(cd "$DESTINATION" && pwd -P)"
[[ -w "$DESTINATION" ]] || fail "This folder is not writable. Choose your personal Applications folder."
LOCK="$DESTINATION/.yutaka-setup.lock"
mkdir "$LOCK" 2>/dev/null || fail "Another Yutaka setup is running in this folder."
STAGE=""
TARGET="$DESTINATION/Yutaka.app"
cleanup() {
  if [[ -n "$STAGE" && -d "$STAGE/previous.app" && ! -e "$TARGET" ]]; then
    mv "$STAGE/previous.app" "$TARGET" || return
  fi
  if [[ -n "$STAGE" ]]; then rm -rf "$STAGE"; fi
  rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM
STAGE="$(mktemp -d "$DESTINATION/.yutaka-stage.XXXXXX")"
progress 10 "Preparing installation"
/usr/bin/ditto -x -k "$PAYLOAD/payload.zip" "$STAGE"
APP="$STAGE/Yutaka.app"
INFO="$APP/Contents/Info.plist"
[[ -f "$INFO" ]] || fail "Yutaka is missing from this setup package."
IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")"
[[ "$IDENTIFIER" = com.yutaka.siam ]] || fail "This package belongs to another app."
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$INFO")"
[[ -n "$EXECUTABLE" && "$EXECUTABLE" != */* && -x "$APP/Contents/MacOS/$EXECUTABLE" ]] || fail "The app executable is missing."
/usr/bin/codesign --verify --deep --strict "$APP" || fail "The app signature could not be verified. Download it again."
progress 70 "Checking the installed app"
[[ ! -L "$TARGET" ]] || fail "A symbolic link is blocking the Yutaka app location."
if [[ -e "$TARGET" ]]; then
  [[ -d "$TARGET" && -f "$TARGET/Contents/Info.plist" ]] || fail "Another file is using the Yutaka app location."
  OLD_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$TARGET/Contents/Info.plist")"
  [[ "$OLD_IDENTIFIER" = com.yutaka.siam ]] || fail "Another app is using the Yutaka app location."
fi
progress 90 "Finishing installation"
# Stage and verify the entire signed bundle before touching the current app.
# Restore the previous bundle if the final move fails or setup is interrupted.
if [[ -e "$TARGET" ]]; then mv "$TARGET" "$STAGE/previous.app"; fi
mv "$APP" "$TARGET"
progress 100 "Yutaka is ready"
