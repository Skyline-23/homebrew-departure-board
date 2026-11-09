#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_BUNDLES="$PROJECT_ROOT/work/Build.noindex/Bundles"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
TEMP_ROOT="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/departure-notarize.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT
BUNDLES="$TEMP_ROOT/Bundles"
mkdir -p "$BUNDLES"

# Synced folders can add FinderInfo after signing. Submit clean copies outside
# that folder, just as packaging does, without changing the signed contents.

for name in 'Departure Board.app' 'Departure Board.saver'; do
  ditto --noextattr --norsrc "$SOURCE_BUNDLES/$name" "$BUNDLES/$name"
done

for bundle in "$BUNDLES/Departure Board.app" "$BUNDLES/Departure Board.saver"; do
  codesign --verify --strict "$bundle"
  METADATA="$(codesign -dv --verbose=4 "$bundle" 2>&1)"

  if ! grep -q '^Authority=Developer ID Application:' <<< "$METADATA" || \
     ! grep -q "^TeamIdentifier=$APPLE_TEAM_ID$" <<< "$METADATA" || \
     ! grep -q '^Timestamp=' <<< "$METADATA" || \
     ! grep -q 'flags=.*(runtime)' <<< "$METADATA"; then
    printf 'Notarization requires timestamped Developer ID signatures with hardened runtime from the configured team.\n' >&2
    exit 1
  fi
done

AUTH=()

if [[ -n "${NOTARY_KEYCHAIN_PROFILE:-}" ]]; then
  AUTH=(--keychain-profile "$NOTARY_KEYCHAIN_PROFILE")
else
  : "${APP_STORE_CONNECT_KEY_P8_BASE64:?Set APP_STORE_CONNECT_KEY_P8_BASE64}"
  : "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID}"
  KEY_FILE="$TEMP_ROOT/AuthKey.p8"
  printf '%s' "$APP_STORE_CONNECT_KEY_P8_BASE64" | base64 --decode > "$KEY_FILE"
  chmod 600 "$KEY_FILE"
  AUTH=(--key "$KEY_FILE" --key-id "$APP_STORE_CONNECT_KEY_ID")

  if [[ -n "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then AUTH+=(--issuer "$APP_STORE_CONNECT_ISSUER_ID"); fi
fi

# Both executables are scanned in the same submission; staple each bundle afterward.
COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr --keepParent "$BUNDLES" "$TEMP_ROOT/submission.zip"
set +e
xcrun notarytool submit "$TEMP_ROOT/submission.zip" "${AUTH[@]}" --wait --timeout 20m \
  --output-format json > "$TEMP_ROOT/result.json"
SUBMIT_STATUS=$?
set -e
STATUS="$(python3 - "$TEMP_ROOT/result.json" <<'PYRESULT'
import json,sys
try:
    print(json.load(open(sys.argv[1])).get('status','Unknown'))
except (ValueError,OSError):
    print('Unknown')
PYRESULT
)"
mkdir -p "$PROJECT_ROOT/work"
rm -f "$PROJECT_ROOT/work/notarization-log.json"
cp "$TEMP_ROOT/result.json" "$PROJECT_ROOT/work/notarization-result.json"
SUBMISSION_ID="$(python3 - "$TEMP_ROOT/result.json" <<'PYID'
import json,sys
try:
    print(json.load(open(sys.argv[1])).get('id',''))
except (ValueError,OSError):
    pass
PYID
)"

if [[ -n "$SUBMISSION_ID" ]]; then
  xcrun notarytool log "$SUBMISSION_ID" "${AUTH[@]}" \
    "$PROJECT_ROOT/work/notarization-log.json" || true
fi

if [[ "$SUBMIT_STATUS" != 0 || "$STATUS" != Accepted ]]; then
  python3 - "$TEMP_ROOT/result.json" <<'PY'
import json,sys
try:
    result=json.load(open(sys.argv[1]))
except (ValueError,OSError):
    result={}
print('Notarization did not succeed:',result.get('status','Unknown'),result.get('id',''))
PY

  if [[ -f "$PROJECT_ROOT/work/notarization-log.json" ]]; then
    cat "$PROJECT_ROOT/work/notarization-log.json" >&2
  fi
  exit 1
fi

for bundle in "$BUNDLES/Departure Board.app" "$BUNDLES/Departure Board.saver"; do
  xcrun stapler staple "$bundle"
  xcrun stapler validate "$bundle"
done
spctl --assess --type execute --verbose=4 "$BUNDLES/Departure Board.app"

for name in 'Departure Board.app' 'Departure Board.saver'; do
  rm -rf "$SOURCE_BUNDLES/$name"
  ditto --noextattr --norsrc "$BUNDLES/$name" "$SOURCE_BUNDLES/$name"
done
printf 'Notarization accepted; tickets attached to both bundles.\n'
