import { createServer } from 'node:http';
import { createReadStream } from 'node:fs';
import { stat } from 'node:fs/promises';
import { resolve, extname, sep } from 'node:path';
import { Readable } from 'node:stream';
import downloads from './download-handler.mjs';

const root = resolve('public');
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.png': 'image/png', '.webp': 'image/webp', '.svg': 'image/svg+xml', '.xml': 'application/xml', '.txt': 'text/plain; charset=utf-8' };

async function asset(request) {
  if (!['GET', 'HEAD'].includes(request.method)) return new Response('Method not allowed', { status: 405 });
  const pathname = new URL(request.url).pathname;
  const redirect = { '/install': '/guide/index.html', '/install/ko': '/guide/ko.html' }[pathname];
  if (redirect) return new Response(null, { status: 302, headers: { Location: redirect, 'Cache-Control': 'no-store' } });
  let path;
  try { path = decodeURIComponent(pathname); }
  catch { return new Response('Bad request', { status: 400 }); }
  const file = resolve(root, '.' + path);
  if (!file.startsWith(root + sep) && file !== root) return new Response('Not found', { status: 404 });
  if (path.split('/').some(part => part.startsWith('.') || part.startsWith('_'))) return new Response('Not found', { status: 404 });
  let selected;
  let info;
  for (const candidate of (file === root ? [resolve(file, 'index.html')] : [file, file + '.html', resolve(file, 'index.html')])) {
    try {
      const metadata = await stat(candidate);
      if (metadata.isFile()) { selected = candidate; info = metadata; break; }
    } catch {}
  }
  if (!selected) return new Response('Not found', { status: 404 });
  const headers = {
    'Content-Type': types[extname(selected)] || 'application/octet-stream',
    'Content-Length': String(info.size),
    'Cache-Control': extname(selected) === '.html' ? 'public, max-age=0, must-revalidate' : 'public, max-age=86400',
    'X-Content-Type-Options': 'nosniff',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
  };
  return new Response(request.method === 'HEAD' ? null : Readable.toWeb(createReadStream(selected)), { headers });
}

const server = createServer(async (incoming, outgoing) => {
  const abort = new AbortController();
  outgoing.on('close', () => { if (!outgoing.writableEnded) abort.abort(); });
  try {
    const request = new Request('http://localhost' + incoming.url, { method: incoming.method, headers: incoming.headers, signal: abort.signal });
    const result = incoming.url === '/healthz'
      ? new Response('ok')
      : await downloads.fetch(request, { ASSETS: { fetch: asset } });
    outgoing.writeHead(result.status, Object.fromEntries(result.headers));
    if (result.body && incoming.method !== 'HEAD') {
      Readable.fromWeb(result.body).on('error', () => outgoing.destroy()).pipe(outgoing);
    } else outgoing.end();
  } catch {
    if (!outgoing.headersSent) outgoing.writeHead(503, { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' });
    outgoing.end('Temporarily unavailable');
  }
});
server.listen(Number(process.env.PORT || 3000), '0.0.0.0');
