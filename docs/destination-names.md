# Destination names

Live destinations use the airport IATA code from the flight provider. They do not
use a hand-maintained city-alias table or inferred translations from English.

`DestinationStore` resolves the served city through Wikidata airport identifiers
(P238) and place served (P931), matching the provider's destination name when more
than one city is listed. Every language uses labels for that same city. It reads localized city labels and caches the complete language
set. This metadata lookup needs no additional API key and uses no AeroDataBox
units. Display ticks only read cached names.

`Resources/DestinationNames.json` is a generated cache, downloaded on 2026-11-09;
missing airports are resolved in a batch when live flight data is refreshed.
Wikidata labels are community-maintained and can differ from a terminal's
preferred abbreviation. The flight provider name is retained if no label exists.

Source: https://www.wikidata.org/wiki/Wikidata:Data_access
License: CC0-1.0.
