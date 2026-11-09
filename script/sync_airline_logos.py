#!/usr/bin/env python3
"""Refresh the bundled, offline airline logo catalogue from pinned sources."""
import io
import hashlib
import json
from pathlib import Path
import re
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DESTINATION = ROOT / "Resources" / "AirlineLogos"
LOGO_REVISION = "e0b218991caef4832e0db911136173e8eead942a"
CATALOG_REVISION = "7b001fb8d5d0a2f875d57b2b5a8a8056b2fbc63a"
LOGO_REPOSITORY = "https://raw.githubusercontent.com/Jxck-S/airline-logos"
CATALOG_URL = ("https://raw.githubusercontent.com/imgmongelli/airlines-logos-dataset/"
               f"{CATALOG_REVISION}/airlines.json")


def download(url):

    request = urllib.request.Request(url, headers={"User-Agent": "DepartureBoard-asset-sync"})
    with urllib.request.urlopen(request, timeout=90) as response:
        return response.read()


def main():

    excluded = set(json.loads((DESTINATION / "ExcludedAssets.json").read_text())["sha256"])
    # The archive avoids thousands of individual network requests. Builds never
    # run this script; the reviewed assets are committed and available offline.
    archive_url = f"https://codeload.github.com/Jxck-S/airline-logos/tar.gz/{LOGO_REVISION}"
    cache = ROOT / "work" / "logo-sources" / f"{LOGO_REVISION}.tar.gz"
    cache.parent.mkdir(parents=True, exist_ok=True)

    if not cache.exists():
        cache.write_bytes(download(archive_url))
    with tarfile.open(fileobj=io.BytesIO(cache.read_bytes())) as archive:
        files = {"/".join(member.name.split("/")[1:]): member

                 for member in archive.getmembers() if member.isfile()}
        codes = {Path(path).stem for path in files

                 if path.split("/")[0] in ("flightaware_logos", "radarbox_logos", "custom_logos")
                 and re.fullmatch(r"[A-Z0-9]{3}", Path(path).stem)}
        sources = {}
        DESTINATION.mkdir(parents=True, exist_ok=True)

        for code in sorted(codes):

            for folder in ("custom_logos", "flightaware_logos", "radarbox_logos"):
                path = f"{folder}/{code}.png"

                if path not in files:
                    continue
                data = archive.extractfile(files[path]).read()

                if (not data.startswith(b"\x89PNG\r\n\x1a\n") or
                        hashlib.sha256(data).hexdigest() in excluded):
                    continue
                (DESTINATION / f"{code}.png").write_bytes(data)
                sources[code] = f"{LOGO_REPOSITORY}/{LOGO_REVISION}/{path}"
                break
    entries = json.loads(download(CATALOG_URL))["data"]
    catalog = {}

    for entry in entries:
        iata, icao = entry.get("iata_code"), entry.get("icao_code")

        if not iata or icao not in sources:
            continue
        record = {"icao": icao, "name": entry["name"]}

        if record not in catalog.setdefault(iata, []):
            catalog[iata].append(record)
    # Retain the existing IATA assets as a fallback for carriers without an ICAO
    # match. ICAO + airline name disambiguate reused IATA codes when available.
    additions = json.loads((DESTINATION / "AdditionalSources.json").read_text())

    for code, url in additions.items():
        target = DESTINATION / f"{code}.png"
        data = target.read_bytes() if target.exists() else download(url)

        if hashlib.sha256(data).hexdigest() in excluded:
            continue

        if not target.exists():
            target.write_bytes(data)
        sources[code] = url
    identities = json.loads((DESTINATION / "Additions.json").read_text())

    for iata, records in identities.items():
        catalog.setdefault(iata, []).extend(records)
    (DESTINATION / "Sources.json").write_text(json.dumps(sources, indent=2, sort_keys=True) + "\n")
    (DESTINATION / "Catalog.json").write_text(json.dumps(catalog, indent=2, sort_keys=True) + "\n")
    print(f"Bundled {len(sources)} logos, covering {len(catalog)} IATA codes.")


if __name__ == "__main__":
    main()
