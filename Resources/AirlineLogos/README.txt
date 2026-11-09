Airline logos identify their respective airlines. All trademarks remain the
property of their owners; they are not covered by this project's code license.

Sources.json records the original URL for each bundled image. The collection
uses Jxck-S/airline-logos (transparent FlightAware/RadarBox marks), with direct
Google Flights and airline-published assets for additional coverage.

Catalog.json maps IATA codes to ICAO identities and names. Its base data comes
from imgmongelli/airlines-logos-dataset; Additions.json records newer identities.
AdditionalSources.json preserves separately obtained images when refreshing.

Run script/sync_airline_logos.py to refresh the pinned collection. Rendering
preserves the original aspect ratio, trims transparent margins, and removes
edge-connected white mattes without removing enclosed white artwork.
