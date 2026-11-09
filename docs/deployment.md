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

## API credentials

No API credential is needed by GitHub Actions. Each user saves their own
AeroDataBox RapidAPI key in the companion app. The key remains in their Mac's
Keychain and is sent only to the official AeroDataBox RapidAPI endpoint.

The previous gateway source and deployment workflow have been removed. Older
0.2.x installations using that gateway must upgrade and enter a personal key.
