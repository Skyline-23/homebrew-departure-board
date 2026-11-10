# GitHub Actions deployment

## Release requirements

The tag-triggered `Release Departure Board` workflow uses the `macos-release`
environment. It must have these encrypted secrets:

| Secret | Contents |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded P12 containing the Developer ID Application certificate and its private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that P12 |
| `APP_STORE_CONNECT_KEY_P8_BASE64` | Base64-encoded App Store Connect API private key |
| `APP_STORE_CONNECT_KEY_ID` | ID of the API key |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer UUID for a team API key; leave unset for an individual key |

Set the repository or environment variable `APPLE_TEAM_ID` to the signing team.
An Apple Development certificate is for development and cannot replace a
Developer ID Application certificate for notarization.

The workflow imports the certificate into an isolated temporary keychain, signs
both universal bundles with hardened runtime and a secure timestamp, and runs
the application tests. It submits the app and screen saver together to Apple's
notary service and attaches a ticket to each bundle.

Only after acceptance does it package the download, extract it again, verify
both signatures and tickets, and check the app with Gatekeeper. A failed check
stops the release before publishing or updating Homebrew. The temporary
keychain and decoded credential files are removed after use.

Build validation on branches and pull requests needs no signing secrets and may
use ad-hoc signatures. Local source builds are also distinct from notarized
release downloads. Releases through **0.6.1** were not notarized.

## Windows release gate

The release workflow runs macOS and Windows builds in parallel. Native x64 and
ARM64 runners check formatting, shared logic, rendered boards, screen-saver
embedding, credential storage, single-instance behavior and installation,
upgrade and removal. The x64 and ARM64 Setup.exe installers, self-contained ZIPs
and their SHA-256 files are attached to the same release only after those jobs
and macOS notarization pass.
Windows packages remain explicitly unsigned previews; macOS signing secrets
are not used for them.

A failed platform job prevents publication and the Homebrew update. Tag the
reviewed merge on `main` as `v<version>` to start the complete release.

## Local notarization

Build with a Developer ID identity and the same `APPLE_TEAM_ID`. Use a validated
`NOTARY_KEYCHAIN_PROFILE` or the API-key environment variables above with:

```sh
./script/notarize.sh
./script/package.sh
./script/notarize.sh "outputs/DepartureBoard/dist/DepartureBoard-$VERSION-universal.dmg"
./script/validate-distribution.sh
```

`VERSION` must match the built bundles. Do not re-sign an accepted bundle: a new
signature requires a new notarization. The Homebrew launcher preserves valid
Developer ID signatures rather than replacing them with local development signatures.

References: [Apple notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution),
[Developer ID certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates).

## Flight API credentials

No flight-provider credential is needed by GitHub Actions. Each user saves their
own AeroDataBox RapidAPI key in the companion app. It remains in that user's macOS
Keychain or Windows Credential Manager and is sent only to the provider's RapidAPI endpoint.

## Native installers and settings refresh

The macOS release includes a signed, notarized DMG as the primary website download. The disk image contains the universal app, screen saver, an Applications shortcut and the offline illustrated guide. Bundle notarization runs before packaging, followed by a separate DMG notarization and verification. ZIPs remain available for Homebrew and existing installation workflows.

Windows continues to publish separate self-contained x64 and ARM64 Setup.exe files. The refreshed settings group controls under Display, Desktop and Flight data, with persistent Apply changes and Preview actions. The native self-test captures the regular, scrolled-data and compact settings layouts.

## CI and website automation

Validation first classifies changed files. Product-site and guide changes use a small Ubuntu job; native source changes run the macOS bundle suite. Superseded validation runs are cancelled. Windows caches NuGet packages and the verified installer compiler, and avoids building an unused portable desktop application before publishing the runtime-specific package.

The Nitroship GitHub integration connects only `Skyline-23/homebrew-departure-board`. Repository-root `nitroship.json` defines the production website build. Production deployment is enabled for `main`, and branch previews are disabled.

One tag-triggered workflow builds both platforms in parallel, verifies them, publishes a complete GitHub release and updates Homebrew from the released archives. Both platform versions are derived from the release tag. That `main` push triggers the website deployment. The final CI job waits for the matching public `release.json`, checks both guide languages and verifies that all three download routes resolve to installers in the same GitHub release. The workflow succeeds only after the live website passes those checks.

Installers are stored and downloaded from GitHub Releases. Nitroship serves the product pages, illustrated guide and download redirects. CI renders the Korean and English Open Graph images from `site/og-template.html` using Chrome, validates the 1200×630 PNGs and commits them with the Homebrew update. The website build adds the release version to each image URL for cache invalidation. Apple ticket-service failures with exit code 68 are retried up to three times; other signing errors fail immediately.
