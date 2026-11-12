Departure Board 0.7.8 adds in-app updates for macOS and Windows.

- Allow macOS updates to install and restart while the settings window is open.
- Choose automatic checks and automatic installation in the Updates settings, with the current version and last check time shown.
- Download updates in the background and install when quitting, or review release notes and choose to install, skip or defer manually.
- Check for updates from the app settings or menu. New releases are checked once a day in the background.
- Verify update files with Ed25519 signatures before installation. macOS also uses Developer ID signing and notarization.
- Download and install updates directly from GitHub Releases, then restart the app with existing settings and API keys.
- Keep the Mac screen saver aligned with the updated companion app.
- Generate and sign platform-specific update feeds automatically in the release workflow.

If you use 0.7.6 or earlier, install the latest version once from the website. Subsequent updates are available inside the app. If you already use 0.7.7 on macOS, close the settings window before choosing Install and Relaunch.

macOS 12+ supports Apple Silicon and Intel. Windows 11 supports x64 and ARM64 and remains an unsigned preview; update authenticity is verified with the app's pinned Ed25519 key.

Live flight data requires your own AeroDataBox RapidAPI subscription and key. Sample data works offline without a key.

See [Third-party notices](https://github.com/Skyline-23/homebrew-departure-board/blob/main/THIRD_PARTY_NOTICES.md) for library and artwork licenses.
