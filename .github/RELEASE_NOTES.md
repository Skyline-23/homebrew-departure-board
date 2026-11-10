Departure Board 0.7.6 automates the complete release and website rollout.

- Build macOS, Windows and the website checks in parallel, then publish the complete installer set to GitHub Releases.
- Update Homebrew and deploy the product website automatically. CI verifies the deployed version, both installation guides and all three native installer downloads before completing.
- Derive Windows application and installer versions from the release tag.
- Retry temporary Apple ticket-service failures during notarization.

The refreshed native settings, illustrated offline guide, responsive product page and OS-specific downloads from 0.7.5 are included.

macOS 12+ supports Apple Silicon and Intel. Windows 11 supports x64 and ARM64 and remains an unsigned preview.

Live flight data requires your own AeroDataBox RapidAPI subscription and key. Sample data works offline without a key.

Code and project branding use the MIT license. See [Third-party notices](https://github.com/Skyline-23/homebrew-departure-board/blob/main/THIRD_PARTY_NOTICES.md) for artwork licenses.
