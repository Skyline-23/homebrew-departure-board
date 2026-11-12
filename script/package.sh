#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
DIST="$PROJECT_ROOT/outputs/DepartureBoard/dist"
BUNDLES="$PROJECT_ROOT/work/Build.noindex/Bundles"
mkdir -p "$DIST"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/departure-board-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto --noextattr --norsrc "$BUNDLES/Departure Board.app" "$STAGING/Departure Board.app"
ditto --noextattr --norsrc "$BUNDLES/Departure Board.saver" "$STAGING/Departure Board.saver"
cp "$PROJECT_ROOT/LICENSE" "$STAGING/LICENSE"
cp -R "$PROJECT_ROOT/Resources/Guide" "$STAGING/Guide"
cp "$PROJECT_ROOT/Resources/Install Guide.html" "$STAGING/Install Guide.html"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr "$STAGING" "$DIST/DepartureBoard-$VERSION-universal.zip"
shasum -a 256 "$DIST/DepartureBoard-$VERSION-universal.zip"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent \
  "$STAGING/Departure Board.app" "$DIST/DepartureBoard-$VERSION-update.zip"
ln -s /Applications "$STAGING/Applications"
DISK_IMAGE="$DIST/DepartureBoard-$VERSION-universal.dmg"
hdiutil create -volname "Departure Board" -srcfolder "$STAGING" -fs HFS+ -format UDZO -ov "$DISK_IMAGE"
SIGN_FLAGS=(--force --sign "${CODE_SIGN_IDENTITY:--}")

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then SIGN_FLAGS+=(--timestamp); fi

if [[ -n "${CODE_SIGN_KEYCHAIN:-}" ]]; then SIGN_FLAGS+=(--keychain "$CODE_SIGN_KEYCHAIN"); fi
codesign "${SIGN_FLAGS[@]}" "$DISK_IMAGE"
codesign --verify --strict "$DISK_IMAGE"
git -C "$PROJECT_ROOT" archive --format=tar.gz --prefix="departure-board-$VERSION/" HEAD > "$DIST/DepartureBoard-$VERSION-source.tar.gz"
shasum -a 256 "$DIST/DepartureBoard-$VERSION-source.tar.gz"
