#!/usr/bin/env python3
"""Validate the catalogue and localization files before shipping a bundle."""
import json
import re
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
RESOURCES = ROOT / "Resources"
codes = json.loads((RESOURCES / "LocationOrder.json").read_text())
assert len(codes) == len(set(codes)) == 44
required_airports = {"ICN", "LHR", "CDG", "NRT", "HND", "HKG", "SIN"}
assert required_airports <= set(codes)

english = (RESOURCES / "en.lproj/Localizable.strings").read_text()
english_keys = set(re.findall(r'^"([^"]+)"\s*=', english, re.M))
for source in (ROOT / "Sources").glob("*.m"):
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
        assert location["reference"]["source"]
        assert location["display"]["panelCount"] >= 1
        assert location["display"]["rowCount"] >= 8
        assert location["gates"]

for language in RESOURCES.glob("*.lproj"):
    text = (language / "Localizable.strings").read_text()
    keys = re.findall(r'^"([^"]+)"\s*=', text, re.M)
    assert len(keys) == len(set(keys)), f"Duplicate localization key in {language.name}"
    for required in ("heading.departures", "column.time", "status.boarding"):
        assert required in keys, (language.name, required)

print(f"Validated {len(codes)} locations and {len(list(RESOURCES.glob('*.lproj')))} language bundles.")
