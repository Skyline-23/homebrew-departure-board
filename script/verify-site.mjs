#!/usr/bin/env node
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { setTimeout as delay } from 'node:timers/promises';
import { isDeepStrictEqual } from 'node:util';

const version = process.argv[2];
assert.match(version || '', /^\d+\.\d+\.\d+$/, 'Supply the release version.');
const origin = 'https://dpboard.skyline23.com';
const imageFolder = new URL('../Resources/Guide/images/', import.meta.url);
const expectedImages = {};
const imageDimensions = {};
for (const filename of (await readdir(imageFolder)).filter(name => name.endsWith('.png')).sort()) {
  const bytes = await readFile(new URL(filename, imageFolder));
  expectedImages[filename] = createHash('sha256').update(bytes).digest('hex').slice(0, 12);
  imageDimensions[filename] = [bytes.readUInt32BE(16), bytes.readUInt32BE(20)];
}
const deadline = Date.now() + 10 * 60 * 1000;
let deployed = false;

while (Date.now() < deadline) {
  try {
    const response = await fetch(`${origin}/release.json?release=${version}`, {
      cache: 'no-store',
      signal: AbortSignal.timeout(15000),
    });
    if (response.ok) {
      const manifest = await response.json();
      if (manifest.version === version && isDeepStrictEqual(manifest.images, expectedImages)) {
        deployed = true;
        break;
      }
    }
  } catch (error) {
    console.log(`Waiting for website deployment (${error.message}).`);
  }
  await delay(10000);
}
assert.ok(deployed, `Website did not deploy release ${version} within ten minutes.`);

const checkedImages = new Set();
for (const path of ['/index.html', '/ko.html', '/guide/ko.html', '/guide/index.html']) {
  const response = await fetch(origin + path, { signal: AbortSignal.timeout(15000) });
  assert.equal(response.status, 200, `${path} must load.`);
  assert.match(response.headers.get('content-type') || '', /text\/html/);
  const html = await response.text();
  const pageImages = new Set();
  for (const match of html.matchAll(/<img\b[^>]*\bsrc="(images\/([^"?]+))"/g)) {
    const filename = match[2].match(/^(.+)\.([a-f0-9]{12})(\.png)$/);
    assert.ok(filename, `${path} must use a content-versioned image URL.`);
    const original = filename[1] + filename[3];
    assert.equal(filename[2], expectedImages[original], `${original} must match the current screenshot.`);
    pageImages.add(original);
    const imageUrl = new URL(match[1], origin + path).href;
    if (!checkedImages.has(imageUrl)) {
      const image = await fetch(imageUrl, { signal: AbortSignal.timeout(15000) });
      assert.equal(image.status, 200, `${imageUrl} must load.`);
      const png = new DataView(await image.arrayBuffer());
      assert.equal(png.getUint32(0), 0x89504e47);
      assert.deepEqual([png.getUint32(16), png.getUint32(20)], imageDimensions[original]);
      checkedImages.add(imageUrl);
    }
  }
  const requiredImages = path.startsWith('/guide/')
    ? Object.keys(expectedImages)
    : ['macos-settings.png', 'windows-settings.png'];
  for (const filename of requiredImages)
    assert.ok(pageImages.has(filename), `${path} must show the current ${filename}.`);
  if (!path.startsWith('/guide/')) {
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
console.log(`PASS ${checkedImages.size} current screenshots use content-versioned URLs.`);

const installers = {
  macos: 'DepartureBoard-universal.dmg',
  'windows-x64': 'DepartureBoard-win-x64-Setup.exe',
  'windows-arm64': 'DepartureBoard-win-arm64-Setup.exe',
};

async function fetchDownload(url, options) {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const response = await fetch(url, options);
    if (![502, 503, 504].includes(response.status) || attempt === 3) return response;
    await response.body?.cancel();
    await delay(2000 * (attempt + 1));
  }
}

for (const [platform, filename] of Object.entries(installers)) {
  const redirect = await fetchDownload(`${origin}/download/${platform}`, {
    method: 'HEAD', redirect: 'manual', signal: AbortSignal.timeout(15000),
  });
  assert.equal(redirect.status, 302, `${platform} must redirect.`);
  const latest = `https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/${filename}`;
  assert.equal(redirect.headers.get('location'), latest);
  const release = await fetchDownload(latest, {
    method: 'HEAD', redirect: 'manual', signal: AbortSignal.timeout(15000),
  });
  assert.equal(release.status, 302, `${filename} must resolve to a published release.`);
  const asset = release.headers.get('location');
  assert.equal(asset, `https://github.com/Skyline-23/homebrew-departure-board/releases/download/v${version}/${filename}`);
  const download = await fetchDownload(asset, { method: 'HEAD', signal: AbortSignal.timeout(30000) });
  assert.equal(download.status, 200, `${filename} must download.`);
  assert.ok(Number(download.headers.get('content-length')) > 1000000);
  console.log(`PASS ${platform}: GitHub release ${version}, ${download.headers.get('content-length')} bytes.`);
}
console.log(`PASS website and installation guide deployed for ${version}.`);
