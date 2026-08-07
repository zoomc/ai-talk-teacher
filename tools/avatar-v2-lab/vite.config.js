import fs from 'node:fs';
import path from 'node:path';
import {defineConfig} from 'vite';

const repoRoot = path.resolve(import.meta.dirname, '../..');
const avatarSource = path.join(repoRoot, 'assets/3d/avatar-v2/rocketbox-female-01.glb');

function bundledAvatar() {
  return {
    name: 'bundled-avatar',
    configureServer(server) {
      server.middlewares.use('/avatar.glb', (_req, res) => {
        if (!fs.existsSync(avatarSource)) {
          res.statusCode = 404;
          res.end('Avatar asset is not checked out');
          return;
        }
        res.setHeader('Content-Type', 'model/gltf-binary');
        fs.createReadStream(avatarSource).pipe(res);
      });
    },
    generateBundle() {
      if (!fs.existsSync(avatarSource)) return;
      this.emitFile({
        type: 'asset',
        fileName: 'avatar.glb',
        source: fs.readFileSync(avatarSource),
      });
    },
  };
}

function productionRuntime() {
  return {
    name: 'production-runtime-preview',
    configureServer(server) {
      server.middlewares.use('/production', (req, res, next) => {
        const requestPath = (req.url || '/').split('?')[0].replace(/^\/+/, '');
        const filePath = path.resolve(repoRoot, 'assets/3d', requestPath);
        if (!filePath.startsWith(path.join(repoRoot, 'assets/3d')) || !fs.existsSync(filePath)) {
          next();
          return;
        }
        const type = requestPath.endsWith('.html')
          ? 'text/html'
          : requestPath.endsWith('.js') || requestPath.endsWith('.mjs')
            ? 'application/javascript'
            : requestPath.endsWith('.glb')
              ? 'model/gltf-binary'
              : 'application/octet-stream';
        res.setHeader('Content-Type', type);
        fs.createReadStream(filePath).pipe(res);
      });
    },
  };
}

export default defineConfig({
  plugins: [bundledAvatar(), productionRuntime()],
  publicDir: path.resolve(import.meta.dirname, 'public'),
  build: {sourcemap: true},
});
