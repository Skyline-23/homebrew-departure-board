#!/usr/bin/env python3
"""Build the statically rendered Next.js product site and bundled guide."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():

    parser = argparse.ArgumentParser()
    parser.add_argument('--version', default=None)
    args = parser.parse_args()
    environment = os.environ.copy()
    environment['NEXT_TELEMETRY_DISABLED'] = '1'

    if args.version:
        environment['DEPARTURE_SITE_VERSION'] = args.version
    subprocess.run(['npm', 'run', 'build'], cwd=ROOT / 'site', env=environment, check=True)
    output = ROOT / 'work/site'

    if output.exists():
        shutil.rmtree(output)
    shutil.copytree(ROOT / 'site/out', output)
    print(f'Built Next.js product site: {output}')


if __name__ == '__main__':
    main()
