# Application screenshots

These images were exported from Departure Board 0.6.0 on November 9, 2026 using
the app's own screenshot command, English display mode and cached flight data.
They show the same native board renderer used by the app, wallpaper and screen
saver. Flight data is supplied by [AeroDataBox](https://aerodatabox.com/).

| File | Profile |
| --- | --- |
| `haneda-english.png` | Haneda (HND), used as the README's main image |
| `heathrow-english.png` | Heathrow (LHR) |
| `incheon-english.png` | Incheon (ICN), with its original multilingual header |

To export a new image without opening a preview window:

```sh
"/Applications/Departure Board.app/Contents/MacOS/DepartureBoard" \
  --snapshot "$PWD/haneda-english.png" \
  --location HND --language english --live-data
```

This reads the locally cached schedule. Omit `--live-data` to use the built-in
sample timetable instead. Retain the provider attribution when publishing an
image made from provider flight data.
