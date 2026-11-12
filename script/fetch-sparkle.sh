#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${SPARKLE_ROOT:-}" ]]; then
  test -f "$SPARKLE_ROOT/Sparkle.framework/Sparkle"
  printf '%s\n' "$SPARKLE_ROOT"
  exit 0
fi
VERSION=2.10.1
DIGEST=1a856d2a9edb8e628de88121d7be04cf0e2167f8641650b78fca00b14244cf27
CACHE="$ROOT/work/dependencies"
ARCHIVE="$CACHE/Sparkle-$VERSION.tar.xz"
DESTINATION="$CACHE/Sparkle-$VERSION"
mkdir -p "$CACHE"

if [[ ! -f "$ARCHIVE" ]] || [[ "$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')" != "$DIGEST" ]]; then
  curl --fail --location --retry 3 --silent --show-error \
    "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" \
    -o "$ARCHIVE.tmp"
  echo "$DIGEST  $ARCHIVE.tmp" | shasum -a 256 --check >/dev/null
  mv "$ARCHIVE.tmp" "$ARCHIVE"
fi

if [[ ! -f "$DESTINATION/Sparkle.framework/Sparkle" ]]; then
  mkdir -p "$DESTINATION"
  tar -xf "$ARCHIVE" -C "$DESTINATION"
fi
printf '%s\n' "$DESTINATION"
