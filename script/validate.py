#!/usr/bin/env python3
"""Validate the catalogue and localization files before shipping a bundle."""
import json
import hashlib
import re
import struct
import zlib
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
icon = (RESOURCES / "AppIcon.icns").read_bytes()
assert icon[:4] == b"icns" and struct.unpack(">I", icon[4:8])[0] == len(icon)

codes = json.loads((RESOURCES / "LocationOrder.json").read_text())
assert len(codes) == len(set(codes)) == 44
required_airports = {"ICN", "LHR", "CDG", "NRT", "HND", "HKG", "SIN"}
assert required_airports <= set(codes)

english = (RESOURCES / "en.lproj/Localizable.strings").read_text()
english_keys = set(re.findall(r'^"([^"]+)"\s*=', english, re.M))

for source in (ROOT / "Sources").rglob("*.m"):
    referenced = re.findall(r'@"((?:settings|menu|heading|data|style|language|density|notice)\.[^"\s]+)"', source.read_text())
    missing = set(referenced) - english_keys
    assert not missing, f"Missing English strings in {source.name}: {sorted(missing)}"

for code in codes:
    location = json.loads((RESOURCES / "Locations" / f"{code}.json").read_text())
    assert location["code"] == code
    ZoneInfo(location["zone"])
    assert f'"location.{code}"' in english
    assert location["routes"]

    if location["kind"] == "airport":
        assert re.fullmatch(r"[a-z][a-z0-9-]*", location["display"]["adapter"])
        assert location["reference"]["source"]
        assert location["display"]["rowCount"] >= 8
        assert location["display"]["detailRevision"] >= 2
        assert (location["display"].get("headerLayout") or
                location["display"]["adapter"] != "profile")
        title_key = location["display"].get("titleKey", location["titleKey"])
        native_strings = (RESOURCES / f'{location["lang"]}.lproj' / "Localizable.strings").read_text()
        assert f'"{title_key}"' in native_strings, f"Untranslated native heading for {code}"
        assert set(location["columns"]) <= {"time", "expected", "airline", "flight", "destination",
                                             "terminal", "counter", "gate", "state"}
        assert location["gates"]

for language in RESOURCES.glob("*.lproj"):
    text = (language / "Localizable.strings").read_text()
    keys = re.findall(r'^"([^"]+)"\s*=', text, re.M)
    assert len(keys) == len(set(keys)), f"Duplicate localization key in {language.name}"

    for required in ("heading.departures", "column.time", "status.boarding", "data.loading",
                     "data.unavailable", "data.noDepartures", "data.configure"):
        assert required in keys, (language.name, required)

logo_folder = RESOURCES / "AirlineLogos"
logo_sources = json.loads((logo_folder / "Sources.json").read_text())
logo_catalog = json.loads((logo_folder / "Catalog.json").read_text())
excluded_logos = set(json.loads((logo_folder / "ExcludedAssets.json").read_text())["sha256"])
assert len(logo_sources) >= 1600, "The full offline logo collection is missing"

for carrier, source in logo_sources.items():
    assert re.fullmatch(r"[A-Z0-9]{2,3}", carrier)
    assert source.startswith("https://")
    data = (logo_folder / f"{carrier}.png").read_bytes()
    assert hashlib.sha256(data).hexdigest() not in excluded_logos, f"Placeholder logo: {carrier}"
    assert data.startswith(b"\x89PNG\r\n\x1a\n"), carrier
    width, height = struct.unpack(">II", data[16:24])
    assert 0 < width <= 2048 and 0 < height <= 2048, carrier
    offset = 8

    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk = data[offset + 4:offset + 8 + length]
        checksum = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])[0]
        assert zlib.crc32(chunk) & 0xffffffff == checksum, f"Corrupt logo: {carrier}"
        offset += length + 12

for iata, entries in logo_catalog.items():
    assert entries and re.fullmatch(r"[A-Z0-9]{2}", iata)
    assert all(entry["icao"] in logo_sources for entry in entries), iata
assert {"TW", "RS", "BX", "ZE", "CZ"} <= logo_catalog.keys()

print(f"Validated {len(codes)} locations, {len(list(RESOURCES.glob('*.lproj')))} language bundles "
      f"and {len(logo_sources)} airline logos.")
