# Diagnostic logs

The app records state changes and request boundaries, rather than every animation frame.
The event sequence separates data fetching from display updates:

- `flight.request_started` / `flight.request_finished`: airport, response count and duration.
- `flight.request_failed`: HTTP status or a bounded failure category.
- `flight.retry_scheduled` / `flight.refresh_skipped`: retry delay or cache/lock reason.
- `flight.cache_loaded`: a changed cache became visible to the process.
- `board.state_changed` (macOS) / `view.frame_presented` and `wallpaper.frame_presented`
  (Windows): loading, ready, empty or unavailable state reached the view.
- App, screen-saver and wallpaper lifecycle events identify starts and stops.

API keys, authorization headers, complete request URLs, response bodies and exception
messages are not included. Airport codes and aggregate row counts are included.

## macOS

Use Console.app or capture unified logs from Terminal:

```sh
log stream --style compact --predicate 'subsystem BEGINSWITH "com.skyline23.departureboard"'
```

To read recent events:

```sh
log show --last 30m --style compact --predicate 'subsystem BEGINSWITH "com.skyline23.departureboard"'
```

Categories include `data`, `board`, `app`, `credentials` and `saver`. The screen-saver
host recovery also records `Host frames paused` and `Host animation callbacks resumed`.
These transitions use the default log level so recent evidence is available after the event.
macOS manages unified-log retention.

## Windows

Logs are stored in:

```text
%LOCALAPPDATA%\DepartureBoard\Logs\departure-board.log
```

Each line is JSON containing a UTC timestamp, process ID, app version and event fields.
The file rotates at 1 MiB and keeps two older files (`.1` and `.2`). Repeated cache/lock
skip messages and cache-read failures are limited to once per reason and airport every five minutes. A short
cross-process file lock avoids interleaved records; logging failures do not stop the app.

```powershell
Get-Content "$env:LOCALAPPDATA\DepartureBoard\Logs\departure-board.log" -Wait
```

Keep all three files when reporting an intermittent issue. A request can complete in
one process while a screen-saver or wallpaper process reads the shared cache.

Windows uses its own dispatcher timers, so it does not depend on macOS's
`animateOneFrame` callbacks. Data-completion events also refresh visible Windows views
immediately; hidden views resume through their normal visibility handling.
