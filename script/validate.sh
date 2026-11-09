#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
python3 script/validate.py
for strings in Resources/*.lproj/Localizable.strings; do plutil -lint "$strings" >/dev/null; done
mkdir -p work
xcrun clang -fobjc-arc -framework Cocoa -framework ScreenSaver Tests/ScreenSaverHost.m -o work/ScreenSaverHost
work/ScreenSaverHost "$PROJECT_ROOT/outputs/DepartureBoard/dist/Departure Board.saver"
open -g -n -W "$PROJECT_ROOT/outputs/DepartureBoard/dist/Departure Board.app" --args --snapshot-all "$PROJECT_ROOT/work/validation-previews"
test "$(find work/validation-previews -name '*.png' | wc -l | tr -d ' ')" = 44
printf 'All native bundle, catalogue and language checks passed.\n'
