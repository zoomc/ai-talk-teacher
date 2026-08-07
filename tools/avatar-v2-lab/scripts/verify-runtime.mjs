import fs from 'node:fs';
import path from 'node:path';

const labRoot = path.resolve(import.meta.dirname, '..');
const repoRoot = path.resolve(labRoot, '../..');
const source = fs.readFileSync(
  path.join(labRoot, 'avatar-runtime-source.html'),
  'utf8',
);
const bundlePath = path.join(repoRoot, 'assets/3d/avatar-v2-runtime.js');
const bundle = fs.readFileSync(bundlePath, 'utf8');

const requiredSource = [
  'avatar:speakAudio',
  'avatar:stopSpeechAudio',
  'HeadAudio',
  "case 'idle':",
  "bone:'Ponytail1'",
  'head.dispose()',
];
const requiredBundle = [
  'avatar:speakAudio',
  'avatar:stopSpeechAudio',
  'AudioWorkletNode',
  'Ponytail1',
];
const requiredAssets = [
  'assets/3d/avatar-v2/mpfb.glb',
  'assets/3d/vendor/headaudio/headworklet.mjs',
  'assets/3d/vendor/headaudio/model-en-mixed.bin',
];

for (const marker of requiredSource) {
  if (!source.includes(marker)) throw new Error(`Source marker missing: ${marker}`);
}
for (const marker of requiredBundle) {
  if (!bundle.includes(marker)) throw new Error(`Bundle marker missing: ${marker}`);
}
for (const relativePath of requiredAssets) {
  if (!fs.existsSync(path.join(repoRoot, relativePath))) {
    throw new Error(`Runtime asset missing: ${relativePath}`);
  }
}

console.log('Avatar V2 runtime verification passed');
