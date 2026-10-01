#!/usr/bin/env bash
set -euo pipefail

ARCH="${1:?usage: fetch_linuxdeploy.sh <x86_64|aarch64> <output-path>}"
OUTPUT="${2:?usage: fetch_linuxdeploy.sh <x86_64|aarch64> <output-path>}"
REPOSITORY="linuxdeploy/linuxdeploy"
TAG="continuous"
ASSET="linuxdeploy-${ARCH}.AppImage"
DIRECT_URL="https://github.com/${REPOSITORY}/releases/download/${TAG}/${ASSET}"

case "$ARCH" in
  x86_64)
    FILE_ARCH_PATTERN='x86-64|x86_64'
    ;;
  aarch64)
    FILE_ARCH_PATTERN='ARM aarch64|aarch64'
    ;;
  *)
    echo "::error::Unsupported linuxdeploy architecture: $ARCH"
    exit 2
    ;;
esac

mkdir -p "$(dirname "$OUTPUT")"
TMP="${OUTPUT}.part"

validate_linuxdeploy() {
  local candidate="$1"
  [ -s "$candidate" ] || return 1

  # AppImage type 2 executables are ELF binaries. Reject HTML/JSON error bodies
  # and reject a cached/downloaded binary for the wrong runner architecture.
  local description
  description="$(file -b "$candidate" 2>/dev/null || true)"
  if ! grep -Eq 'ELF .* executable' <<<"$description"; then
    echo "linuxdeploy validation rejected non-ELF payload: ${description:-unknown file type}" >&2
    return 1
  fi
  if ! grep -Eqi "$FILE_ARCH_PATTERN" <<<"$description"; then
    echo "linuxdeploy validation rejected wrong architecture for $ARCH: $description" >&2
    return 1
  fi

  # linuxdeploy AppImages are self-extracting. This lightweight invocation
  # catches truncated ELF files before the packaging step tries to execute one.
  chmod +x "$candidate"
  if ! APPIMAGE_EXTRACT_AND_RUN=1 "$candidate" --version >/dev/null 2>&1; then
    echo "linuxdeploy validation could not execute $candidate" >&2
    return 1
  fi
  return 0
}

if validate_linuxdeploy "$OUTPUT"; then
  echo "Using cached validated linuxdeploy: $OUTPUT"
  exit 0
fi
rm -f "$OUTPUT" "$TMP"

# GitHub-hosted runners include gh. Its release-download path uses GitHub's API
# rather than relying solely on the browser release-asset URL that can
# intermittently return HTTP 5xx responses.
if command -v gh >/dev/null 2>&1; then
  for attempt in 1 2 3; do
    rm -f "$TMP"
    echo "Downloading $ASSET with GitHub CLI (attempt $attempt/3)..."
    if gh release download "$TAG" \
      --repo "$REPOSITORY" \
      --pattern "$ASSET" \
      --output "$TMP" \
      --clobber; then
      if validate_linuxdeploy "$TMP"; then
        mv "$TMP" "$OUTPUT"
        echo "Validated linuxdeploy downloaded with GitHub CLI."
        exit 0
      fi
    fi
    sleep $((attempt * 2))
  done
fi

# Final fallback for environments without gh or when the API path has a
# transient failure. Retry all network/HTTP errors with bounded timeouts.
rm -f "$TMP"
echo "GitHub CLI download unavailable/failed; trying direct release asset URL..."
if curl --fail --location \
  --retry 8 --retry-all-errors --retry-delay 2 --retry-max-time 180 \
  --connect-timeout 20 --max-time 300 \
  --silent --show-error \
  "$DIRECT_URL" \
  --output "$TMP"; then
  if validate_linuxdeploy "$TMP"; then
    mv "$TMP" "$OUTPUT"
    echo "Validated linuxdeploy downloaded with direct URL fallback."
    exit 0
  fi
fi

rm -f "$TMP"
echo "::error::Could not obtain a valid $ASSET from GitHub after API and direct-download retries."
exit 1
