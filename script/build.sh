#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/work/build"
DIST_DIR="$PROJECT_ROOT/outputs/DepartureBoard/dist"
APP_NAME="Departure Board"
VERSION="${VERSION:-0.1.0}"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Both bundles share the same drawing and timetable code. No WebView or network service.
COMMON_SOURCES=()
for source in DepartureSchedule Localization LiveFlightStore BoardView DrawingSupport BoardChrome AirportRenderer SplitFlapRenderer RailwayRenderer SettingsController; do
  COMMON_SOURCES+=("$PROJECT_ROOT/Sources/$source.m")
done
COMMON_FLAGS=(-fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=12.0 -framework Cocoa -framework CoreText -framework Security -framework LocalAuthentication)
ARCH_FLAGS=(-arch arm64 -arch x86_64)
if [[ "${BUILD_ARCH:-universal}" != "universal" ]]; then ARCH_FLAGS=(-arch "$BUILD_ARCH"); fi

make_bundle() {
  local bundle="$1" executable="$2" identifier="$3" package="$4" principal="$5"
  rm -rf "$bundle"
  mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
  cp -R "$PROJECT_ROOT/Resources/." "$bundle/Contents/Resources/"
  local plist="$bundle/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleName string Departure Board" "$plist" >/dev/null
  /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Departure Board" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $executable" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $identifier" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string $package" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 12.0" "$plist"
  /usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string $principal" "$plist"
  /usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$plist"
  /usr/libexec/PlistBuddy -c "Add :NSHumanReadableCopyright string Departure Board contributors. MIT License." "$plist"

}

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
SAVER_BUNDLE="$BUILD_DIR/DepartureBoardSaver.bundle"
make_bundle "$APP_BUNDLE" DepartureBoard io.skyline.departureboard.preview APPL NSApplication
make_bundle "$SAVER_BUNDLE" DepartureBoard io.skyline.departureboard.saver BNDL DepartureBoardSaver

xcrun clang "${COMMON_FLAGS[@]}" "${ARCH_FLAGS[@]}" "${COMMON_SOURCES[@]}" "$PROJECT_ROOT/Sources/App.m" -o "$APP_BUNDLE/Contents/MacOS/DepartureBoard"
xcrun clang "${COMMON_FLAGS[@]}" "${ARCH_FLAGS[@]}" -bundle -framework ScreenSaver "${COMMON_SOURCES[@]}" "$PROJECT_ROOT/Sources/ScreenSaver.m" -o "$SAVER_BUNDLE/Contents/MacOS/DepartureBoard"

# Local builds use an ad-hoc signature. Release signing is opt-in and uses the caller's identity.
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
SIGNING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/departure-board-sign.XXXXXX")"
trap 'rm -rf "$SIGNING_DIR"' EXIT
for bundle in "$APP_BUNDLE" "$SAVER_BUNDLE"; do
  # Sign outside synced Documents: File Provider can attach FinderInfo during a build.
  clean_bundle="$SIGNING_DIR/$(basename "$bundle")"
  ditto --noextattr --norsrc "$bundle" "$clean_bundle"
  xattr -cr "$clean_bundle"
  codesign --force --sign "$SIGN_IDENTITY" --options runtime "$clean_bundle"
  codesign --verify --strict "$clean_bundle"
  rm -rf "$bundle"
  ditto --noextattr --norsrc "$clean_bundle" "$bundle"
done
rm -rf "$DIST_DIR/$APP_NAME.saver"
ditto --noextattr --norsrc "$SAVER_BUNDLE" "$DIST_DIR/$APP_NAME.saver"
printf 'Built %s and %s\n' "$APP_BUNDLE" "$SAVER_BUNDLE"
