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
