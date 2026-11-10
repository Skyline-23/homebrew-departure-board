#!/usr/bin/env python3
"""Fail on broken local guide assets, links and anchors before packaging."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1] / 'Resources'

class Page(HTMLParser):
    def __init__(self):

        super().__init__()
        self.links, self.ids = [], set()
    def handle_starttag(self, tag, attributes):

        values = dict(attributes)

        if 'id' in values:
            self.ids.add(values['id'])

        for key in ('src', 'href'):
            if key in values:
                self.links.append(values[key])

for path in [*(ROOT / 'Guide').glob('*.html'), ROOT / 'Install Guide.html']:
    page = Page()
    page.feed(path.read_text(encoding='utf-8'))

    for link in page.links:
        url = urlsplit(link)

        if url.scheme or url.netloc:
            continue
        target = (path.parent / unquote(url.path)).resolve() if url.path else path

        if not target.is_file():
            raise SystemExit(f'{path.name}: missing {link}')

        if url.fragment:
            other = page

            if target != path:
                other = Page()
                other.feed(target.read_text(encoding='utf-8'))

            if unquote(url.fragment) not in other.ids:
                raise SystemExit(f'{path.name}: broken anchor {link}')
print('Offline guide links, anchors and images passed.')
