# Third-party notices

The [MIT license](LICENSE) covers Departure Board's original code and project
branding. It does not grant ownership of third-party airline trademarks or artwork.

Additional MIT terms for imported metadata are included in
[Resources/Data-LICENSE](Resources/Data-LICENSE).

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

## Phosphor Icons

The product website uses `site/arrow-right.svg` from [Phosphor Icons](https://github.com/phosphor-icons/core), under the MIT license.

```text
MIT License

Copyright (c) 2023 Phosphor Icons

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Application update frameworks

- Sparkle 2.10.1: Copyright Sparkle contributors, MIT license. The license is bundled in `Resources/ThirdParty/Sparkle-LICENSE`.
- NetSparkle 3.1.0: Copyright NetSparkle contributors, MIT license. The license is bundled in `Resources/ThirdParty/NetSparkle-LICENSE.md`. Its Ed25519 verifier uses the MIT-licensed [Chaos.NaCl](https://github.com/CodesInChaos/Chaos.NaCl) library.

Updates are distributed through GitHub Releases and verified against the app's embedded Ed25519 public key.
