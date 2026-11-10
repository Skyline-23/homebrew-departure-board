#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/work/Build.noindex"
DIST_DIR="$BUILD_DIR/Bundles"
APP_NAME="Departure Board"
VERSION="${VERSION:-0.1.0}"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

# Both bundles share the same drawing and timetable code. No WebView or network service.
source "$PROJECT_ROOT/script/common-sources.sh"
COMMON_FLAGS=(-I "$PROJECT_ROOT/Sources" -fobjc-arc -fmodules -O2 -Wall -Wextra -Wno-unused-parameter -mmacosx-version-min=12.0 -framework Cocoa -framework QuartzCore -framework Security -framework LocalAuthentication)
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
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $identifier" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string $package" "$plist"

  if [[ "$package" == "APPL" ]]; then
    # Agent status takes effect before main(), including wallpaper/maintenance helpers.
    /usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$plist"
  fi
  /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $VERSION" "$plist"
  /usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 12.0" "$plist"
  /usr/libexec/PlistBuddy -c "Add :NSPrincipalClass string $principal" "$plist"
  /usr/libexec/PlistBuddy -c "Add :NSHighResolutionCapable bool true" "$plist"
  /usr/libexec/PlistBuddy -c "Add :NSHumanReadableCopyright string Departure Board contributors. MIT License." "$plist"

}

APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
SAVER_BUNDLE="$BUILD_DIR/DepartureBoardSaver.bundle"
make_bundle "$APP_BUNDLE" DepartureBoard com.skyline23.departureboard APPL NSApplication
make_bundle "$SAVER_BUNDLE" DepartureBoard com.skyline23.departureboard.saver BNDL DepartureBoardSaver

xcrun clang "${COMMON_FLAGS[@]}" "${ARCH_FLAGS[@]}" "${COMMON_SOURCES[@]}" "${APP_SOURCES[@]}" "$PROJECT_ROOT/Sources/App.m" -o "$APP_BUNDLE/Contents/MacOS/DepartureBoard"
xcrun clang "${COMMON_FLAGS[@]}" "${ARCH_FLAGS[@]}" -bundle -framework ScreenSaver "${COMMON_SOURCES[@]}" "$PROJECT_ROOT/Sources/ScreenSaver.m" -o "$SAVER_BUNDLE/Contents/MacOS/DepartureBoard"

# Local builds use an ad-hoc signature. Release signing is opt-in and uses the caller's identity.
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  # A stable local signing identity keeps Keychain approvals valid across builds.
  SIGN_IDENTITY="$(security find-identity -v -p codesigning | awk '/Developer ID Application:|Apple Development:/ { print $2; exit }')"
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
fi
SIGNING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/departure-board-sign.XXXXXX")"
trap 'rm -rf "$SIGNING_DIR"' EXIT

for bundle in "$APP_BUNDLE" "$SAVER_BUNDLE"; do
  # Sign outside synced Documents: File Provider can attach FinderInfo during a build.
  clean_bundle="$SIGNING_DIR/$(basename "$bundle")"
  ditto --noextattr --norsrc "$bundle" "$clean_bundle"
  # Native screenshots may carry FinderInfo; sign only clean staging metadata.
  xattr -cr "$clean_bundle"
  SIGN_FLAGS=(--force --sign "$SIGN_IDENTITY" --options runtime)

  if [[ "$SIGN_IDENTITY" != "-" ]]; then SIGN_FLAGS+=(--timestamp); fi

  if [[ -n "${CODE_SIGN_KEYCHAIN:-}" ]]; then SIGN_FLAGS+=(--keychain "$CODE_SIGN_KEYCHAIN"); fi
  codesign "${SIGN_FLAGS[@]}" "$clean_bundle"
  codesign --verify --strict "$clean_bundle"
  rm -rf "$bundle"
  ditto --noextattr --norsrc "$clean_bundle" "$bundle"
done
rm -rf "$DIST_DIR/$APP_NAME.saver"
ditto --noextattr --norsrc "$SAVER_BUNDLE" "$DIST_DIR/$APP_NAME.saver"
printf 'Built %s and %s\n' "$APP_BUNDLE" "$SAVER_BUNDLE"
