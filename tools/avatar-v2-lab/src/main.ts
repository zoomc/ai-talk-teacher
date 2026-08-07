import {TalkingHead} from '@met4citizen/talkinghead';
import {HeadAudio} from '@met4citizen/headaudio/modules/headaudio.mjs';
import './style.css';

type Phase = 'idle' | 'listening' | 'thinking' | 'speaking';
type Emotion = 'neutral' | 'warm' | 'happy' | 'encouraging' | 'curious' | 'thinking' | 'surprised' | 'serious';

const avatarNode = document.querySelector<HTMLDivElement>('#avatar')!;
const statusNode = document.querySelector<HTMLSpanElement>('#runtime-status')!;
const statusDot = document.querySelector<HTMLSpanElement>('.status-dot')!;
const stateNode = document.querySelector<HTMLElement>('#caption-state')!;
const emotionNode = document.querySelector<HTMLElement>('#caption-emotion')!;
const fpsNode = document.querySelector<HTMLElement>('#fps')!;
const audioNode = document.querySelector<HTMLElement>('#audio-state')!;
const speechInput = document.querySelector<HTMLTextAreaElement>('#speech-text')!;
const deviceDpr = Math.max(window.devicePixelRatio || 1, 1);
const targetDpr = Math.min(deviceDpr, window.innerWidth < 600 ? 1.25 : 1.5);

const head = new TalkingHead(avatarNode, {
  cameraView: 'upper',
  cameraDistance: 0.05,
  cameraRotateEnable: false,
  cameraZoomEnable: false,
  // TalkingHead multiplies this by the browser DPR internally.
  modelPixelRatio: targetDpr / deviceDpr,
  modelFPS: 60,
  avatarMood: 'neutral',
  avatarIdleEyeContact: 0.38,
  avatarSpeakingEyeContact: 0.72,
  avatarListeningEyeContact: 0.82,
  avatarSpeakingHeadMove: 0.32,
  // The lab uses HeadAudio for audio-driven visemes, so no language module
  // should be fetched or silently become the primary lip-sync clock.
  lipsyncModules: [],
  lightAmbientColor: 0xeef3ff,
  lightAmbientIntensity: 1.0,
  lightDirectColor: 0xfff7ed,
  lightDirectIntensity: 12,
  lightDirectPhi: 0.9,
  lightDirectTheta: 2.1,
  lightSpotColor: 0x94b8ff,
  lightSpotIntensity: 3.5,
  lightSpotPhi: 0.9,
  lightSpotTheta: 3.4,
  lightSpotDispersion: 1.8,
}) as TalkingHead & {
  start(): void;
  stop(): void;
  lookAt(x: number, y: number, duration?: number): void;
  objectLeftEye: any;
  avatarHeight: number;
};

let phase: Phase = 'idle';
let emotion: Emotion = 'neutral';
let headaudio: HeadAudio | null = null;
let audioContext: AudioContext | null = null;
let speechSource: AudioBufferSourceNode | null = null;
let speechGain: GainNode | null = null;
let gestureTimer: number | null = null;
let lastGestureAt = 0;
let frameCount = 0;
let fpsStarted = performance.now();

const moodMap: Record<Emotion, string> = {
  neutral: 'neutral', warm: 'love', happy: 'happy', encouraging: 'happy',
  curious: 'neutral', thinking: 'neutral', surprised: 'fear', serious: 'angry',
};

function setStatus(text: string, ready = false) {
  statusNode.textContent = text;
  statusDot.classList.toggle('ready', ready);
}

function finishMaterials() {
  // Keep the MIT Rocketbox asset local while giving its PBR materials a
  // cinematic studio response. No rig or morph target is modified here.
  const runtimeHead = head as TalkingHead & {
    armature?: {scale: any; rotation: any; position: any; updateMatrixWorld(force?: boolean): void; traverse(callback: (object: any) => void): void};
  };
  runtimeHead.armature?.rotation.set(0, 0, Math.PI / 2);
  head.stop();
  runtimeHead.armature?.updateMatrixWorld(true);
  runtimeHead.armature?.traverse((object: any) => {
    const mesh = object;
    if (!mesh.isMesh || !mesh.material) return;
    if (mesh.isSkinnedMesh) {
      mesh.bindMatrix.identity();
      mesh.bindMatrixInverse.identity();
      mesh.skeleton.calculateInverses();
    }
    const materials = Array.isArray(mesh.material) ? mesh.material : [mesh.material];
    materials.forEach((material: any) => {
      const name = String(material.name || '').toLowerCase();
      material.envMapIntensity = 0.72;
      material.metalness = Math.min(Number(material.metalness) || 0, 0.08);
      material.roughness = Math.max(Number(material.roughness) || 0.48, 0.42);
      if (name.includes('head') || name.includes('body') || name.includes('skin')) {
        material.roughness = 0.5;
      }
    });
  });
  const eyePoint = head.objectLeftEye.getWorldPosition(head.objectLeftEye.position.clone());
  head.avatarHeight = eyePoint.y + 0.2;
  head.setView('upper', {cameraX: 0.2, cameraY: 0.8, cameraDistance: 6});
  head.start();
}

function setPhase(next: Phase) {
  phase = next;
  stateNode.textContent = next[0].toUpperCase() + next.slice(1);
  document.querySelectorAll<HTMLButtonElement>('[data-phase]').forEach((button) => {
    button.classList.toggle('active', button.dataset.phase === next);
  });
  if (next === 'listening') head.startListening?.(head.audioCtx.createAnalyser());
  if (next === 'idle' || next === 'thinking') head.stopListening?.();
  if (next === 'speaking') head.lookAtCamera(1200);
}

function setEmotion(next: Emotion) {
  emotion = next;
  emotionNode.textContent = `· ${next}`;
  head.setMood(moodMap[next]);
  document.querySelectorAll<HTMLButtonElement>('[data-emotion]').forEach((button) => {
    button.classList.toggle('active', button.dataset.emotion === next);
  });
}

function stopGesture() {
  if (gestureTimer !== null) window.clearTimeout(gestureTimer);
  gestureTimer = null;
  head.stopGesture(550);
}

function queueGesture(name: string) {
  const now = performance.now();
  if (now - lastGestureAt < 700) return;
  lastGestureAt = now;
  stopGesture();
  // Rocketbox facial animation is high quality, but its authored arm pose is
  // not compatible with TalkingHead's generic Mixamo hand clips. Keep the
  // gesture API semantic and use gaze/emotion cues here; this avoids asking a
  // mismatched rig to make implausible, broken limb rotations.
  const cues: Record<string, Array<[number, () => void]>> = {
    'small nod': [[120, () => head.lookAtCamera(500)], [720, () => head.lookAt(0.5, 0.47, 420)]],
    'large nod': [[120, () => head.lookAtCamera(850)], [1050, () => head.lookAt(0.5, 0.4, 650)]],
    'shake head': [[80, () => head.lookAt(0.38, 0.5, 450)], [580, () => head.lookAt(0.62, 0.5, 650)], [1320, () => head.lookAtCamera(520)]],
    'open palm': [[180, () => head.lookAt(0.58, 0.48, 900)], [1100, () => head.lookAtCamera(650)]],
    explain: [[180, () => head.lookAtCamera(700)], [950, () => head.lookAt(0.58, 0.48, 850)], [1750, () => head.lookAtCamera(600)]],
    praise: [[160, () => head.setMood('happy')], [700, () => head.lookAtCamera(800)]],
    greeting: [[160, () => head.lookAtCamera(900)], [900, () => head.lookAt(0.58, 0.5, 700)]],
    thinking: [[160, () => head.lookAt(0.34, 0.58, 900)], [1050, () => head.lookAtCamera(700)]],
  };
  const selected = cues[name] ?? cues.explain;
  selected.forEach(([delay, callback]) => window.setTimeout(callback, delay));
  gestureTimer = window.setTimeout(stopGesture, selected[selected.length - 1][0] + 1200);
}

async function setupAudioDrivenLipSync() {
  const context = head.audioCtx;
  audioContext = context;
  await context.audioWorklet.addModule('/node_modules/@met4citizen/headaudio/dist/headworklet.min.mjs');
  headaudio = new HeadAudio(context, {
    processorOptions: {vadEventsEnabled: true},
    parameterData: {vadGateActiveDb: -42, vadGateInactiveDb: -58, speakerMeanHz: 220},
  });
  await headaudio.loadModel('/node_modules/@met4citizen/headaudio/dist/model-en-mixed.bin');
  head.audioSpeechGainNode.connect(headaudio);
  headaudio.onvalue = (key: string, value: number) => {
    const target = (head as TalkingHead & {mtAvatar?: Record<string, {newvalue: number; needsUpdate: boolean}>}).mtAvatar?.[key];
    if (target) {
      target.newvalue = value;
      target.needsUpdate = true;
    }
  };
  head.opt.update = headaudio.update.bind(headaudio);
  headaudio.onstarted = () => { audioNode.textContent = 'Speaking'; setPhase('speaking'); };
  headaudio.onended = () => { audioNode.textContent = 'Ready'; setPhase('idle'); };
  setStatus('Runtime ready', true);
}

async function playSpeech() {
  const text = speechInput.value.trim();
  if (!text) return;
  interrupt();
  setPhase('speaking');
  setEmotion(emotion === 'neutral' ? 'warm' : emotion);
  queueGesture('explain');
  audioNode.textContent = 'Loading audio';
  try {
    const response = await fetch('/audio/avatar-demo.wav');
    const buffer = await response.arrayBuffer();
    const decoded = await head.audioCtx.decodeAudioData(buffer);
    head.speakAudio({audio: decoded});
    audioNode.textContent = 'Speaking';
  } catch (error) {
    console.error(error);
    audioNode.textContent = 'Audio unavailable';
    setStatus('Audio failed · runtime still available');
  }
}

function interrupt() {
  head.streamInterrupt?.();
  head.stopAnimation?.();
  head.stopGesture?.(350);
  speechSource?.stop();
  speechSource = null;
  speechGain?.disconnect();
  speechGain = null;
  if (headaudio) headaudio.resetAll();
  setPhase('idle');
  audioNode.textContent = 'Ready';
}

function wireControls() {
  document.querySelectorAll<HTMLButtonElement>('[data-phase]').forEach((button) => {
    button.addEventListener('click', () => setPhase(button.dataset.phase as Phase));
  });
  document.querySelectorAll<HTMLButtonElement>('[data-emotion]').forEach((button) => {
    button.addEventListener('click', () => setEmotion(button.dataset.emotion as Emotion));
  });
  document.querySelectorAll<HTMLButtonElement>('[data-gesture]').forEach((button) => {
    button.addEventListener('click', () => queueGesture(button.dataset.gesture!));
  });
  document.querySelector<HTMLButtonElement>('#play-speech')!.addEventListener('click', playSpeech);
  document.querySelector<HTMLButtonElement>('#interrupt')!.addEventListener('click', interrupt);
  document.querySelector<HTMLButtonElement>('#look-camera')!.addEventListener('click', () => head.lookAtCamera(1600));
  document.querySelector<HTMLButtonElement>('#random-idle')!.addEventListener('click', () => {
    const gestures = ['small nod', 'open palm', 'praise', 'thinking'];
    queueGesture(gestures[Math.floor(Math.random() * gestures.length)]);
  });
}

function updateFps() {
  frameCount += 1;
  const elapsed = performance.now() - fpsStarted;
  if (elapsed > 700) {
    fpsNode.textContent = `${Math.round(frameCount * 1000 / elapsed)}`;
    frameCount = 0;
    fpsStarted = performance.now();
  }
  requestAnimationFrame(updateFps);
}

async function boot() {
  wireControls();
  setStatus('Loading local CG asset');
  try {
    await head.showAvatar({
      url: '/avatar.glb', body: 'F', avatarMood: 'neutral',
      baseline: {headRotateX: -0.025, eyeBlinkLeft: 0.15, eyeBlinkRight: 0.15},
    });
    finishMaterials();
    await setupAudioDrivenLipSync();
    setPhase('idle');
    setEmotion('neutral');
    updateFps();
  } catch (error) {
    console.error(error);
    const reason = error instanceof Error ? error.message : String(error);
    setStatus(`Avatar failed: ${reason}`);
    document.querySelector('#caption-note')!.textContent = 'Check local asset / browser WebGL support';
  }
}

void boot();
