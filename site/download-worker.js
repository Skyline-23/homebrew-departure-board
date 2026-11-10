const downloads = {
  macos: 'DepartureBoard-universal.zip',
  'windows-x64': 'DepartureBoard-win-x64.zip',
  'windows-arm64': 'DepartureBoard-win-arm64.zip',
  'windows-x64.sha256': 'DepartureBoard-win-x64.zip.sha256',
  'windows-arm64.sha256': 'DepartureBoard-win-arm64.zip.sha256',
};
const release = 'https://github.com/Skyline-23/homebrew-departure-board/releases/latest/download/';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.pathname !== '/download' && !url.pathname.startsWith('/download/')) return env.ASSETS.fetch(request);
    let platform = url.pathname.slice('/download/'.length);
    const automatic = url.pathname === '/download' || url.pathname === '/download/';
    if (automatic) {
      platform = url.searchParams.get('platform') || detectPlatform(request);
      if (!platform) return platformPicker();
    }
    if (!Object.hasOwn(downloads, platform)) return new Response('Download not found.', { status: 404 });
    const filename = downloads[platform];
    if (!['GET', 'HEAD'].includes(request.method)) {
      return new Response('Method not allowed.', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }
    if (automatic) return new Response(null, { status: 302, headers: { Location: '/download/' + platform, 'Cache-Control': 'no-store' } });
    const headers = new Headers();
    for (const name of ['Range', 'If-Range', 'If-None-Match', 'If-Modified-Since']) {
      if (request.headers.has(name)) headers.set(name, request.headers.get(name));
    }
    let upstream;
    try {
      upstream = await fetch(release + filename, {
        method: request.method,
        headers,
        redirect: 'follow',
        cf: { cacheEverything: true, cacheTtlByStatus: { '200-299': 300, '400-599': 0 } },
      });
    } catch {
      return unavailable();
    }
    if (![200, 206, 304, 416].includes(upstream.status)) return unavailable();
    const responseHeaders = new Headers({
      'Content-Type': filename.endsWith('.sha256') ? 'text/plain; charset=utf-8' : 'application/zip',
      'Content-Disposition': `attachment; filename="${filename}"`,
      'Cache-Control': 'public, max-age=300',
      'X-Content-Type-Options': 'nosniff',
    });
    for (const name of ['Content-Length', 'Content-Range', 'Accept-Ranges', 'ETag', 'Last-Modified']) {
      if (upstream.headers.has(name)) responseHeaders.set(name, upstream.headers.get(name));
    }
    return new Response(upstream.body, { status: upstream.status, headers: responseHeaders });
  },
};

function unavailable() {
  return new Response('The download is temporarily unavailable. Please try again shortly.', {
    status: 503,
    headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store', 'Retry-After': '60' },
  });
}

function detectPlatform(request) {
  const agent = request.headers.get('User-Agent') || '';
  const platform = request.headers.get('Sec-CH-UA-Platform') || '';
  if (/Android|iPhone|iPad|iPod/i.test(agent)) return null;
  if (/macOS/i.test(platform) || /Macintosh/i.test(agent)) return 'macos';
  if (/Windows/i.test(platform + agent)) {
    const arch = request.headers.get('Sec-CH-UA-Arch') || '';
    return /arm|aarch64/i.test(arch + agent) ? 'windows-arm64' : 'windows-x64';
  }
  return null;
}

function platformPicker() {
  return new Response(`<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Departure Board · Download</title><link rel="stylesheet" href="/site.css"></head><body><main><section class="hero"><h1>Departure Board</h1><p class="lead">설치할 컴퓨터를 선택하세요.<br>Choose your computer.</p><form class="download-picker" action="/download" method="get"><label for="platform">운영체제 / Operating system</label><select id="platform" name="platform"><option value="macos">macOS · Apple Silicon / Intel</option><option value="windows-x64">Windows · Intel / AMD</option><option value="windows-arm64">Windows · ARM64</option></select><button class="button" type="submit">받기 · Get</button></form></section></main></body></html>`, {
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' },
  });
}
