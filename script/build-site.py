#!/usr/bin/env python3
"""Build the public product pages without runtime API calls or dependencies."""
import argparse
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('--version', default=None)
    args = parser.parse_args()
    version = args.version or re.search(r'version "([^"]+)"', (ROOT / 'Casks/departure-board.rb').read_text())[1]

    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('Expected a release version such as 0.7.3')
    subprocess.run(['python3', str(ROOT / 'script/build-guide.py'), '--check'], check=True)
    output = ROOT / 'work/site'

    if output.exists():
        shutil.rmtree(output)
    output.mkdir(parents=True, exist_ok=True)

    for name in ['index.html', 'ko.html', 'site.css', 'icon.png', 'download.js', 'og-ko-v1.png', 'og-en-v1.png', 'hero.css', 'airport-demo.js', 'airport-data.js', 'board-transition.js', 'flap-tile.webp', 'arrow-right.svg']:
        shutil.copyfile(ROOT / 'site' / name, output / name)
    shutil.copytree(ROOT / 'site/boards', output / 'boards')
    shutil.copytree(ROOT / 'Resources/Guide', output / 'guide', dirs_exist_ok=True)
    shutil.copytree(ROOT / 'Resources/Guide/images', output / 'images', dirs_exist_ok=True)
    (output / 'robots.txt').write_text('User-agent: *\nAllow: /\nSitemap: https://dpboard.skyline23.com/sitemap.xml\n')
    (output / 'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join(f'<url><loc>https://dpboard.skyline23.com/{path}</loc></url>' for path in ['', 'ko.html', 'guide/index.html', 'guide/ko.html'])+'</urlset>')
    print(f'Built product site for {version}: {output}')

if __name__ == '__main__':
    main()
