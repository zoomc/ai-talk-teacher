/**
 * Test server for E2E testing the Flutter web app.
 * Serves the build/web directory with SPA fallback (serves index.html for all routes)
 * so GoRouter's client-side routing works correctly.
 */
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const BUILD_DIR = path.resolve(__dirname, '..', 'build', 'web');
const PORT = parseInt(process.env.E2E_PORT || '8080', 10);

const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json',
  '.symbols': 'application/octet-stream',
};

const server = http.createServer((req, res) => {
  let urlPath = req.url || '/';
  // Strip query params
  const qIndex = urlPath.indexOf('?');
  if (qIndex >= 0) urlPath = urlPath.substring(0, qIndex);

  let filePath = path.join(BUILD_DIR, urlPath === '/' ? 'index.html' : urlPath);

  // Security: prevent directory traversal
  if (!filePath.startsWith(BUILD_DIR)) {
    res.writeHead(403);
    res.end('Forbidden');
    return;
  }

  // Try the exact file path; if not found, serve index.html (SPA fallback)
  if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
    filePath = path.join(BUILD_DIR, 'index.html');
  }

  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  // Set cache control - no cache for test files during development
  const isAsset = ext === '.png' || ext === '.jpg' || ext === '.wasm' || ext === '.ttf' || ext === '.otf';
  const cacheControl = isAsset ? 'max-age=86400' : 'no-cache';

  try {
    const content = fs.readFileSync(filePath);
    res.writeHead(200, {
      'Content-Type': contentType,
      'Content-Length': content.length,
      'Cache-Control': cacheControl,
    });
    res.end(content);
  } catch (err) {
    res.writeHead(500);
    res.end(`Internal Server Error: ${err.message}`);
  }
});

server.listen(PORT, () => {
  console.log(`E2E test server running at http://localhost:${PORT}`);
  console.log(`Serving: ${BUILD_DIR}`);
});

// Graceful shutdown
process.on('SIGTERM', () => server.close());
process.on('SIGINT', () => server.close());
