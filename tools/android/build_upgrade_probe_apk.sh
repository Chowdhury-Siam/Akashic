#!/usr/bin/env bash
set -euo pipefail

TREE="${1:?Usage: build_upgrade_probe_apk.sh <source-tree> <output-apk>}"
OUTPUT_APK="${2:?Usage: build_upgrade_probe_apk.sh <source-tree> <output-apk>}"

if [ ! -d "$TREE" ]; then
  echo "::error::Upgrade probe source tree does not exist: $TREE"
  exit 1
fi

TREE="$(cd "$TREE" && pwd)"
OUTPUT_APK="$(python3 -c 'import os,sys; print(os.path.abspath(sys.argv[1]))' "$OUTPUT_APK")"
mkdir -p "$(dirname "$OUTPUT_APK")"

pushd "$TREE" >/dev/null

# The Actions pub cache is only an optimization. A previous published source tree
# can legitimately need a package that is absent from the restored cache, so do
# a normal locked-source resolution instead of intentionally failing offline first.
flutter pub get

VERSION="$(awk '/^version:/ { print $2; exit }' pubspec.yaml)"
if [ -z "$VERSION" ] || [[ "$VERSION" != *+* ]]; then
  echo "::error::Could not parse version from $TREE/pubspec.yaml: $VERSION"
  exit 1
fi
VERSION_NAME="${VERSION%%+*}"
BUILD_NUMBER="${VERSION##*+}"

# Older Flutter/Gradle project layouts can successfully finish assembleDirectRelease
# but make the Flutter CLI fail while discovering/copying the resulting APK. Capture
# the CLI status, then independently locate and validate the Gradle artifact. A real
# compile/signing failure still fails because no valid x86_64 APK will exist.
set +e
flutter build apk \
  --flavor direct \
  --release \
  --target-platform android-x64 \
  --split-per-abi \
  --build-name="$VERSION_NAME" \
  --build-number="$BUILD_NUMBER" \
  --no-pub \
  --no-tree-shake-icons \
  --dart-define=YUTAKA_APP_VERSION="$VERSION_NAME" \
  --dart-define=YUTAKA_ANDROID_DISTRIBUTION=direct
FLUTTER_BUILD_STATUS=$?
set -e

mapfile -t APK_CANDIDATES < <(
  {
    find build/app/outputs -type f -name '*.apk' -print 2>/dev/null || true
    find android/app/build/outputs -type f -name '*.apk' -print 2>/dev/null || true
  } | awk '!seen[$0]++' | sort
)

if [ ${#APK_CANDIDATES[@]} -eq 0 ]; then
  echo "::error::No APK was produced for upgrade probe source tree: $TREE"
  echo "Flutter build exit code: $FLUTTER_BUILD_STATUS"
  if [ "$FLUTTER_BUILD_STATUS" -ne 0 ]; then
    exit "$FLUTTER_BUILD_STATUS"
  fi
  exit 1
fi

echo "Available upgrade-probe APK outputs for $(basename "$TREE"):"
printf '  %s\n' "${APK_CANDIDATES[@]}"

SELECTED_APK=""
for apk in "${APK_CANDIDATES[@]}"; do
  lower="$(printf '%s' "$apk" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower" != *direct*release*.apk ]]; then
    continue
  fi
  # The real-upgrade emulator is x86_64. Ensure we do not accidentally use an
  # ARM split or an unrelated APK if an older project layout emits several files.
  if unzip -l "$apk" | grep -qE 'lib/x86_64/(libflutter|libapp)\.so'; then
    SELECTED_APK="$apk"
    break
  fi
done

if [ -z "$SELECTED_APK" ]; then
  echo "::error::No direct-release x86_64 APK was found for upgrade probe source tree: $TREE"
  echo "Flutter build exit code: $FLUTTER_BUILD_STATUS"
  exit 1
fi

if [ "$FLUTTER_BUILD_STATUS" -ne 0 ]; then
  echo "::warning::Flutter CLI returned $FLUTTER_BUILD_STATUS after Gradle completed, but a valid x86_64 direct-release APK was found at $SELECTED_APK. Continuing with the verified Gradle artifact."
fi

# Fail if the selected APK is corrupt before the emulator job starts.
unzip -tq "$SELECTED_APK" >/dev/null
cp "$SELECTED_APK" "$OUTPUT_APK"
echo "Upgrade probe APK: $SELECTED_APK -> $OUTPUT_APK"

popd >/dev/null
