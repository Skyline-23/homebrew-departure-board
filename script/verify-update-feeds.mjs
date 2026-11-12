#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createPublicKey, verify } from 'node:crypto';
import { readFile } from 'node:fs/promises';

const version = process.argv[2];
assert.match(version || '', /^\d+\.\d+\.\d+$/);
const rawKey = Buffer.from((await readFile(new URL('../Resources/Updates/public-key.txt', import.meta.url), 'utf8')).trim(), 'base64');
assert.equal(rawKey.length, 32);
const key = createPublicKey({key: Buffer.concat([Buffer.from('302a300506032b6570032100', 'hex'), rawKey]), format: 'der', type: 'spki'});
const base = 'https://github.com/Skyline-23/homebrew-departure-board/releases';
const filenames = {
  macos: `DepartureBoard-${version}-update.zip`,
  'windows-x64': 'DepartureBoard-win-x64-Setup.exe',
  'windows-arm64': 'DepartureBoard-win-arm64-Setup.exe',
};

async function download(url, options = {}) {
  const response = await fetch(url, {...options, signal: AbortSignal.timeout(60000)});
  assert.equal(response.status, 200, `${url} must be available.`);
  return response;
}

for (const [platform, filename] of Object.entries(filenames)) {
  const url = `${base}/latest/download/appcast-${platform}.xml`;
  const bytes = Buffer.from(await (await download(url)).arrayBuffer());
  const xml = bytes.toString('utf8');
  if (platform === 'macos') {
    const footer = xml.match(/<!-- sparkle-signatures:\s*edSignature: ([A-Za-z0-9+/=]+)\s*length: (\d+)\s*-->\s*$/);
    assert.ok(footer, 'The macOS feed must be signed.');
    const length = Number(footer[2]);
    assert.equal(bytes.subarray(length).toString('utf8'), footer[0]);
    assert.ok(verify(null, bytes.subarray(0, length), key, Buffer.from(footer[1], 'base64')), 'Invalid macOS feed signature.');
  } else {
    const signature = await (await download(url + '.signature')).text();
    assert.ok(verify(null, bytes, key, Buffer.from(signature.trim(), 'base64')), `Invalid ${platform} feed signature.`);
  }
  assert.ok(xml.includes(`<sparkle:version>${version}</sparkle:version>`), 'Feed version must match the release.');
  const enclosure = xml.match(/<enclosure\s+([^>]+)>?/);
  assert.ok(enclosure);
  const asset = enclosure[1].match(/\burl="([^"]+)"/);
  assert.equal(asset?.[1], `${base}/download/v${version}/${filename}`);
  const size = Number(enclosure[1].match(/\blength="(\d+)"/)?.[1]);
  assert.ok(size > 1000000);
  const response = await download(asset[1], {method: 'HEAD'});
  assert.equal(Number(response.headers.get('content-length')), size);
  console.log(`PASS ${platform}: signed feed ${version}, ${size} byte update available.`);
}
