#!/bin/bash
set -euo pipefail
[[ "${CI:-}" == true ]] || { echo 'Run installation tests on a disposable CI Mac.' >&2; exit 1; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="$ROOT/work/installation-checks"
APP='/Applications/Departure Board.app'
SAVER="$HOME/Library/Screen Savers/Departure Board.saver"
mkdir -p "$REPORT"
test ! -e "$APP"
test ! -e "$SAVER"
brew tap Skyline-23/departure-board
if brew command trust >/dev/null 2>&1; then
  brew trust --cask skyline-23/departure-board/departure-board
fi
HOMEBREW_NO_AUTO_UPDATE=1 brew install --cask skyline-23/departure-board/departure-board
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ -z "${EXPECTED_VERSION:-}" || "$VERSION" == "$EXPECTED_VERSION" ]]
validate_ticket() {
  for attempt in 1 2 3; do
    if xcrun stapler validate "$1"; then return 0; fi
    [[ "$attempt" == 3 ]] || sleep 5
  done
  return 1
}
for bundle in "$APP" "$SAVER"; do
  codesign --verify --strict "$bundle"
  validate_ticket "$bundle"
  metadata="$(codesign -dvv "$bundle" 2>&1)"
  grep -q '^TeamIdentifier=Q23JLSJCCV$' <<< "$metadata"
  lipo "$bundle/Contents/MacOS/DepartureBoard" -verify_arch "$(uname -m)"
done
spctl --assess --type execute --verbose=4 "$APP" 2>&1 | tee "$REPORT/gatekeeper.txt"
# Gatekeeper's one-time Open confirmation requires a person. After verifying
# the real download above, approve only these test bundles for unattended UI tests.
xattr -dr com.apple.quarantine "$APP" "$SAVER"
xcrun swift "$ROOT/Tests/InstalledApplication.swift" "$VERSION" | tee "$REPORT/application.txt"
xcrun clang -fobjc-arc -framework Cocoa -framework ScreenSaver \
  "$ROOT/Tests/InstalledScreenSaver.m" -o "$REPORT/ScreenSaverCheck"
"$REPORT/ScreenSaverCheck" "$SAVER" | tee "$REPORT/screensaver.txt"
brew list --cask --versions departure-board | tee "$REPORT/homebrew.txt"
printf 'Clean Homebrew install and native launch passed on %s.\n' "$(uname -m)"
