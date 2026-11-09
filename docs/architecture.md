# Airport rendering

The view owns time, language rotation, paging and settings. An airport adapter
translates an airport profile into the layout and signage used by the shared
renderers. Renderers do not fetch flights or choose airports.

```text
DBBoardView
  └─ AirportAdapterForLocation(location)
       ├─ ProfileAirportAdapter       data-driven headers and layout
       ├─ IncheonAirportAdapter       multilingual sign and footer
       └─ HanedaAirportAdapter        check-in counters and compact header
            └─ AirportTableRenderer
                 ├─ AirportCellRenderer
                 ├─ AirportHeaderRenderer
                 └─ AirportFooterRenderer
```

## Where a change belongs

| Change | File or directory |
| --- | --- |
| An airport's colors, columns, fonts or row density | `Resources/Locations/<IATA>.json` |
| A custom airport sign or diagram | `Sources/Airports/Adapters/` |
| Adapter selection and immutable render context | `Sources/Airports/AirportAdapter.*` |
| Table geometry and iteration | `Sources/Airports/AirportTableRenderer.m` |
| Flight, destination, logo and status cells | `Sources/Airports/AirportCellRenderer.m` |
| Shared profile headers and footers | `Sources/Airports/AirportHeaderRenderer.m`, `AirportFooterRenderer.m` |
| Time, language rotation, pages and view lifecycle | `Sources/BoardView.m` |
| Flight requests, normalization and caching | `Sources/LiveFlightStore.m` |
| Translated board text | `Resources/<language>.lproj/Localizable.strings` |

`AirportRenderer.m` is the small bridge from the view to the adapter. It passes
an immutable context containing the current rows, time, language and page.
The adapter is selected once when the location changes, not for every cell.

## Adding an airport

1. Add its independent JSON file to `Resources/Locations` and its code to
   `Resources/LocationOrder.json`.
2. Use `display.adapter: "profile"` when existing layout rules describe the
   airport. Each airport retains its own configuration; a separate empty class
   is unnecessary.
3. For custom signage, subclass `DBProfileAirportAdapter`, override only the
   relevant drawing or geometry methods, and register its identifier in
   `AirportAdapter.m`. Put that identifier in the airport's JSON file.
4. Add translations and a visual source reference. Run the native checks and
   compare the affected airport at desktop and portrait sizes.

Do not add IATA-code conditionals to the view, shared header or table renderer.
Adapters consume flight rows; they must not read preferences, access Keychain,
perform network requests or start timers.

## Formatting and verification

Source files use four-space indentation, explicit control-flow braces and a
100-column limit. Format Objective-C with the checked-in `.clang-format`:

```sh
./script/format.sh
./script/format.sh --check
```

`script/common-sources.sh` is the shared source manifest. Files added under
`Sources/Airports` and `Sources/Airports/Adapters` are included in both bundles
and the lifecycle tests automatically.

The native tests check that adapter routing follows the profile identifier,
including when the IATA code changes. Release installation tests use fresh
Intel and Apple Silicon runners, the published Homebrew cask and no flight API
key. They verify signatures and notarization before approving the test copy's
one-time Gatekeeper confirmation for automated UI checks.
