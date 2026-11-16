#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
TEST_APP="$PROJECT_ROOT/work/Build.noindex/DesktopSelectionTests.app"
mkdir -p "$TEST_APP/Contents/MacOS"
cat > "$TEST_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.skyline23.departureboard.desktop-tests</string>
<key>CFBundleExecutable</key><string>DesktopSelectionTests</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
PLIST
ditto --noextattr --norsrc Resources "$TEST_APP/Contents/Resources"
source "$PROJECT_ROOT/script/common-sources.sh"
xcrun clang -I "$PROJECT_ROOT/Sources" -fobjc-arc -fmodules -O0 -mmacosx-version-min=12.0 \
  -framework Cocoa -framework QuartzCore -framework Security -framework LocalAuthentication \
  "${COMMON_SOURCES[@]}" "${APP_SOURCES[@]}" Tests/DesktopSelection.m \
  -o "$TEST_APP/Contents/MacOS/DesktopSelectionTests"
TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/departure-desktop.XXXXXX")"
trap 'rm -rf "$TEST_HOME"' EXIT

for scenario in single connected; do
  "$TEST_APP/Contents/MacOS/DesktopSelectionTests" "$TEST_HOME/$scenario" "$scenario"
done
