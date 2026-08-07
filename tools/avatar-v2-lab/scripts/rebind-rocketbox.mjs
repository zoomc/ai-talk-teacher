import fs from 'node:fs';
import {Matrix4, Quaternion, Vector3} from 'three';

const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  throw new Error('usage: node rebind-rocketbox.mjs input.glb output.glb');
}

function readGlb(filePath) {
  const bytes = fs.readFileSync(filePath);
  const jsonLength = bytes.readUInt32LE(12);
  const json = JSON.parse(bytes.toString('utf8', 20, 20 + jsonLength));
  const binHeader = 20 + jsonLength;
  const binLength = bytes.readUInt32LE(binHeader);
  const bin = bytes.subarray(binHeader + 8, binHeader + 8 + binLength);
  return {json, bin};
}

function localMatrix(node) {
  if (node.matrix) return new Matrix4().fromArray(node.matrix);
  return new Matrix4().compose(
    new Vector3(...(node.translation || [0, 0, 0])),
    new Quaternion(...(node.rotation || [0, 0, 0, 1])),
    new Vector3(...(node.scale || [1, 1, 1])),
  );
}

function writeGlb(json, bin) {
  const jsonBytes = Buffer.from(JSON.stringify(json));
  const paddedJson = Buffer.concat([jsonBytes, Buffer.alloc((4 - jsonBytes.length % 4) % 4, 0x20)]);
  const paddedBin = Buffer.concat([bin, Buffer.alloc((4 - bin.length % 4) % 4)]);
  const output = Buffer.alloc(12 + 8 + paddedJson.length + 8 + paddedBin.length);
  output.writeUInt32LE(0x46546c67, 0);
  output.writeUInt32LE(2, 4);
  output.writeUInt32LE(output.length, 8);
  let offset = 12;
  output.writeUInt32LE(paddedJson.length, offset);
  output.writeUInt32LE(0x4e4f534a, offset + 4);
  paddedJson.copy(output, offset + 8);
  offset += 8 + paddedJson.length;
  output.writeUInt32LE(paddedBin.length, offset);
  output.writeUInt32LE(0x004e4942, offset + 4);
  paddedBin.copy(output, offset + 8);
  return output;
}

const document = readGlb(inputPath);
const {json} = document;
const sceneRoots = json.scenes[json.scene ?? 0]?.nodes || [];
const rootIndex = sceneRoots.find((index) => json.nodes[index]?.name === 'Armature') ?? sceneRoots[0];
if (rootIndex === undefined) throw new Error('Armature root not found');

// TalkingHead normalizes the Armature object scale to 1. Make that same
// normalization part of the asset and compute inverse bind matrices against
// the normalized node graph, so Three.js skinning starts in the authored pose.
json.nodes[rootIndex].scale = [1, 1, 1];
const worldMatrices = new Map();
function visit(index, parent) {
  const world = new Matrix4().multiplyMatrices(parent, localMatrix(json.nodes[index]));
  worldMatrices.set(index, world);
  for (const child of json.nodes[index].children || []) visit(child, world);
}
visit(rootIndex, new Matrix4());

for (const skin of json.skins || []) {
  if (skin.inverseBindMatrices === undefined) continue;
  const accessor = json.accessors[skin.inverseBindMatrices];
  const joints = skin.joints || [];
  const inverseBytes = Buffer.alloc(joints.length * 16 * 4);
  joints.forEach((jointIndex, index) => {
    const inverse = worldMatrices.get(jointIndex)?.clone().invert();
    if (!inverse) throw new Error(`Joint node ${jointIndex} is not under Armature`);
    inverse.elements.forEach((value, elementIndex) => {
      inverseBytes.writeFloatLE(value, (index * 16 + elementIndex) * 4);
    });
  });
  const alignedOffset = (document.bin.length + 3) & ~3;
  const bufferViewIndex = json.bufferViews.length;
  json.bufferViews.push({buffer: 0, byteOffset: alignedOffset, byteLength: inverseBytes.length});
  json.accessors[skin.inverseBindMatrices] = {...accessor, bufferView: bufferViewIndex, byteOffset: 0};
  document.bin = Buffer.concat([document.bin, Buffer.alloc(alignedOffset - document.bin.length), inverseBytes]);
}

json.buffers[0].byteLength = document.bin.length;
fs.writeFileSync(outputPath, writeGlb(json, document.bin));
console.log(`Rebound ${outputPath} (${json.skins?.length || 0} skin(s))`);
