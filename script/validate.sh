#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
python3 script/validate.py
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' 'work/Build.noindex/Bundles/Departure Board.app/Contents/Info.plist')" = true
for strings in Resources/*.lproj/Localizable.strings; do plutil -lint "$strings" >/dev/null; done
mkdir -p work
xcrun clang -fobjc-arc -framework Foundation Tests/UserInstallation.m -o work/UserInstallationTests
work/UserInstallationTests
xcrun clang -fobjc-arc -framework Cocoa -framework ScreenSaver Tests/ScreenSaverHost.m -o work/ScreenSaverHost
work/ScreenSaverHost "$PROJECT_ROOT/work/Build.noindex/Bundles/Departure Board.saver"
# Window lifecycle checks activate test windows; keep them off a user's desktop.
if [[ "${CI:-}" == "true" || "${RUN_INTERACTIVE_TESTS:-0}" == "1" ]]; then
  ./script/validate_lifecycle.sh
fi
open -g -n -W "$PROJECT_ROOT/work/Build.noindex/Bundles/Departure Board.app" --args --snapshot-all "$PROJECT_ROOT/work/validation-previews"
test "$(find work/validation-previews -name '*.png' | wc -l | tr -d ' ')" = 44
printf 'All native bundle, catalogue and language checks passed.\n'
