Departure Board 0.7.4 adds a guided Windows installer and direct downloads from the product site.

- Install Windows with one Setup.exe for x64 or ARM64, without administrator access or a separate .NET installation. Update in place and remove it from Installed apps.
- Keep the previous screen saver across upgrades and restore it on removal. User settings and credentials are preserved.
- Download the latest release directly from GitHub through one OS-aware Get button; the website no longer proxies installer files.
- Share provider retry delays across airports and processes, honor `Retry-After`, and avoid continuous refresh when only the tray/menu-bar icon is active.
- Keep saved refresh settings; new installations default to five minutes. Language, page and codeshare changes reuse cached flights.
- Include English and Korean installation guides with real screenshots, every display option, wallpaper/screen saver setup and troubleshooting. Open them from the app or `Install Guide.html` in the download.
- Verify two virtual monitors at 100% + 150% and 100% + 200%, including negative screen coordinates, wallpaper, screen saver and preview DPI transitions. See the [validation record](https://github.com/Skyline-23/homebrew-departure-board/blob/main/Windows/VALIDATION.md).
- Use the [product site](https://dpboard.skyline23.com) for downloads and the illustrated guide.

macOS 12+ downloads support Apple Silicon and Intel and are Developer ID signed and notarized. Windows 11 downloads support x64 and ARM64 and remain unsigned preview builds. Physical mixed-DPI hardware and lock/unlock coverage remain separate from the virtual-monitor checks.

Live flight data requires your own AeroDataBox RapidAPI subscription and key. Sample data works without a key. The app does not estimate account quotas or add a quota-based stop.

Code and project branding use the MIT license. See [Third-party notices](https://github.com/Skyline-23/homebrew-departure-board/blob/main/THIRD_PARTY_NOTICES.md) for airline artwork.
