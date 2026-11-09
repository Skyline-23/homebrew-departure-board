#!/usr/bin/env python3
"""Check blank lines after function and control-flow block openings."""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATTERNS = {
    ".m": [
        r"(?m)^[+-] \([^)]*\)[^;{}]*\{[ \t]*\n",
        r"(?m)^(?:static\s+)?[A-Za-z_][\w<> *]*\s+\**[A-Za-z_]\w*\([^;{}]*\)\s*\{[ \t]*\n",
        r"(?m)^[ \t]*(?:}\s*)?(?:if|else|for|while|switch|@synchronized|@autoreleasepool)\b[^{}]*\{[ \t]*\n",
    ],
    ".swift": [
        r"(?m)^[ \t]*(?:(?:private|fileprivate|public|internal|static|class|mutating|override|final)\s+)*func\b[^{}]*\{[ \t]*\n",
        r"(?m)^[ \t]*(?:}\s*)?(?:if|else|guard|for|while|switch|do|catch|defer)\b[^{}]*\{[ \t]*\n",
    ],
    ".sh": [r"(?m)^[A-Za-z_]\w*\(\)\s*\{[ \t]*\n"],
    ".py": [r"(?m)^[ \t]*(?:async )?def \w+\([^)]*\)[^:\n]*:[ \t]*\n"],
}


def missing_lines(path, text):

    positions = set()
    for pattern in PATTERNS.get(path.suffix, []):
        for match in re.finditer(pattern, text):
            if not re.match(r"[ \t]*\n", text[match.end():]):
                positions.add(match.end())
    return sorted(positions)


def main():

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fix", action="store_true")
    arguments = parser.parse_args()
    failures = 0

    for folder in ("Sources", "Tests", "script"):
        for path in sorted((ROOT / folder).rglob("*")):
            if path.suffix not in PATTERNS or not path.is_file():
                continue
            text = path.read_text()
            positions = missing_lines(path, text)
            if not positions:
                continue
            if arguments.fix:
                for position in reversed(positions):
                    text = text[:position] + "\n" + text[position:]
                path.write_text(text)
            else:
                for position in positions:
                    line = text.count("\n", 0, position)
                    print(f"{path.relative_to(ROOT)}:{line}: missing block opening blank line")
                failures += len(positions)

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
