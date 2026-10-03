#!/usr/bin/env bash
# Per-user installation backend shared by the graphical and terminal installers.
set -euo pipefail
PAYLOAD_DIR="${1:?Missing payload directory}"
INSTALL_DIR="${2:?Missing installation directory}"
DESKTOP_SHORTCUT="${3:-false}"

fail() { echo "ERROR: $*" >&2; exit 1; }
progress() { echo "PROGRESS:$1:$2"; }
[[ "$INSTALL_DIR" = /* && "$INSTALL_DIR" != / && "$INSTALL_DIR" != "$HOME" ]] || fail "Choose an absolute app folder, such as $HOME/.local/opt/yutaka."
[[ "$INSTALL_DIR" != *$'\n'* && "$INSTALL_DIR" != *$'\r'* ]] || fail "The folder name cannot contain line breaks."
[[ -f "$PAYLOAD_DIR/Yutaka.AppImage" && -s "$PAYLOAD_DIR/Yutaka.AppImage" && -s "$PAYLOAD_DIR/icon.png" ]] || fail "The installer payload is incomplete. Download it again."
[[ "$DESKTOP_SHORTCUT" == true || "$DESKTOP_SHORTCUT" == false ]] || fail "Invalid shortcut option."

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
[[ "$DATA_DIR" = /* && "$CACHE_DIR" = /* ]] || fail "XDG data and cache folders must be absolute paths."
mkdir -p "$CACHE_DIR"
LOCK="$CACHE_DIR/yutaka-installer.lock"
mkdir "$LOCK" 2>/dev/null || fail "Another Yutaka installer is running. Close it and try again."
STAGED=()
cleanup() {
  for staged in "${STAGED[@]}"; do rm -f -- "$staged"; done
  rmdir "$LOCK" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 130' INT TERM

progress 10 "Preparing your app folder"
mkdir -p "$INSTALL_DIR" "$HOME/.local/bin" "$DATA_DIR/applications" "$DATA_DIR/icons/hicolor/512x512/apps"
# Resolve symlinks before writing the launcher and desktop entry.
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd -P)"
APP="$INSTALL_DIR/Yutaka.AppImage"
LAUNCHER="$HOME/.local/bin/yutaka"
ICON="$DATA_DIR/icons/hicolor/512x512/apps/yutaka.png"
DESKTOP="$DATA_DIR/applications/yutaka.desktop"
LOCATION="$DATA_DIR/yutaka-installer-location"
for target in "$APP" "$LAUNCHER" "$ICON" "$DESKTOP" "$LOCATION"; do
  [[ ! -d "$target" ]] || fail "A directory is blocking installation: $target"
done
new_stage() { REPLY="$(mktemp "${1}.new.XXXXXX")"; STAGED+=("$REPLY"); }
new_stage "$APP"; APP_STAGE="$REPLY"
new_stage "$LAUNCHER"; LAUNCHER_STAGE="$REPLY"
new_stage "$ICON"; ICON_STAGE="$REPLY"
new_stage "$DESKTOP"; DESKTOP_STAGE="$REPLY"
new_stage "$LOCATION"; LOCATION_STAGE="$REPLY"
printf '%s\n' "$INSTALL_DIR" > "$LOCATION_STAGE"
chmod 644 "$LOCATION_STAGE"

progress 25 "Copying Yutaka"
cp -- "$PAYLOAD_DIR/Yutaka.AppImage" "$APP_STAGE"
chmod 755 "$APP_STAGE"
cp -- "$PAYLOAD_DIR/icon.png" "$ICON_STAGE"
chmod 644 "$ICON_STAGE"
progress 70 "Creating your app shortcut"
# %q generates a Bash literal, including paths with quotes or dollar signs.
printf '#!/usr/bin/env bash\n# Run without requiring a FUSE installation.\nexport APPIMAGE_EXTRACT_AND_RUN=1\nexec %q "$@"\n' "$APP" > "$LAUNCHER_STAGE"
chmod 755 "$LAUNCHER_STAGE"
desktop_quote() {
  # Desktop Entry string escaping is applied after Exec argument escaping.
  local value="$1"
  value="${value//\\/\\\\}"; value="${value//\"/\\\"}"
  value="${value//\$/\\\$}"; value="${value//\`/\\\`}"
  value="${value//%/%%}"; value="${value//\\/\\\\}"
  printf '"%s"' "$value"
}
{
  printf '[Desktop Entry]\nType=Application\nName=Yutaka\nComment=Private, local-first personal finance tracker\nExec='
  desktop_quote "$LAUNCHER"
  printf '\nIcon=yutaka\nTerminal=false\nCategories=Office;Finance;\nStartupNotify=true\nStartupWMClass=yutaka\n'
} > "$DESKTOP_STAGE"
chmod 644 "$DESKTOP_STAGE"

SHORTCUT_STAGE=""
if [[ "$DESKTOP_SHORTCUT" == true ]]; then
  SHORTCUT_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || printf '%s/Desktop' "$HOME")"
  # Some desktops disable their Desktop directory by mapping it to HOME.
  [[ "$SHORTCUT_DIR" = /* && "$SHORTCUT_DIR" != "$HOME" ]] || fail "This desktop has no desktop shortcut folder."
  mkdir -p "$SHORTCUT_DIR"
  [[ ! -d "$SHORTCUT_DIR/Yutaka.desktop" ]] || fail "A directory is blocking the desktop shortcut."
  new_stage "$SHORTCUT_DIR/Yutaka.desktop"; SHORTCUT_STAGE="$REPLY"
  cp -- "$DESKTOP_STAGE" "$SHORTCUT_STAGE"
  chmod 755 "$SHORTCUT_STAGE"
fi

progress 90 "Finishing installation"
# Never delete the installation directory or any app data. Replace only our files;
# the large AppImage is staged on the same filesystem and renamed atomically.
mv -f -- "$APP_STAGE" "$APP"
mv -f -- "$ICON_STAGE" "$ICON"
mv -f -- "$LAUNCHER_STAGE" "$LAUNCHER"
mv -f -- "$DESKTOP_STAGE" "$DESKTOP"
mv -f -- "$LOCATION_STAGE" "$LOCATION"
if [[ -n "$SHORTCUT_STAGE" ]]; then
  mv -f -- "$SHORTCUT_STAGE" "$SHORTCUT_DIR/Yutaka.desktop"
  gio set "$SHORTCUT_DIR/Yutaka.desktop" metadata::trusted true >/dev/null 2>&1 || true
fi
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$DATA_DIR/applications" >/dev/null 2>&1 || true
fi
progress 100 "Yutaka is ready"
