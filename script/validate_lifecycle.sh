#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
TEST_APP="$PROJECT_ROOT/work/AppLifecycleTests.app"
mkdir -p "$TEST_APP/Contents/MacOS"
cp "outputs/DepartureBoard/dist/Departure Board.app/Contents/Info.plist" "$TEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable AppLifecycleTests' "$TEST_APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.skyline23.departureboard.lifecycle-tests' "$TEST_APP/Contents/Info.plist"
ditto --noextattr --norsrc Resources "$TEST_APP/Contents/Resources"
SOURCES=()
for source in Sources/*.m; do
  case "$source" in Sources/App.m|Sources/ScreenSaver.m) continue;; esac
  SOURCES+=("$source")
done
xcrun clang -fobjc-arc -fmodules -O2 -mmacosx-version-min=12.0 \
  -framework Cocoa -framework QuartzCore -framework CoreText -framework Security -framework LocalAuthentication \
  "${SOURCES[@]}" Tests/AppLifecycle.m -o "$TEST_APP/Contents/MacOS/AppLifecycleTests"
RESULT="$(mktemp "${TMPDIR:-/tmp}/departure-lifecycle.XXXXXX")"
trap 'unlink "$RESULT"' EXIT
printf 'pending' > "$RESULT"
open -g -n -W "$TEST_APP" --args "$RESULT"
test "$(cat "$RESULT")" = passed
printf 'Passed 12 close/reopen cycles, Dock transitions and startup/recovery decisions.\n'
