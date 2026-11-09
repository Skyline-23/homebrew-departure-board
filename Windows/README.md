# Departure Board for Windows — preview

Windows 11 x64 and ARM64 port. This preview shares the macOS app's 40 airport profiles,
translations, schedules and airline assets. macOS remains the stable release.

## Install a preview build

1. Download `DepartureBoard-win-x64` or `DepartureBoard-win-arm64` from a successful
   **Windows preview** GitHub Actions run. Extract the artifact, then extract the ZIP inside it.
2. Double-click **Install.cmd**. It installs for your Windows user, adds a Start menu shortcut
   and selects Departure Board as your screen saver. Administrator access is not needed.
3. Open **Departure Board** from Start. Choose an airport and use **Apply**.

The preview is not Authenticode signed. Windows may show an unknown-publisher warning.
Do not treat this as a signed stable release. The package includes the .NET runtime.

The package includes a SHA-256 checksum file next to the ZIP.

The tray icon opens settings, previews the board and quits the background app. Closing
settings keeps it in the tray. Enable **Launch in background at sign-in** to start it automatically.

## Live flights

Sample mode works without an account. For real flights, follow [API setup](https://github.com/Skyline-23/homebrew-departure-board/blob/main/docs/api-key.md),
choose **Live flight data**, enter your own AeroDataBox RapidAPI key and apply.
The key is saved in **Windows Credential Manager**. Settings and shared flight caches are in
`%LOCALAPPDATA%\DepartureBoard`. No key is bundled in the app or sent to a project proxy.
A masked saved key means it is already stored; leaving the field unchanged keeps it.

The refresh interval controls API use. Windows, previews and the screen saver share a disk
cache and a fetch lock; language, clock, page and codeshare changes do not call the API.
Provider failures retain cached flights and share a retry delay between processes.

## Screen saver and wallpaper

**Set as screen saver** selects the installed `.scr` file. Open Windows screen saver settings
to choose your idle timeout and sign-in requirement. The app supports full-screen `/s`,
preview `/p <HWND>` and settings `/c` commands.

**Set as wallpaper** saves the current board as a Windows wallpaper image.

**Live desktop wallpaper** embeds the board behind desktop icons using Explorer's WorkerW
host, including the layered desktop used by newer Windows 11 builds. The app recreates its
board windows when Explorer's host or the monitor layout changes. **Show on all desktops**
controls whether the live board follows Windows virtual desktops. This remains experimental
and does not replace the lock-screen background. Physical mixed-DPI multi-monitor and
lock/unlock coverage remains pending.

To uninstall, run `Uninstall.ps1` from the installation folder using PowerShell. It restores
the previous screen saver when Departure Board is still selected. User settings and saved
credentials are kept.

## Display options

The Windows settings match the macOS choices: automatic/LCD/split-flap display,
English/local/alternating languages, airport layout or 10/12/16 rows, brightness
35–100%, reduced motion, and board scale 50/65/75/85/100%. The data refresh choices
are 1, 5 and 15 minutes, 1 hour and 6 hours. Both apps offer sample/live data,
a personal API key, live wallpaper, a still wallpaper action, startup at sign-in,
and display on all virtual desktops/Spaces. Screen-saver and window previews use a brief fade for split-flap changes; reduced
motion disables it. Live wallpaper replaces completed frames without animation. Windows screen-saver selection is also available.

See [native validation and performance measurements](VALIDATION.md).

## Develop

Requires the .NET 10 SDK. On Windows:

```powershell
dotnet tool restore --tool-manifest Windows/.config/dotnet-tools.json
python Windows/scripts/format.py --check
dotnet run --project Windows/DepartureBoard.Core.Tests -- Resources
dotnet build Windows/DepartureBoard.slnx -c Release
./Windows/scripts/Publish.ps1 -Runtime win-x64
```

The shared-core tests and cross-compilation also run on macOS/Linux. WPF execution requires Windows.
Run `DepartureBoard.exe --self-test <output-folder> --desktop` from a logged-in
Windows desktop to also verify wallpaper parenting and virtual-desktop membership.
SSH service sessions cannot access the interactive user's Credential Manager.

CI renders each airport in English and its local language, checks native preview embedding,
and tests the extracted installer and uninstaller. It does not replace physical multi-monitor
or lock/unlock testing.

`DepartureBoard.Core` owns catalog, settings, provider, cache and flight grouping.
`DepartureBoard.Windows/Rendering` owns airport adapters and drawing.
`Platform` owns Windows credentials, screen saver, startup and desktop embedding.
`Views` owns the settings and board windows. `scripts` owns packaging and formatting.
