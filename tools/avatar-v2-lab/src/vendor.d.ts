declare module '@met4citizen/talkinghead' {
  export class TalkingHead {
    constructor(node: HTMLElement, options?: Record<string, unknown>);
    audioCtx: AudioContext;
    audioSpeechGainNode: AudioNode;
    mtAvatar?: Record<string, {newvalue: number; needsUpdate: boolean}>;
    opt: {update?: (dt: number) => void};
    showAvatar(avatar: Record<string, unknown>): Promise<void>;
    speakAudio(audio: Record<string, unknown>): void;
    setMood(mood: string): void;
    setView(view: string, options?: Record<string, unknown>): void;
    lookAtCamera(duration: number): void;
    startListening(analyser: AnalyserNode): void;
    stopListening(): void;
    playGesture(name: string, duration?: number, mirror?: boolean, transition?: number): void;
    stopGesture(transition?: number): void;
    stopAnimation(): void;
    streamInterrupt(): void;
  }
}

declare module '@met4citizen/headaudio/modules/headaudio.mjs' {
  export class HeadAudio extends AudioWorkletNode {
    constructor(context: AudioContext, options?: Record<string, unknown>);
    onstarted: (() => void) | null;
    onended: (() => void) | null;
    onvalue: ((key: string, value: number) => void) | null;
    loadModel(url: string): Promise<void>;
    update(dt: number): void;
    resetAll(): void;
  }
}
