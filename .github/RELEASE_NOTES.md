Departure Board 0.7.7 adds in-app updates for macOS and Windows.

- Check for updates from the app settings or menu. New releases are checked once a day in the background.
- Verify update files with Ed25519 signatures before installation. macOS also uses Developer ID signing and notarization.
- Download and install updates directly from GitHub Releases, then restart the app with existing settings and API keys.
- Keep the Mac screen saver aligned with the updated companion app.
- Generate and sign platform-specific update feeds automatically in the release workflow.

If you use 0.7.6 or earlier, install 0.7.7 once from the website. Subsequent updates are available inside the app.

macOS 12+ supports Apple Silicon and Intel. Windows 11 supports x64 and ARM64 and remains an unsigned preview; update authenticity is verified with the app's pinned Ed25519 key.

Live flight data requires your own AeroDataBox RapidAPI subscription and key. Sample data works offline without a key.

See [Third-party notices](https://github.com/Skyline-23/homebrew-departure-board/blob/main/THIRD_PARTY_NOTICES.md) for library and artwork licenses.
