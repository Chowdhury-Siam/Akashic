#!/usr/bin/env bash
# Run from the repository root: bash tools/test_release_version.sh
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
readers=0
for workflow in "$repo"/.github/workflows/*.yml; do
  while IFS= read -r command; do
    for ending in '\n' '\r\n'; do
      printf "name: yutaka${ending}version: 1.0.1258+302${ending}" > "$scratch/pubspec.yaml"
      (
        cd "$scratch"
        eval "$command"
        test "$FULL_VERSION" = '1.0.1258+302'
        test "${FULL_VERSION%%+*}" = '1.0.1258'
        test "${FULL_VERSION##*+}" = '302'
      )
    done
    readers=$((readers + 1))
  done < <(awk '/^[[:space:]]+FULL_VERSION=/ { sub(/^[[:space:]]+/, ""); sub(/\r$/, ""); print }' "$workflow")
done
test "$readers" -eq 5
printf 'All %s Bash version readers pass LF and CRLF checks.\n' "$readers"
