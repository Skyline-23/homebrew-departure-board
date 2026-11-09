# Departure Board

A native macOS screen saver with departure-board profiles for 40 airports and
four railway stations. Includes a companion app for previewing and configuring
the board. The settings interface is English. Boards start in English, then
alternate with the selected location's language every 12 seconds.

## Install

```sh
brew tap Skyline-23/departure-board
brew install --formula skyline-23/departure-board/departure-board
departure-board
```

Homebrew compiles the app on your Mac. Its first launch registers it in
`~/Applications` and `~/Library/Screen Savers`, outside Homebrew's isolated build
environment. This avoids relying on an unnotarized downloaded binary.

Choose **Departure Board** under **Other** in the screen-saver selector. On current
macOS this is **System Settings → Wallpaper → Screen Saver**; older releases have
a separate **Screen Saver** settings pane. Open the
**Departure Board** app to change location, display style, language, density,
brightness and the live-data gateway. Requires macOS 12 or later; release
builds target the current Mac. Binary release ZIPs also contain Apple Silicon and Intel architectures.

## Live flight information

The app does not contain an airline-data provider key. An authenticated
Cloudflare Worker calls AeroDataBox and caches normalized departure data. The
companion app stores the gateway access token in Keychain and refreshes a local
cache. The screen saver reads that cache without network requests or Keychain
prompts over the lock screen.

1. Subscribe to AeroDataBox through RapidAPI.
2. Add the secrets listed in [deployment.md](docs/deployment.md) to GitHub.
3. Run **Deploy flight-data gateway** in GitHub Actions.
4. Enter the deployed HTTPS URL and gateway access token in the companion app.

Missing or expired live data is shown as unavailable. A separately selected
**Sample schedule** mode is available for visual previews. Railway profiles
currently have sample timetables; they are not presented as live rail feeds.

The default upstream allowance is four requests per day with six-hour refreshes
and a 12-hour departure horizon to stay within the free plan. The daily allowance
is shared across all selected airports. Change it to match the subscribed allowance before using
frequent live refreshes. AeroDataBox coverage, update times and gate availability
vary by airport. Cached information retains its provider attribution and is never
kept for more than the permitted seven-day retention period.

## Visual profiles

Each airport has its own palette, column order, panel count, row density and
reference photograph. Haneda includes its check-in area diagram; Changi uses
highlighted gate cells; Heathrow uses its yellow header; Incheon uses blue paired
panels. Railway renderers have their own table and column layouts. A classic
split-flap renderer is available as an alternative for airports.

The reference catalogue records the photographs used. These are reconstructed
display profiles, not airport-endorsed software or a promise that every terminal
uses the same display today.

## Build and validate

Requires Xcode command-line tools, Python 3, and Node.js 22.

```sh
./script/build_and_run.sh
./script/validate.sh
```

`build.sh` creates the `.app` and `.saver`; `validate.sh` checks the catalogue,
language bundles, gateway behaviour and native screen-saver loading, then renders
all 44 profiles. `package.sh` creates the release ZIP. Tags such as `v0.1.0`
trigger GitHub Actions to build, validate, release and update the Homebrew cask.

## Source layout

| Path | Responsibility |
| --- | --- |
| `Sources/BoardView.m` | View lifecycle, language cycling and data selection |
| `Sources/AirportRenderer.m` | Airport panels and location-specific display elements |
| `Sources/RailwayRenderer.m` | Railway tables and train-by-train columns |
| `Sources/SplitFlapRenderer.m` | Mechanical split-flap drawing and animation |
| `Sources/DepartureSchedule.m` | Explicitly labelled sample timetables |
| `Sources/LiveFlightStore.m` | Keychain, local cache and background refresh |
| `Sources/SettingsController.m` | English configuration sheet |
| `Resources/Locations/*.json` | One readable file per location |
| `Resources/*.lproj/Localizable.strings` | Display text and translations |
| `server/src/` | Authenticated, cached AeroDataBox gateway |
| `.github/workflows/` | Validation, release and gateway deployment |

## Credits

Its MIT-licensed city names, airline metadata and sample route lists are reused;
the original licence is included in `Resources/Data-LICENSE`. The native
macOS renderer and integrations are separate implementations. TeX Gyre Heros is
distributed under the included GUST Font License. Airline names and trademarks
belong to their respective owners.

Code: MIT.
