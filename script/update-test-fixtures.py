#!/usr/bin/env python3
"""Generate disposable signed fixtures, never using the release key."""
import base64
import importlib.util
from pathlib import Path
import sys
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('update_feed', root / 'script/build-update-feed.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
output = Path(sys.argv[1]).resolve()
output.mkdir(parents=True, exist_ok=True)
key = Ed25519PrivateKey.generate()
public = base64.b64encode(key.public_key().public_bytes_raw()).decode()
seed = base64.b64encode(key.private_bytes_raw()).decode()
(output / 'Resources/Updates').mkdir(parents=True, exist_ok=True)
(output / 'Resources/Updates/public-key.txt').write_text(public)
(output / 'test-only-private-key.txt').write_text(seed)
module.ROOT = output

for platform in ['macos', 'windows-x64', 'windows-arm64']:
    artifact = output / f'{platform}.bin'
    artifact.write_bytes(b'Disposable installer signature fixture\x00\x01')
    module.build_feed('1.2.3', platform, artifact, output, seed)
print(f'Created signed update fixtures in {output}.')
