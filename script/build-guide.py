#!/usr/bin/env python3
"""Build the bundled, offline guide from its small documented Markdown subset."""
import argparse
import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GUIDE = ROOT / 'Resources/Guide'


def inline(value):

    value = html.escape(value, quote=True)
    value = re.sub(r'`([^`]+)`', r'<code>\1</code>', value)
    value = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', value)
    value = re.sub(r'\*([^*]+)\*', r'<em>\1</em>', value)
    return re.sub(r'\[([^]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', value)


def render(source):

    lines = source.splitlines()
    result, sections = [], []
    i = 0

    while i < len(lines):
        line = lines[i]

        if not line.strip():
            i += 1
            continue

        if line.startswith('```'):
            code = []
            i += 1

            while i < len(lines) and not lines[i].startswith('```'):
                code.append(lines[i]); i += 1
            result.append('<pre><code>' + html.escape('\n'.join(code)) + '</code></pre>')
        elif line.startswith('#'):
            match = re.match(r'(#{1,3}) (.*)', line)
            level, title = len(match[1]), match[2]
            slug = re.sub(r'[^\w-]+', '-', title.lower()).strip('-')
            result.append(f'<h{level} id="{slug}">{inline(title)}</h{level}>')

            if level == 2:
                sections.append((slug, title))
        elif re.match(r'!\[.*\]\(.*\)$', line):
            match = re.match(r'!\[(.*)\]\((.*)\)$', line)
            url = match[2].replace('../Resources/Guide/', '')
            result.append(f'<figure><img src="{html.escape(url, quote=True)}" alt="{html.escape(match[1], quote=True)}" loading="lazy"></figure>')
        elif line.startswith('|'):
            rows = []

            while i < len(lines) and lines[i].startswith('|'):
                cells = [c.strip() for c in lines[i].strip('|').split('|')]

                if not all(re.fullmatch(r':?-+:?', c) for c in cells):
                    rows.append(cells)
                i += 1
            head = '<tr>' + ''.join('<th scope="col">'+inline(c)+'</th>' for c in rows[0]) + '</tr>'
            body = ''.join('<tr>'+''.join('<td>'+inline(c)+'</td>' for c in row)+'</tr>' for row in rows[1:])
            result.append('<div class="table"><table><thead>'+head+'</thead><tbody>'+body+'</tbody></table></div>')
            continue
        elif re.match(r'(- |\d+\. )', line):
            ordered = bool(re.match(r'\d+\. ', line))
            tag = 'ol' if ordered else 'ul'
            items = []

            while i < len(lines) and re.match(r'\d+\. ' if ordered else r'- ', lines[i]):
                items.append('<li>'+inline(re.sub(r'^(?:- |\d+\. )', '', lines[i]))+'</li>'); i += 1
            start = int(re.match(r'\d+', line)[0]) if ordered else 1
            opening = f'<ol start="{start}">' if ordered else '<ul>'
            result.append(opening+''.join(items)+f'</{tag}>')
            continue
        elif line.startswith('> '):
            result.append('<aside class="note">'+inline(line[2:])+'</aside>')
        else:
            paragraph = [line]
            i += 1

            while i < len(lines) and lines[i].strip() and not re.match(r'^(#|```|\||!\[|> |\d+\. |- )', lines[i]):
                paragraph.append(lines[i]); i += 1
            result.append('<p>'+inline(' '.join(paragraph))+'</p>')
            continue
        i += 1
    return '\n'.join(result), sections


def build(language):

    korean = language == 'ko'
    body, sections = render((ROOT / ('docs/install-guide.ko.md' if korean else 'docs/install-guide.md')).read_text(encoding='utf-8'))
    navigation = ''.join(f'<a href="#{slug}">{html.escape(title)}</a>' for slug, title in sections)
    return f'''<!doctype html>
<html lang="{language}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Departure Board — {'설치와 사용 설명서' if korean else 'Installation and user guide'}</title>
<link rel="stylesheet" href="guide.css"></head><body>
<header><a class="brand" href="#">DEPARTURE BOARD</a><nav aria-label="Language"><a href="index.html" lang="en">English</a><a href="ko.html" lang="ko">한국어</a></nav></header>
<div class="layout"><nav class="contents" aria-label="{'목차' if korean else 'Contents'}"><span>{'목차' if korean else 'CONTENTS'}</span>{navigation}</nav>
<main>{body}</main></div><footer>{'이 설명서와 사진은 앱에 포함되어 인터넷 없이도 열립니다.' if korean else 'This guide and its images are bundled with the app and work offline.'}</footer></body></html>
'''


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()

    for language, name in [('en', 'index.html'), ('ko', 'ko.html')]:
        path = GUIDE / name
        value = build(language)

        if args.check:
            if not path.exists() or path.read_text(encoding='utf-8') != value:
                raise SystemExit(f'{path.relative_to(ROOT)} is stale; run python3 script/build-guide.py')
        else:
            path.write_text(value, encoding='utf-8')
    print('Bundled installation guides are current.')


if __name__ == '__main__':
    main()
