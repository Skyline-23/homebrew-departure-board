#!/usr/bin/env node
import assert from 'node:assert/strict';
import { setTimeout as delay } from 'node:timers/promises';

const version = process.argv[2];
assert.match(version || '', /^\d+\.\d+\.\d+$/, 'Supply the release version.');
const origin = 'https://dpboard.skyline23.com';
const deadline = Date.now() + 10 * 60 * 1000;
let deployed = false;

while (Date.now() < deadline) {
  try {
    const response = await fetch(`${origin}/release.json?release=${version}`, {
      cache: 'no-store',
      signal: AbortSignal.timeout(15000),
    });
    if (response.ok && (await response.json()).version === version) {
      deployed = true;
      break;
    }
  } catch (error) {
    console.log(`Waiting for website deployment (${error.message}).`);
  }
  await delay(10000);
}
assert.ok(deployed, `Website did not deploy release ${version} within ten minutes.`);

for (const path of ['/index.html', '/ko.html', '/guide/ko.html', '/guide/index.html']) {
  const response = await fetch(origin + path, { signal: AbortSignal.timeout(15000) });
  assert.equal(response.status, 200, `${path} must load.`);
  assert.match(response.headers.get('content-type') || '', /text\/html/);
  if (!path.startsWith('/guide/')) {
    const html = await response.text();
    const image = html.match(/property="og:image"\s+content="([^"]+)"/);
    assert.ok(image, `${path} must declare an Open Graph image.`);
    const imageUrl = new URL(image[1]);
    assert.equal(imageUrl.origin, origin);
    const korean = path === '/ko.html';
    assert.equal(imageUrl.pathname, `/og-${korean ? 'ko' : 'en'}-v1.png`);
    assert.ok(html.includes(`property="og:locale" content="${korean ? 'ko_KR' : 'en_US'}"`));
    assert.equal(imageUrl.searchParams.get('v'), version);
    const social = await fetch(imageUrl, { signal: AbortSignal.timeout(15000) });
    assert.equal(social.status, 200, 'Open Graph image must load.');
    assert.match(social.headers.get('content-type') || '', /image\/png/);
    const png = new DataView(await social.arrayBuffer());
    assert.equal(png.getUint32(0), 0x89504e47, 'Open Graph image must be a PNG.');
    assert.equal(png.getUint32(16), 1200);
    assert.equal(png.getUint32(20), 630);
  }
}

const installers = {
  macos: 'DepartureBoard-universal.dmg',
  'windows-x64': 'DepartureBoard-win-x64-Setup.exe',
  'windows-arm64': 'DepartureBoard-win-arm64-Setup.exe',
};
for (const [platform, filename] of Object.entries(installers)) {
  const redirect = await fetch(`${origin}/download/${platform}`, {
    method: 'HEAD', redirect: 'manual', signal: AbortSignal.timeout(15000),
  });
  assert.equal(redirect.status, 302, `${platform} must redirect.`);
  const latest = `https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/${filename}`;
  assert.equal(redirect.headers.get('location'), latest);
  const release = await fetch(latest, {
    method: 'HEAD', redirect: 'manual', signal: AbortSignal.timeout(15000),
  });
  assert.equal(release.status, 302, `${filename} must resolve to a published release.`);
  const asset = release.headers.get('location');
  assert.equal(asset, `https://github.com/Skyline-23/homebrew-departure-board/releases/download/v${version}/${filename}`);
  const download = await fetch(asset, { method: 'HEAD', signal: AbortSignal.timeout(30000) });
  assert.equal(download.status, 200, `${filename} must download.`);
  assert.ok(Number(download.headers.get('content-length')) > 1000000);
  console.log(`PASS ${platform}: GitHub release ${version}, ${download.headers.get('content-length')} bytes.`);
}
console.log(`PASS website and installation guide deployed for ${version}.`);
