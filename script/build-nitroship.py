#!/usr/bin/env python3
"""Prepare only the public product site and its download server for Nitroship."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():

    subprocess.run(['python3', str(ROOT / 'script/build-site.py')], check=True)
    output = ROOT / 'work/nitroship'
    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / 'work/site', output / 'public')

    for name in ['server.mjs', 'Dockerfile', 'nitroship.json']:
        shutil.copyfile(ROOT / 'site/nitroship' / name, output / name)
    shutil.copyfile(ROOT / 'site/download-handler.mjs', output / 'download-handler.mjs')
    print(f'Prepared product-only Nitroship upload: {output}')

if __name__ == '__main__':
    main()
