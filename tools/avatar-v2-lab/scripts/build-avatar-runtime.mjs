import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {build} from 'esbuild';

const labRoot = path.resolve(import.meta.dirname, '..');
const repoRoot = path.resolve(labRoot, '../..');
const avatarHtml = path.join(labRoot, 'avatar-runtime-source.html');
const output = path.join(repoRoot, 'assets/3d/avatar-v2-runtime.js');
const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'avatar-v2-runtime-'));
const entry = path.join(workDir, 'entry.js');
const html = fs.readFileSync(avatarHtml, 'utf8');
const match = html.match(/<script type="module">([\s\S]*?)<\/script>/);

if (!match) throw new Error('avatar.html must contain a module script before bundling');
const talkingHeadModule = path.join(
  labRoot,
  'node_modules/@met4citizen/talkinghead/modules/talkinghead.mjs',
);
fs.writeFileSync(
  entry,
  match[1].replace("from 'talkinghead'", `from ${JSON.stringify(talkingHeadModule)}`),
);

try {
  await build({
    entryPoints: [entry],
    bundle: true,
    format: 'esm',
    platform: 'browser',
    target: ['es2020'],
    outfile: output,
    sourcemap: false,
    minify: true,
    absWorkingDir: labRoot,
    mainFields: ['module', 'main'],
  });
  fs.copyFileSync(
    path.join(repoRoot, 'assets/3d/vendor/talkinghead/playback-worklet.js'),
    path.join(repoRoot, 'assets/3d/playback-worklet.js'),
  );
  console.log(`Built ${path.relative(repoRoot, output)}`);
} finally {
  fs.rmSync(workDir, {recursive: true, force: true});
}
