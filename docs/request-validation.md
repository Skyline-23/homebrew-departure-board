# Request behavior validation — 2026-11-10

The tests use in-process HTTP fixtures. They do not consume AeroDataBox requests and do not establish current live-provider coverage or account quota availability.

| Case | macOS | Windows |
| --- | --- | --- |
| Sequentially refresh all 40 airports after HTTP 429 | 1 request | 1 request |
| Same sequence after HTTP 403 | 1 request | 1 request |
| Same sequence after HTTP 503 | 1 request | 1 request |
| Replace the failed credential and request twice | 1 new request, then cache | 1 new request, then cache |
| Respect a two-hour Retry-After | Passed | Passed |
| HTTP-date Retry-After | Parsed by implementation | Fixture passed |
| Concurrent consumers | Shared non-blocking file lock | Shared non-blocking file lock |

Run the native fixtures with `script/validate.sh`, and Windows fixtures with `dotnet run --project Windows/DepartureBoard.Core.Tests -- Resources`. The latter completed 311 assertions. Universal macOS build and bundle validation passed.

The provider-wide lock serializes cache refresh attempts from the app, screen saver and background helper. Retry metadata is scoped to a SHA-256 credential fingerprint and contains no API key. Successful fetches clear failed retry state. New installs default to a five-minute refresh interval; saved interval choices are preserved. Rendering, language changes, page transitions and codeshare rotation reuse cached flights.

A resident tray/menu-bar app only initiates periodic refresh while a preview, settings window or live wallpaper is active. Normal retry scheduling follows provider errors and `Retry-After`; it is not a client quota budget. No account request limit, remaining-quota estimate, billing-cycle setting or quota-based shutdown was added.
