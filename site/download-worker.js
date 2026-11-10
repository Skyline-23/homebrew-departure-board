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
    if (!url.pathname.startsWith('/download/')) return env.ASSETS.fetch(request);
    const platform = url.pathname.slice('/download/'.length);
    if (!Object.hasOwn(downloads, platform)) return new Response('Download not found.', { status: 404 });
    const filename = downloads[platform];
    if (!['GET', 'HEAD'].includes(request.method)) {
      return new Response('Method not allowed.', { status: 405, headers: { Allow: 'GET, HEAD' } });
    }
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
