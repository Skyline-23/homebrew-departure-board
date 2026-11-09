# GitHub Actions deployment

## macOS app and screen saver

The `Release macOS screen saver` workflow runs for `v*` tags. It builds a universal
binary, runs validation, uploads binary and source archives, and commits their corresponding
SHA-256 values to `Casks/departure-board.rb` and `Formula/departure-board.rb`. No provider secret is passed to this job.

Local builds and the initial workflow use ad-hoc code signing. Developer ID
signing and notarization require an Apple Developer distribution identity; an
Apple Development certificate is not a substitute. Do not describe an ad-hoc
artifact as notarized. The recommended formula compiles locally; it does not
install the unnotarized release binary.

## Flight-data gateway

Create a GitHub environment named `flight-data` with these secrets:

| Secret | Used for |
| --- | --- |
| `CLOUDFLARE_API_TOKEN` | Deploying the Worker and writing Worker secrets |
| `CLOUDFLARE_ACCOUNT_ID` | Selecting the Cloudflare account |
| `AERODATABOX_API_KEY` | Authenticating AeroDataBox through RapidAPI |
| `BOARD_ACCESS_TOKEN` | Authenticating this user's companion app |

The gateway workflow puts the last two values into encrypted Worker secrets.
They are never written into the source tree, release ZIP, cask or log output.
The client stores only the gateway access token in macOS Keychain.

The Worker uses a single Durable Object to enforce an account-wide daily request
allowance and to prevent simultaneous clients from duplicating upstream calls.
Its default is four provider requests per UTC day and a six-hour cache window,
with a 12-hour departure horizon. This spreads one airport's free-plan refreshes
across the day instead of spending the daily allowance in the first hour.
Both are in `server/wrangler.jsonc`; adjust them only within the chosen provider
plan. A stale result is labelled cached, and data older than seven days is not
served. The app refuses to display a local snapshot older than 24 hours.

Run `Deploy flight-data gateway` after setting secrets. The workflow explicitly
skips deployment when required credentials are missing; successful validation is
separate from a successful deployment.
