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

const head = new TalkingHead(avatarNode, {
  cameraView: 'upper',
  cameraDistance: 0.05,
  cameraRotateEnable: false,
  cameraZoomEnable: false,
  modelPixelRatio: Math.min(window.devicePixelRatio, 1.75),
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
  lightAmbientIntensity: 1.3,
  lightDirectColor: 0xfff7ed,
  lightDirectIntensity: 17,
  lightDirectPhi: 0.9,
  lightDirectTheta: 2.1,
  lightSpotColor: 0x94b8ff,
  lightSpotIntensity: 7,
  lightSpotPhi: 0.9,
  lightSpotTheta: 3.4,
  lightSpotDispersion: 1.8,
});

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
  const timeline: Record<string, Array<[number, string, number, boolean]>> = {
    'small nod': [[220, 'nod', 900, false]],
    'large nod': [[220, 'nod', 1400, false]],
    'shake head': [[250, 'shake', 1300, false]],
    'open palm': [[360, 'side', 1800, false]],
    explain: [[260, 'side', 1600, false], [1550, 'handup', 1300, true]],
    praise: [[240, 'thumbup', 1500, false], [1750, 'nod', 800, false]],
    greeting: [[180, 'handup', 1800, false]],
    thinking: [[200, 'shrug', 1800, false]],
  };
  const cues = timeline[name] ?? timeline.explain;
  cues.forEach(([delay, gesture, duration, mirror]) => {
    window.setTimeout(() => head.playGesture(gesture, duration / 1000, mirror, 650), delay);
  });
  gestureTimer = window.setTimeout(stopGesture, cues[cues.length - 1][0] + cues[cues.length - 1][2] + 850);
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
    await setupAudioDrivenLipSync();
    setPhase('idle');
    setEmotion('neutral');
    updateFps();
  } catch (error) {
    console.error(error);
    setStatus('Avatar failed to load');
    document.querySelector('#caption-note')!.textContent = 'Check local asset / browser WebGL support';
  }
}

void boot();
