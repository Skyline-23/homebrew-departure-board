#!/usr/bin/env python3
"""Sign one platform's immutable GitHub release download and update feed."""
import argparse
import base64
import os
from pathlib import Path
import re
import xml.etree.ElementTree as ET

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

ROOT = Path(__file__).resolve().parents[1]
NAMESPACE = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
ET.register_namespace('sparkle', NAMESPACE)


def build_feed(version, platform, artifact, output, seed):

    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise ValueError('Expected a stable semantic version.')
    key = Ed25519PrivateKey.from_private_bytes(base64.b64decode(seed, validate=True))
    public = base64.b64decode((ROOT / 'Resources/Updates/public-key.txt').read_text().strip())

    if key.public_key().public_bytes_raw() != public:
        raise ValueError('Signing key does not match the application public key.')
    payload = artifact.read_bytes()
    signature = base64.b64encode(key.sign(payload)).decode()
    root = ET.Element('rss', {'version': '2.0'})
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'Departure Board Updates'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = f'Departure Board {version}'
    ET.SubElement(item, 'description').text = 'A new version of Departure Board is ready to install.'
    machine_version = version
    ET.SubElement(item, f'{{{NAMESPACE}}}version').text = machine_version
    ET.SubElement(item, f'{{{NAMESPACE}}}shortVersionString').text = version

    if platform == 'macos':
        ET.SubElement(item, f'{{{NAMESPACE}}}minimumSystemVersion').text = '12.0'
    attributes = {
        'url': f'https://github.com/Skyline-23/homebrew-departure-board/releases/download/v{version}/{artifact.name}',
        'length': str(len(payload)),
        'type': 'application/octet-stream',
        f'{{{NAMESPACE}}}version': machine_version,
        f'{{{NAMESPACE}}}os': 'macos' if platform == 'macos' else 'windows',
        f'{{{NAMESPACE}}}edSignature' if platform == 'macos' else f'{{{NAMESPACE}}}signature': signature,
    }
    ET.SubElement(item, 'enclosure', attributes)
    output.mkdir(parents=True, exist_ok=True)
    feed = output / f'appcast-{platform}.xml'
    data = ET.tostring(root, encoding='utf-8', xml_declaration=True)
    feed.write_bytes(data)

    if platform != 'macos':
        feed.with_suffix('.xml.signature').write_text(base64.b64encode(key.sign(data)).decode())
    return feed


def main():

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--platform', choices=['macos', 'windows-x64', 'windows-arm64'], required=True)
    parser.add_argument('--artifact', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    seed = os.environ.get('UPDATE_ED25519_PRIVATE_KEY', '').strip()

    if not seed:
        raise SystemExit('Missing UPDATE_ED25519_PRIVATE_KEY.')
    feed = build_feed(args.version, args.platform, args.artifact, args.output, seed)
    print(f'Signed {args.artifact.name}; wrote {feed.name}.')


if __name__ == '__main__':
    main()
