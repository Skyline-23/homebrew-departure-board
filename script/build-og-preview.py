#!/usr/bin/env python3
"""Prepare social cards, optionally rendering the 1200x630 PNGs in CI."""
import argparse
from pathlib import Path
import html
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--render', action='store_true')
args = parser.parse_args()
output = ROOT / 'work/og'
output.mkdir(parents=True, exist_ok=True)
shutil.copyfile(ROOT / 'site/icon.png', output / 'icon.png')
shutil.copyfile(ROOT / 'site/boards/icn.webp', output / 'board.webp')
shutil.copyfile(ROOT / 'site/flap-tile.webp', output / 'flap-tile.webp')
template = (ROOT / 'site/og-template.html').read_text()

for language, title, description in [
    ('ko', '공항 전광판을<br>배경화면으로', '40개 공항 · 배경화면과 화면 보호기'),
    ('en', 'Your airport.<br>On your desktop.', '40 airports · Wallpaper & screen saver'),
]:
    page = template.replace('{{lang}}', language).replace('{{title}}', title).replace('{{description}}', html.escape(description))
    (output / f'{language}.html').write_text(page)
    if args.render:
        browser = shutil.which('google-chrome') or shutil.which('chromium')
        if not browser:
            raise SystemExit('Install Chrome to render social cards.')
        image = ROOT / f'site/og-{language}-v1.png'
        with tempfile.TemporaryDirectory(prefix='departure-og-') as profile:
            subprocess.run([
                browser, '--headless', '--no-sandbox', '--hide-scrollbars',
                '--disable-background-networking', '--force-device-scale-factor=1',
                f'--user-data-dir={profile}', '--window-size=1200,630',
                '--virtual-time-budget=1000', f'--screenshot={image}',
                (output / f'{language}.html').as_uri(),
            ], check=True, timeout=45, capture_output=True)
        header = image.read_bytes()[:24]
        if header[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', header[16:24]) != (1200, 630):
            raise SystemExit(f'Invalid social card dimensions: {image}')
        print(f'Rendered {image.name} at 1200x630.')
print(f'Prepared social cards in {output}.')
