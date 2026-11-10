Departure Board now includes **macOS 12+** (Apple Silicon and Intel) and a **Windows 11 preview** (x64 and ARM64).

- Record request failures, cache updates, display-state changes and lifecycle events without logging API keys or response bodies. See [diagnostic logs](https://github.com/Skyline-23/homebrew-departure-board/blob/main/docs/diagnostics.md).
- Update visible Windows boards when a flight request completes, and leave the loading state when a background request fails.
- Show duplicate gate and check-in labels only once, while preserving distinct counters and gate ranges.
- Use the same 40 airport profiles as a live desktop wallpaper or screen saver.
- Display settings now share the same choices on both platforms: style, language, row density, brightness, reduced motion, scale and refresh interval.
- Desktop layouts leave room for the menu bar, Dock or taskbar, keeping headers, rows and footers inside the usable screen area.
- Windows rendering reuses unchanged schedules and text layouts, and split-flap boards advance through later departures.
- Windows packages include a per-user installer, the .NET runtime, a native screen saver and SHA-256 checksums.

The macOS download is Developer ID signed and notarized. Windows downloads are **unsigned preview builds** and can show an unknown-publisher warning. Physical mixed-DPI multi-monitor and lock/unlock coverage remains pending; see [Windows validation](https://github.com/Skyline-23/homebrew-departure-board/blob/main/Windows/VALIDATION.md).

For installation and personal API-key setup, see the [README](https://github.com/Skyline-23/homebrew-departure-board#install). Live flights require your own AeroDataBox subscription; sample mode is available without an API key.

The code and project branding use the MIT license. Airline artwork retains its third-party status; see [Third-party notices](https://github.com/Skyline-23/homebrew-departure-board/blob/main/THIRD_PARTY_NOTICES.md).
