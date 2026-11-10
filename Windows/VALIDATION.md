# Windows validation — 2026-11-09

## Scope

The Windows 11 x64 build was compiled and exercised on an AMD Ryzen 7 9800X3D
workstation through SSH and an interactive Windows App session. The host reported
Windows 11 Pro build 26300. The test SDK was .NET 10.0.403; the self-contained
runtime was 10.0.14. Remote Desktop reported WPF rendering tier 0, so these results
are not native GPU frame latency measurements.

The baseline was `f544c9b`, with the same measurement harness added. Each case warms
fonts and logos, then advances the clock through 120 simulated seconds. Timings
include session updates and WPF drawing-command recording. A separate software
bitmap raster is recorded in the JSON; it is not included in the table below.

## Rendering measurements

| 3840 × 2160 case | Redraws, before → after | Drawing time, before → after | Allocated MiB, before → after |
| --- | ---: | ---: | ---: |
| Incheon, alternating languages | 36 → 16 | 388.6 → 84.6 ms | 50.3 → 10.8 |
| Haneda, alternating languages | 36 → 16 | 320.4 → 90.6 ms | 45.5 → 9.8 |
| JFK, English | 36 → 8 | 206.2 → 32.7 ms | 54.7 → 5.8 |
| Heathrow, split-flap | 36 → 8 | 357.3 → 46.2 ms | 201.9 → 18.9 |

Across the eight 1080p/4K cases, redraws decreased 66.7%, drawing-command time
80.0%, and managed allocations 87.1%. This is a controlled drawing workload,
not a promise of the same percentage improvement in overall desktop CPU usage.
All 80 initial airport/language images matched the baseline pixel for pixel.

Sample schedules now update on minute boundaries and retain their rows during
page changes. Live codeshare rotation retains its four-second cadence. Text
layout is reused through a per-renderer cache capped at 2,048 entries. Split-flap
boards now advance to later departures instead of repeating the first page.

## Platform checks

The shared-core suite passes 274 assertions. The native test suite checks airport rendering, native screen-saver preview
parenting and physical size, a temporary Credential Manager entry, settings,
page rotation, brightness, and cached/uncached pixel equivalence. The package
smoke test installs the extracted ZIP, exercises second-launch handoff and
close-to-tray, upgrades while a `.scr` is running, then uninstalls while a `.scr`
is running. It checks that program files are removed.

An interactive desktop check covers the newer Windows 11 layered desktop host,
physical wallpaper bounds, and virtual-desktop membership. A native child window
presents the shared renderer on the layered desktop; WPF top-level window
reparenting alone did not produce visible wallpaper on this host. Windows App
confirmed the live board behind desktop icons, page/language changes, and
Explorer's desktop context menu remaining usable. Windows App also
showed full-screen output at 6016 × 3384 with language and page changes.
The final 4012 × 2192 desktop check confirmed that the still/live board footer
fits above the taskbar. Offset-monitor geometry is covered by the native tests.

Run the reproducible checks from the repository:

```powershell
dotnet tool restore --tool-manifest Windows/.config/dotnet-tools.json
python Windows/scripts/test_format.py
python Windows/scripts/format.py --check
dotnet build Windows/DepartureBoard.slnx -c Release
dotnet run --project Windows/DepartureBoard.Core.Tests -c Release --no-build -- Resources
./Windows/scripts/Publish.ps1 -Runtime win-x64
```

Run `DepartureBoard.exe --self-test <output-directory> --desktop` in an
interactive desktop session for the optional wallpaper checks. Plain SSH
service sessions cannot verify interactive Credential Manager access.

## Release boundary

The package is an unsigned preview, not an Authenticode-signed stable release.
Physical mixed-DPI multiple displays, native GPU behavior, lock/unlock,
virtual-desktop switching, and an actual Explorer restart still need coverage.
The implementation detects missing Explorer hosts and monitor-layout changes
and retries; recovery is not a substitute for those end-to-end tests. Live API
behavior is covered by fixtures and shared-cache tests, not a paid live-provider
account. The Windows CI separately runs native x64 and ARM64 checks.

## Mixed-DPI virtual displays — 2026-11-10

The 0.7.3 candidate was tested in the Windows console session using the already
installed SudoVDA 1.10.9.289 driver. No driver restart was needed. Two virtual
monitors were extended, with the QHD display left of and above the FHD primary:

| Primary | Secondary | Secondary position | Observed native DPI |
| --- | --- | --- | --- |
| 1920 × 1080, 100% | 2560 × 1440, 150% | −2560, −360 | 96 / 144 |
| 1920 × 1080, 100% | 2560 × 1440, 200% | −2560, −360 | 96 / 192 |

In both cases, screen-saver HWNDs matched each physical pixel rectangle, WPF
scale matched native DPI, and moving the preview between displays updated its
DPI without placing it outside the display. Live and still wallpaper captures
on the secondary display showed the header and footer above its taskbar. The
header pixel matched the renderer in all six secondary captures. Existing
foreground windows covered the primary desktop, so its wallpaper visibility was
not inferred from a full-desktop capture; native bounds and its full-screen
screen-saver output were verified separately.

Wallpaper Engine was also running on the machine and could cover the Windows
still image. Its playback was temporarily stopped for these captures, then
resumed through its documented command-line interface. The still-image test
restores the previous Windows wallpaper afterward. Use one active wallpaper
manager when checking appearance.

Geometry, observed DPI and capture hashes are in
[mixed-dpi-2026-11-10.json](validation/mixed-dpi-2026-11-10.json). Reproduce from a
normal signed-in console session with:

```powershell
DepartureBoard.exe --self-test display-output --desktop --display-only
```

The display-only check creates temporary windows, captures the desktop and
applies then restores a still image. Credential and installer checks remain in
the full smoke suite. The original physical display configuration and other
wallpaper playback were restored after the test. Physical cable hot-plug,
lock/unlock, HDR/color accuracy and other GPU/monitor combinations remain
separate coverage.

## Settings refresh — 2026-11-10

The .NET 10.0.403 build completed with zero warnings and errors on Skyline23-PC. The shared-core suite passed all 311 assertions. The interactive native self-test rendered all 80 airport/language images, exercised settings and native preview embedding, and returned exit code 0.

The new settings use the built-in WPF Fluent light theme, three grouped sections and a fixed footer. The window is resizable with a 560 × 420 DIP minimum. Regular, scrolled flight-data and compact screenshots are generated by the existing native self-test. The settings were also opened through Windows App and navigated with the keyboard. The guide uses the regular and flight-data captures.

The macOS settings were reorganized using native AppKit controls and Auto Layout. The native bundle, screen saver configuration, 40 airport and 22-language validations passed locally. The saved refresh interval remains intact in both apps. All screenshots use sample schedules without provider requests.
