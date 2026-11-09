#!/bin/bash
set -euo pipefail
: "${APPLE_CERTIFICATE_P12_BASE64:?Set APPLE_CERTIFICATE_P12_BASE64 in release secrets}"
: "${APPLE_CERTIFICATE_PASSWORD:?Set APPLE_CERTIFICATE_PASSWORD in release secrets}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for the signing team}"
: "${GITHUB_ENV:?This script imports a temporary signing identity for GitHub Actions}"

TEMP_ROOT="${RUNNER_TEMP:-${TMPDIR:-/tmp}}"
CERTIFICATE_FILE="$(mktemp "$TEMP_ROOT/departure-certificate.XXXXXX")"
SIGNING_KEYCHAIN="$TEMP_ROOT/departure-signing-$(uuidgen).keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
IMPORTED=0
cleanup() {
  rm -f "$CERTIFICATE_FILE"
  if [[ "$IMPORTED" != 1 ]]; then security delete-keychain "$SIGNING_KEYCHAIN" >/dev/null 2>&1 || true; fi
}
trap cleanup EXIT
printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode > "$CERTIFICATE_FILE"
chmod 600 "$CERTIFICATE_FILE"
security create-keychain -p "$KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN"
security set-keychain-settings -lut 21600 "$SIGNING_KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$SIGNING_KEYCHAIN"
security import "$CERTIFICATE_FILE" -f pkcs12 -k "$SIGNING_KEYCHAIN" -P "$APPLE_CERTIFICATE_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" \
  "$SIGNING_KEYCHAIN" >/dev/null
IDENTITY="$(security find-identity -v -p codesigning "$SIGNING_KEYCHAIN" | \
  awk -v team="$APPLE_TEAM_ID" '/Developer ID Application:/ && index($0, "(" team ")") {print $2; exit}')"
if [[ -z "$IDENTITY" ]]; then
  printf 'The P12 does not contain a valid Developer ID Application identity for the configured team.\n' >&2
  exit 1
fi
printf 'CODE_SIGN_IDENTITY=%s\nCODE_SIGN_KEYCHAIN=%s\n' "$IDENTITY" "$SIGNING_KEYCHAIN" >> "$GITHUB_ENV"
IMPORTED=1
printf 'Imported the Developer ID Application signing identity into a temporary keychain.\n'
