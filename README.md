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
brightness and your API key. Requires macOS 12 or later. Both Homebrew and
release builds include Apple Silicon and Intel code for the system screen-saver hosts.

## Live flight information

Each user supplies their own AeroDataBox RapidAPI key and subscription. The
companion app calls AeroDataBox directly and stores the key in macOS Keychain.
There is no shared proxy, bundled key, or shared request allowance.

1. Subscribe to AeroDataBox on RapidAPI.
2. Open **Options → Open Departure Board Settings** from the system screen-saver selector, or **Settings** in the app.
3. Enter your personal RapidAPI key and select **Apply**.

The app, screen saver and live desktop wallpaper share the same location and
display settings. A saved key is represented by a masked value. The app caches 12 hours of departures and lets each user choose a refresh
interval from one minute to six hours. Requests run while the app or screen saver
is active. Provider quotas and availability depend on the user's subscription.
Codeshare numbers rotate every four seconds and board pages every 15 seconds
without additional API requests. Concurrent refreshes from the app and background job
are combined into one request. Failed requests use increasing retry delays, and
quota/authentication errors pause retries for an hour (or the provider's longer
`Retry-After` interval). A replacement key clears that pause.

Enable **Use as live desktop wallpaper** to display the board behind desktop
icons on every connected screen. The app must remain running for the wallpaper
to update. Turn the option off to reveal the existing wallpaper again.

The screen saver reads local flight data without opening Keychain prompts over
the lock screen. Its **Options** button opens the companion settings editor. Keeping one editor
avoids Keychain access and preference writes from the system screen-saver sandbox. The provider and retrieval time are shown in settings.

Missing data is shown as unavailable. **Sample schedule** is for visual previews;
the four railway profiles currently use sample timetables, not live railway feeds.

## Visual profiles

Each airport has its own palette, column order, row density and reference
photograph. The default layout shows one physical panel per monitor: a long
reference wall is cropped to one panel instead of shrinking or repeating it. Haneda includes its check-in area diagram; Changi uses
highlighted gate cells; Heathrow uses its yellow header; Incheon uses blue
rows and its multilingual header. Railway renderers have their own table and column layouts. A classic
split-flap renderer is available as an alternative for airports.

The reference catalogue records the photographs used. These are reconstructed
display profiles, not airport-endorsed software or a promise that every terminal
uses the same display today.

## Build and validate

Requires Xcode command-line tools and Python 3.

```sh
./script/build_and_run.sh
./script/validate.sh
```

`build.sh` creates the `.app` and `.saver`; `validate.sh` checks the catalogue,
language bundles, provider data normalization and native screen-saver loading, then renders
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
| `Sources/SettingsStore.m` | Shared preferences and secure settings handoff |
| `Sources/DesktopController.m` | Live wallpaper windows, one per display |
| `.github/workflows/` | Validation and macOS releases |

## Credits

Its MIT-licensed city names, airline metadata and sample route lists are reused;
the original licence is included in `Resources/Data-LICENSE`. The native
macOS renderer and integrations are separate implementations. TeX Gyre Heros is
distributed under the included GUST Font License. Airline names and trademarks
belong to their respective owners.

Code: MIT.

Live destination names are resolved from cached multilingual Wikidata labels,
using provider airport codes rather than a manual city-alias table. See
[the data notes](docs/destination-names.md).
