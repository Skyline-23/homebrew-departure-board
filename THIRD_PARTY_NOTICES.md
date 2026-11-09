# Third-party notices

The [MIT license](LICENSE) covers Departure Board's original code and project
branding. It does not grant ownership of third-party airline trademarks or artwork.

## Airline artwork and identity data

- [Jxck-S/airline-logos](https://github.com/Jxck-S/airline-logos) supplies much of
  the artwork. Its README describes airline-identification use and retains
  ownership with the airlines and operators; it does not provide a general
  open-source license for those images.
- [imgmongelli/airlines-logos-dataset](https://github.com/imgmongelli/airlines-logos-dataset)
  supplies identity mappings. Its README declares an MIT license.
- Additional images come from the airline-published and Google Flights URLs
  recorded in [Sources.json](Resources/AirlineLogos/Sources.json). Each image
  keeps its original third-party status.

The artwork identifies airlines on flight boards. Departure Board is not
endorsed by those airlines. Review the original sources before reusing artwork;
this project's code license does not replace their permissions or terms.
For a correction or removal request, open an issue identifying the asset and its
source. The pinned collection and refresh process are documented in
[Resources/AirlineLogos/README.txt](Resources/AirlineLogos/README.txt).

## Airport references

Each airport profile records its reference URL in `Resources/Locations`.
Reference photographs are linked, not bundled. The recreated interfaces do not
imply airport endorsement or that every terminal uses the same current layout.

## Destination names

Destination translations are resolved from Wikidata's structured data, which
is published under [CC0](https://www.wikidata.org/wiki/Wikidata:Licensing).
See [destination-name notes](docs/destination-names.md) for lookup and caching.

## Project icon

The Departure Board icon was generated for this project using OpenAI image
generation. The source image is [docs/branding/logo.png](docs/branding/logo.png)
and is distributed with the project's MIT-licensed branding.
