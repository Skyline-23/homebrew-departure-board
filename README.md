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
If your Mac has an Apple Development or Developer ID signing identity, the
launcher applies that stable identity after Homebrew installation to retain
Keychain approvals across updates.

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

Click **Set as Wallpaper** in Settings to apply and register the live board automatically
behind desktop icons on every connected screen. A full-resolution still frame
is also registered with macOS once per minute and when settings change, so the
lock screen uses the same board instead of an unrelated photo. The app must
remain running for updates. Turning the option off restores the previous
system wallpaper. The current board also appears automatically in the system wallpaper chooser;
no file or folder import is needed.

The screen saver reads local flight data without opening Keychain prompts over
the lock screen. Its **Options** button opens the companion settings editor. Keeping one editor
avoids Keychain access and preference writes from the system screen-saver sandbox. The provider and retrieval time are shown in settings.

Loading, an empty departure window, missing configuration and a failed request have separate localized messages. API authentication, subscription and rate-limit errors are explained in Settings. **Sample schedule** is for visual previews;
the four railway profiles currently use sample timetables, not live railway feeds.

Closing the preview keeps Departure Board running in the menu bar and removes
its Dock icon. Use the menu bar icon to reopen the board or settings. **Quit
Departure Board** stops it for the current login session. Enable **Launch in
background at login** in Settings to start it automatically after signing in.
A local maintenance job restores the app after an unexpected exit; flight
requests still follow the configured refresh interval.

LCD boards repaint when displayed content changes. The 30 fps timer is reserved
for visible split-flap animation; covered windows and sleeping displays stop
rendering. Wallpaper snapshots render into a separate bitmap without resizing
the live desktop windows. Image generation runs in a short-lived helper, so its
buffers are released after export. Exports pause during idle time and while the
screen saver runs. The registered photo uses a stable filename per display, and
old Departure Board frame entries are removed from wallpaper photo history.

**Show on all Spaces** controls whether the live board follows you between
Spaces. It is enabled by default; turning it off keeps the board on its current
Space.

The default **Board Scale** is 75%. It reduces text and header sizes and fits more
rows on a desktop display. Settings offers 50–100%; manual row counts remain
available independently.

## Visual profiles

All 40 airports have individual headers, column layouts, row rules, status treatments and reference photographs. The default layout shows one physical panel per monitor: a long
reference wall contributes one panel, with its rows adapted to the display size. Haneda includes its check-in area diagram; Vienna has its analogue clock; Hong Kong has its blue check-in column; Changi uses
highlighted gate cells; Heathrow uses its yellow header; Incheon uses blue
rows and its multilingual header. Railway renderers have their own table and column layouts. A classic
split-flap renderer is available as an alternative for airports.

The reference catalogue records the photographs used. These are reconstructed
display profiles, not airport-endorsed software or a promise that every terminal
uses the same display today.

Airline logos are bundled for offline use and matched by ICAO, airline name and
IATA code. They retain their proportions without white tiles. The image cache
is bounded; adding carriers does not load the entire collection into memory or
consume flight API requests. `script/sync_airline_logos.py` refreshes the pinned
source collection. Original asset URLs are recorded in
`Resources/AirlineLogos/Sources.json`; airline trademarks belong to their owners.

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
| `Sources/BackgroundAgent.m` | Login startup, crash recovery and refresh scheduling |
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

Development bundles stay in `work/Build.noindex` so Spotlight does not list test
apps alongside the installed app. Release archives are written to
`outputs/DepartureBoard/dist`.

Unreported operational statuses use the localized “Status unavailable” remark.
This is distinct from a failed timetable download and is never inferred as an on-time flight.
