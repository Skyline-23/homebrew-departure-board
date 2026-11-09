#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
DIST="$PROJECT_ROOT/outputs/DepartureBoard/dist"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/departure-board-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto --noextattr --norsrc "$DIST/Departure Board.app" "$STAGING/Departure Board.app"
ditto --noextattr --norsrc "$DIST/Departure Board.saver" "$STAGING/Departure Board.saver"
cp "$PROJECT_ROOT/LICENSE" "$STAGING/LICENSE"
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr "$STAGING" "$DIST/DepartureBoard-$VERSION-universal.zip"
shasum -a 256 "$DIST/DepartureBoard-$VERSION-universal.zip"
git -C "$PROJECT_ROOT" archive --format=tar.gz --prefix="departure-board-$VERSION/" HEAD > "$DIST/DepartureBoard-$VERSION-source.tar.gz"
shasum -a 256 "$DIST/DepartureBoard-$VERSION-source.tar.gz"
