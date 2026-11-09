#!/usr/bin/env python3
"""Run the pinned C# formatter, then apply the project's deliberate blank-line rules."""

import argparse
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CONTROL = re.compile(r"^\s*(?:if|for|foreach|while|switch|try|lock)\b")
METHOD = re.compile(r"^(?:(?:public|private|protected|internal|static|async|override|sealed)\s+)*"
                    r"[\w<>?\[\],]+\s+\w+\s*\(")


def spacing(source):
    lines = source.splitlines()
    result = []

    for index, line in enumerate(lines):
        stripped = line.strip()

        if CONTROL.match(line) and result and result[-1].strip() not in ("", "{", ":"):
            result.append("")

        result.append(line)

        if stripped != "{":
            continue

        header = []

        for previous in reversed(lines[:index]):
            if previous.strip() in ("{", "}") or previous.rstrip().endswith(";"):
                break
            header.insert(0, previous.strip())

        signature = " ".join(header).strip()

        is_type = re.search(r"\b(class|record|struct|interface)\b", signature)

        if METHOD.match(signature) and not is_type and ")" in signature and "=>" not in signature:
            if index + 1 < len(lines) and lines[index + 1].strip():
                result.append("")

    return "\n".join(result).rstrip() + "\n"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    sources = sorted(path for path in ROOT.rglob("*.cs")
                     if not {"bin", "obj"}.intersection(path.parts))
    changed = []

    with tempfile.TemporaryDirectory(prefix="departure-board-format-") as temporary:
        target = Path(temporary)
        shutil.copy(ROOT / ".csharpierrc.json", target)

        for source in sources:
            copy = target / source.relative_to(ROOT)
            copy.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(source, copy)

        subprocess.run(["dotnet", "tool", "run", "csharpier", "--", "format", str(target)],
                       cwd=ROOT, check=True)

        for source in sources:
            formatted = spacing((target / source.relative_to(ROOT)).read_text())

            if formatted != source.read_text():
                changed.append(str(source.relative_to(ROOT)))

                if not arguments.check:
                    source.write_text(formatted)

    if arguments.check and changed:
        print("Run python Windows/scripts/format.py to format these files:")
        print("\n".join(changed))
        raise SystemExit(1)

    print(f"Checked {len(sources)} C# files; {len(changed)} changed.")


if __name__ == "__main__":
    main()
