#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${VERSION:?Set VERSION}"
ARCHIVE="$PROJECT_ROOT/outputs/DepartureBoard/dist/DepartureBoard-$VERSION-universal.zip"
CHECK_ROOT="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/departure-distribution.XXXXXX")"
trap 'rm -rf "$CHECK_ROOT"' EXIT
ditto -x -k "$ARCHIVE" "$CHECK_ROOT"

test -f "$CHECK_ROOT/Install Guide.html"
test -f "$CHECK_ROOT/Guide/index.html"
test -f "$CHECK_ROOT/Guide/ko.html"

for name in 'Departure Board.app' 'Departure Board.saver'; do
  bundle="$CHECK_ROOT/$name"
  test -f "$bundle/Contents/Resources/Guide/index.html"
  test -f "$bundle/Contents/Resources/Guide/ko.html"
  codesign --verify --strict "$bundle"
  xcrun stapler validate "$bundle"
  actual="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$bundle/Contents/Info.plist")"
  test "$actual" = "$VERSION"

  for architecture in arm64 x86_64; do
    lipo "$bundle/Contents/MacOS/DepartureBoard" -verify_arch "$architecture"
  done
done
spctl --assess --type execute --verbose=4 "$CHECK_ROOT/Departure Board.app"
printf 'Final ZIP signatures, notarization tickets and universal binaries verified.\n'

DISK_IMAGE="$PROJECT_ROOT/outputs/DepartureBoard/dist/DepartureBoard-$VERSION-universal.dmg"
hdiutil verify "$DISK_IMAGE"
codesign --verify --strict "$DISK_IMAGE"
xcrun stapler validate "$DISK_IMAGE"
MOUNT_POINT="$CHECK_ROOT/disk-image"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$DISK_IMAGE" -readonly -nobrowse -mountpoint "$MOUNT_POINT"
trap 'hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true; rm -rf "$CHECK_ROOT"' EXIT

for name in 'Departure Board.app' 'Departure Board.saver'; do
  codesign --verify --strict "$MOUNT_POINT/$name"
  xcrun stapler validate "$MOUNT_POINT/$name"
done
test -L "$MOUNT_POINT/Applications"
test -f "$MOUNT_POINT/Install Guide.html"
hdiutil detach "$MOUNT_POINT"
printf 'Final DMG and contained notarized bundles verified.\n'
