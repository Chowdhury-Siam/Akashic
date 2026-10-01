#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <previous-apk> <current-apk>" >&2
  exit 2
fi

PREVIOUS_APK="$1"
CURRENT_APK="$2"
PACKAGE=""
DB_REL="databases/yutaka_flutter.db"
ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PREVIOUS_SOURCE_ROOT="${YUTAKA_PREVIOUS_SOURCE_ROOT:-$(cd "$ROOT_DIR/.." && pwd)/previous}"
WORK_DIR="${RUNNER_TEMP:-/tmp}/yutaka-upgrade-data-loss"
FIXTURE_TOOL="$ROOT_DIR/tools/android/upgrade_data_fixture.py"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

find_android_tool() {
  local tool="$1"
  local candidate

  if command -v "$tool" >/dev/null 2>&1; then
    command -v "$tool"
    return 0
  fi

  for root in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}"; do
    [ -n "$root" ] || continue
    if [ "$tool" = "apkanalyzer" ]; then
      for candidate in "$root"/cmdline-tools/*/bin/apkanalyzer; do
        [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
      done
    else
      for candidate in "$root"/build-tools/*/"$tool"; do
        [ -x "$candidate" ] && { printf '%s\n' "$candidate"; return 0; }
      done
    fi
  done
  return 1
}

detect_apk_package() {
  local apk="$1"
  local analyzer
  local aapt
  local package

  if analyzer="$(find_android_tool apkanalyzer 2>/dev/null)"; then
    package="$($analyzer manifest application-id "$apk" 2>/dev/null | tr -d '\r' | tail -n 1 | xargs || true)"
    if [[ "$package" =~ ^[A-Za-z0-9_]+([.][A-Za-z0-9_]+)+$ ]]; then
      printf '%s\n' "$package"
      return 0
    fi
  fi

  if aapt="$(find_android_tool aapt 2>/dev/null)"; then
    package="$($aapt dump badging "$apk" 2>/dev/null | sed -n "s/^package: name='\([^']*\)'.*/\1/p" | head -n 1)"
    if [[ "$package" =~ ^[A-Za-z0-9_]+([.][A-Za-z0-9_]+)+$ ]]; then
      printf '%s\n' "$package"
      return 0
    fi
  fi

  echo "::error::Could not determine Android application ID from APK: $apk" >&2
  return 1
}

capture_diagnostics() {
  adb logcat -d > "$WORK_DIR/logcat.txt" 2>/dev/null || true
  if [ -n "$PACKAGE" ]; then
    adb shell dumpsys package "$PACKAGE" > "$WORK_DIR/package.txt" 2>/dev/null || true
    adb shell pm list packages -f > "$WORK_DIR/packages.txt" 2>/dev/null || true
    adb shell run-as "$PACKAGE" sh -c 'pwd; ls -la; echo "--- databases ---"; ls -la databases 2>/dev/null || true; echo "--- shared_prefs ---"; ls -la shared_prefs 2>/dev/null || true' > "$WORK_DIR/private-files.txt" 2>&1 || true
  fi
  adb shell getprop > "$WORK_DIR/device-properties.txt" 2>/dev/null || true
}
trap 'capture_diagnostics' ERR

for file in "$PREVIOUS_APK" "$CURRENT_APK" "$FIXTURE_TOOL" "$PREVIOUS_SOURCE_ROOT/lib/main.dart"; do
  test -f "$file" || { echo "::error::Required upgrade-test file is missing: $file"; exit 1; }
done

PREVIOUS_PACKAGE="$(detect_apk_package "$PREVIOUS_APK")"
CURRENT_PACKAGE="$(detect_apk_package "$CURRENT_APK")"
echo "Previous APK applicationId=$PREVIOUS_PACKAGE"
echo "Current APK applicationId=$CURRENT_PACKAGE"
if [ "$PREVIOUS_PACKAGE" != "$CURRENT_PACKAGE" ]; then
  echo "::error::The upgrade probe APKs use different Android application IDs ($PREVIOUS_PACKAGE -> $CURRENT_PACKAGE). Android cannot perform an in-place update across package IDs." >&2
  exit 1
fi
PACKAGE="$PREVIOUS_PACKAGE"

wait_for_package() {
  for _ in $(seq 1 30); do
    if adb shell pm path "$PACKAGE" 2>/dev/null | tr -d '\r' | grep -q '^package:'; then
      return 0
    fi
    sleep 1
  done
  echo "::error::Android PackageManager did not register installed package $PACKAGE within 30 seconds." >&2
  adb shell pm list packages -f >&2 || true
  return 1
}

resolve_launcher_component() {
  local resolved
  local queried

  # PackageManager's resolve-activity command parses an Intent. Restrict that
  # Intent to Yutaka with -p; passing the package as a positional argument is
  # interpreted as Intent data and can incorrectly produce "No activity found".
  resolved="$(
    adb shell cmd package resolve-activity --brief --user 0 \
      -a android.intent.action.MAIN \
      -c android.intent.category.LAUNCHER \
      -p "$PACKAGE" 2>/dev/null | tr -d '\r' || true
  )"

  resolved="$(printf '%s\n' "$resolved" | awk '/^[[:alnum:]_.]+\/[[:alnum:]_.$]+$/ { candidate=$0 } END { print candidate }')"
  if [ -n "$resolved" ]; then
    printf '%s\n' "$resolved"
    return 0
  fi

  # Some platform builds are more reliable when querying all matching launcher
  # activities. Use the first component owned by the installed Yutaka package.
  queried="$(
    adb shell cmd package query-activities --brief --user 0 \
      -a android.intent.action.MAIN \
      -c android.intent.category.LAUNCHER \
      -p "$PACKAGE" 2>/dev/null | tr -d '\r' || true
  )"
  queried="$(printf '%s\n' "$queried" | awk -v pkg="$PACKAGE" '$0 ~ ("^" pkg "/") { print; exit }')"
  if [ -n "$queried" ]; then
    printf '%s\n' "$queried"
    return 0
  fi

  echo "::error::Could not resolve Yutaka's installed MAIN/LAUNCHER activity for package $PACKAGE." >&2
  adb shell dumpsys package "$PACKAGE" >&2 || true
  return 1
}

launch_app() {
  local component
  local launch_output

  component="$(resolve_launcher_component)" || return 1

  adb shell am force-stop "$PACKAGE" >/dev/null 2>&1 || true
  if ! launch_output="$(adb shell am start -W -S -n "$component" 2>&1)"; then
    echo "::error::Failed to launch Yutaka activity $component" >&2
    printf '%s\n' "$launch_output" >&2
    return 1
  fi

  printf '%s\n' "$launch_output"
  if ! printf '%s\n' "$launch_output" | grep -Eq '^Status: ok$'; then
    echo "::error::Android did not report a successful Yutaka activity launch for $component" >&2
    return 1
  fi

  # Give Flutter startup/database initialization time to settle before the
  # private SQLite snapshot is captured.
  sleep 10
}

pull_private_file() {
  local remote="$1"
  local local_path="$2"
  adb exec-out run-as "$PACKAGE" cat "$remote" > "$local_path"
  test -s "$local_path" || { echo "::error::Failed to copy app-private file $remote"; exit 1; }
}

snapshot_db() {
  local prefix="$1"
  adb shell am force-stop "$PACKAGE"
  sleep 1
  pull_private_file "$DB_REL" "$WORK_DIR/$prefix.db"
  for suffix in -wal -shm; do
    if adb shell run-as "$PACKAGE" test -f "${DB_REL}${suffix}" >/dev/null 2>&1; then
      adb exec-out run-as "$PACKAGE" cat "${DB_REL}${suffix}" > "$WORK_DIR/$prefix.db${suffix}"
    fi
  done
}

install_private_db() {
  local db="$1"
  adb push "$db" /data/local/tmp/yutaka-upgrade-fixture.db >/dev/null
  adb shell chmod 0644 /data/local/tmp/yutaka-upgrade-fixture.db
  adb shell "run-as $PACKAGE sh -c 'mkdir -p databases && rm -f ${DB_REL}-wal ${DB_REL}-shm && cp /data/local/tmp/yutaka-upgrade-fixture.db ${DB_REL} && chmod 0600 ${DB_REL}'"
  adb shell rm -f /data/local/tmp/yutaka-upgrade-fixture.db
}

install_offline_preferences() {
  cat > "$WORK_DIR/FlutterSharedPreferences.xml" <<'XML'
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="flutter.onboardingCompleted" value="true" />
    <boolean name="flutter.starterAccountsSkipped" value="false" />
    <boolean name="flutter.cloudSyncEnabled" value="false" />
    <boolean name="flutter.cloudSyncPending" value="true" />
    <boolean name="flutter.automaticUpdatePopupEnabled" value="false" />
    <boolean name="flutter.privacyTelemetryEnabled" value="false" />
    <string name="flutter.currencySymbol">৳</string>
    <string name="flutter.currencyCode">BDT</string>
</map>
XML
  adb push "$WORK_DIR/FlutterSharedPreferences.xml" /data/local/tmp/FlutterSharedPreferences.xml >/dev/null
  adb shell chmod 0644 /data/local/tmp/FlutterSharedPreferences.xml
  adb shell "run-as $PACKAGE sh -c 'mkdir -p shared_prefs && cp /data/local/tmp/FlutterSharedPreferences.xml shared_prefs/FlutterSharedPreferences.xml'"
  adb shell rm -f /data/local/tmp/FlutterSharedPreferences.xml
}

echo "== Clean emulator and install previous signed release probe =="
adb uninstall "$PACKAGE" >/dev/null 2>&1 || true
adb install "$PREVIOUS_APK"
wait_for_package

# A fresh Yutaka install does not guarantee that first-run/onboarding has created
# SQLite yet. Build the baseline database deterministically from the checked-out
# previous release's own CREATE TABLE statements, seed it, then place it in the
# previous app's private databases directory. This keeps the migration fixture
# tied to the real previous source while avoiding UI/lazy-initialization timing.
python3 "$FIXTURE_TOOL" bootstrap \
  --database "$WORK_DIR/previous-baseline.db" \
  --source-root "$PREVIOUS_SOURCE_ROOT"
python3 "$FIXTURE_TOOL" seed \
  --database "$WORK_DIR/previous-baseline.db" \
  --manifest "$WORK_DIR/fixture.json"
install_private_db "$WORK_DIR/previous-baseline.db"
install_offline_preferences

# Prove the previous APK itself can open the source-derived seeded database
# before attempting the in-place upgrade. This catches an inaccurate fixture.
launch_app
snapshot_db "previous-seeded"
python3 "$FIXTURE_TOOL" verify --database "$WORK_DIR/previous-seeded.db" --manifest "$WORK_DIR/fixture.json"

PREVIOUS_VERSION="$(adb shell dumpsys package "$PACKAGE" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1 | tr -d '\r')"
echo "Previous installed versionCode=$PREVIOUS_VERSION"

echo "== Simulate offline package replacement =="
adb shell cmd connectivity airplane-mode enable >/dev/null 2>&1 || {
  adb shell settings put global airplane_mode_on 1 || true
  adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true >/dev/null 2>&1 || true
}

# This is deliberately an in-place update. Never uninstall or clear app data here.
adb install -r "$CURRENT_APK"
wait_for_package
CURRENT_VERSION="$(adb shell dumpsys package "$PACKAGE" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | head -1 | tr -d '\r')"
echo "Current installed versionCode=$CURRENT_VERSION"
if [ -z "$PREVIOUS_VERSION" ] || [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" -le "$PREVIOUS_VERSION" ]; then
  echo "::error::Upgrade probe did not move to a higher versionCode ($PREVIOUS_VERSION -> $CURRENT_VERSION)." >&2
  exit 1
fi

launch_app
snapshot_db "current-offline"
python3 "$FIXTURE_TOOL" verify --database "$WORK_DIR/current-offline.db" --manifest "$WORK_DIR/fixture.json"

echo "== Restore connectivity and verify startup cannot erase the upgraded data =="
adb shell cmd connectivity airplane-mode disable >/dev/null 2>&1 || {
  adb shell settings put global airplane_mode_on 0 || true
  adb shell am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false >/dev/null 2>&1 || true
}
sleep 3
launch_app
snapshot_db "current-reconnected"
python3 "$FIXTURE_TOOL" verify --database "$WORK_DIR/current-reconnected.db" --manifest "$WORK_DIR/fixture.json"

echo "[OK] Real Android in-place upgrade preserved all sentinel finance data before and after reconnect."
