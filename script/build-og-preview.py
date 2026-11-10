#!/usr/bin/env python3
"""Prepare the 1200x630 social-card layouts for browser PNG export."""
from pathlib import Path
import html
import shutil

ROOT = Path(__file__).resolve().parents[1]
output = ROOT / 'work/og'
output.mkdir(parents=True, exist_ok=True)
shutil.copyfile(ROOT / 'site/icon.png', output / 'icon.png')
shutil.copyfile(ROOT / 'Resources/Guide/images/board-incheon.png', output / 'board.png')
template = (ROOT / 'site/og-template.html').read_text()

for language, title, description in [
    ('ko', '공항 전광판을<br>배경화면으로', '배경화면 · 화면 보호기'),
    ('en', 'Your airport.<br>On your desktop.', 'Wallpaper & screen saver'),
]:
    page = template.replace('{{lang}}', language).replace('{{title}}', title).replace('{{description}}', html.escape(description))
    (output / f'{language}.html').write_text(page)
print(f'Serve {output} and export each page at exactly 1200x630 pixels.')
