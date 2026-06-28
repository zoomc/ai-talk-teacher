/// Provider catalog for the 3-Profile system (LLM / STT / TTS).
///
/// Design goals:
/// - User picks a provider from the catalog → base URL / default model / voice
///   are auto-filled. They only need to paste an API key.
/// - "Custom (OpenAI-compatible)" entries cover relay stations (中转站) and
///   self-hosted local servers (Ollama, LM Studio, whisper.cpp, faster-whisper,
///   vLLM, etc.) that expose the OpenAI REST surface.
/// - Vendors with non-OpenAI APIs are handled by dedicated adapters in the
///   service layer (Deepgram, Azure, Google, Fish Audio, ElevenLabs, Aliyun).
///
/// Convention: for `openaiCompatible` providers, [defaultBaseUrl] includes the
/// API version prefix (e.g. `https://api.openai.com/v1`). The services append
/// `/chat/completions`, `/models`, `/audio/transcriptions`, `/audio/speech`.
/// A normalizer in each service tolerates base URLs with or without the version
/// segment, so users who type `https://api.deepseek.com` still work.

/// How a provider is invoked.
enum ProviderKind {
  /// OpenAI-compatible REST surface.
  openaiCompatible,

  /// Vendor-specific REST adapter (handled in the service layer).
  vendor,
}

/// Server region hint, used for grouping in the picker UI.
enum ProviderRegion { cn, global, local }

/// A single provider definition.
class ProviderDef {
  final String id;
  final String displayName;
  final ProviderKind kind;
  final String defaultBaseUrl;
  final String? defaultModel;
  final String? defaultVoice;
  final String docsUrl;
  final String? note;
  final bool apiKeyRequired;
  final ProviderRegion region;

  /// Static voice list for TTS (when the vendor doesn't offer a list endpoint).
  final List<String> voices;

  const ProviderDef({
    required this.id,
    required this.displayName,
    this.kind = ProviderKind.openaiCompatible,
    required this.defaultBaseUrl,
    this.defaultModel,
    this.defaultVoice,
    required this.docsUrl,
    this.note,
    this.apiKeyRequired = true,
    this.region = ProviderRegion.global,
    this.voices = const [],
  });
}

/// Catalog of LLM providers (all OpenAI-compatible).
class LlmProviderCatalog {
  static const String customId = 'custom';

  static const List<ProviderDef> all = [
    ProviderDef(
      id: 'deepseek',
      displayName: 'DeepSeek',
      defaultBaseUrl: 'https://api.deepseek.com/v1',
      defaultModel: 'deepseek-v4-flash',
      docsUrl: 'https://platform.deepseek.com',
      note: 'Cheap, capable, great default. China-based, global access.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'zhipu_glm',
      displayName: 'Zhipu GLM (智谱)',
      defaultBaseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      defaultModel: 'glm-4-flash',
      docsUrl: 'https://open.bigmodel.cn',
      note: 'GLM-4 series. Path uses /api/paas/v4.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'moonshot_kimi',
      displayName: 'Moonshot Kimi (月之暗面)',
      defaultBaseUrl: 'https://api.moonshot.ai/v1',
      defaultModel: 'kimi-k2.6',
      docsUrl: 'https://platform.moonshot.ai',
      note: 'Kimi K2 series. Long context.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'qwen_dashscope',
      displayName: 'Qwen (DashScope 通义)',
      defaultBaseUrl: 'https://dashscope-intl.aliyuncs.com/compatible-mode/v1',
      defaultModel: 'qwen-plus',
      docsUrl: 'https://bailian.console.aliyun.com',
      note:
          'Qwen via DashScope OpenAI-compatible mode. CN users: use https://dashscope.aliyuncs.com/compatible-mode/v1',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'siliconflow',
      displayName: 'SiliconFlow (硅基流动)',
      defaultBaseUrl: 'https://api.siliconflow.cn/v1',
      defaultModel: 'deepseek-ai/DeepSeek-V3',
      docsUrl: 'https://siliconflow.cn',
      note:
          'Aggregator/relay with many open models. Great fallback for domestic users.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'openai',
      displayName: 'OpenAI',
      defaultBaseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini',
      docsUrl: 'https://platform.openai.com',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'groq',
      displayName: 'Groq',
      defaultBaseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
      docsUrl: 'https://console.groq.com',
      note: 'Ultra-low latency. Free tier available.',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'together',
      displayName: 'Together AI',
      defaultBaseUrl: 'https://api.together.ai/v1',
      defaultModel: 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
      docsUrl: 'https://docs.together.ai',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'mistral',
      displayName: 'Mistral (La Plateforme)',
      defaultBaseUrl: 'https://api.mistral.ai/v1',
      defaultModel: 'mistral-small-latest',
      docsUrl: 'https://console.mistral.ai',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'ollama',
      displayName: 'Ollama (Local)',
      defaultBaseUrl: 'http://localhost:11434/v1',
      defaultModel: 'llama3.2',
      docsUrl: 'https://ollama.com',
      note: 'Run models locally. No API key needed (enter any text).',
      apiKeyRequired: false,
      region: ProviderRegion.local,
    ),
    ProviderDef(
      id: 'lm_studio',
      displayName: 'LM Studio (Local)',
      defaultBaseUrl: 'http://localhost:1234/v1',
      defaultModel: '',
      docsUrl: 'https://lmstudio.ai',
      note: 'Local OpenAI-compatible server. Fetch models after starting it.',
      apiKeyRequired: false,
      region: ProviderRegion.local,
    ),
    ProviderDef(
      id: customId,
      displayName: 'Custom (OpenAI-compatible / Relay / Local)',
      defaultBaseUrl: '',
      defaultModel: '',
      docsUrl: '',
      note:
          'Any service exposing /chat/completions: relay stations (中转站), vLLM, LocalAI, etc.',
      apiKeyRequired: false,
      region: ProviderRegion.global,
    ),
  ];

  static ProviderDef byId(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.firstWhere((p) => p.id == customId),
    );
  }
}

/// Catalog of STT providers.
class SttProviderCatalog {
  static const String customId = 'custom';

  static const List<ProviderDef> all = [
    ProviderDef(
      id: 'openai_whisper',
      displayName: 'OpenAI Whisper',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: 'https://api.openai.com/v1',
      defaultModel: 'whisper-1',
      docsUrl: 'https://platform.openai.com/docs/guides/speech-to-text',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'groq_whisper',
      displayName: 'Groq Whisper',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'whisper-large-v3',
      docsUrl: 'https://console.groq.com/docs/speech-text',
      note: 'Fastest Whisper. Free tier.',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'deepgram',
      displayName: 'Deepgram',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://api.deepgram.com',
      defaultModel: 'nova-3',
      docsUrl: 'https://console.deepgram.com',
      note: 'Low latency, strong accent handling. Auth header: "Token <key>".',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'azure',
      displayName: 'Azure Speech',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://{region}.stt.speech.microsoft.com',
      defaultModel: '',
      docsUrl: 'https://learn.microsoft.com/azure/ai-services/speech-service',
      note: 'Set region (e.g. eastus) in the Region field.',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'google',
      displayName: 'Google Cloud Speech',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://speech.googleapis.com',
      defaultModel: '',
      docsUrl: 'https://console.cloud.google.com/speech',
      note: 'Uses API key (not OAuth).',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'siliconflow_stt',
      displayName: 'SiliconFlow Whisper',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: 'https://api.siliconflow.cn/v1',
      defaultModel: 'FunAudioAI/SenseVoiceSmall',
      docsUrl: 'https://siliconflow.cn',
      note: 'Domestic OpenAI-compatible STT relay.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: customId,
      displayName: 'Custom (OpenAI-compatible / Relay / Local)',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: '',
      defaultModel: 'whisper-1',
      docsUrl: '',
      note:
          'Any /audio/transcriptions endpoint: relay stations, whisper.cpp server, faster-whisper-server, etc.',
      apiKeyRequired: false,
      region: ProviderRegion.global,
    ),
  ];

  static ProviderDef byId(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.firstWhere((p) => p.id == customId),
    );
  }
}

/// Catalog of TTS providers.
class TtsProviderCatalog {
  static const String customId = 'custom';

  /// OpenAI built-in voices.
  static const List<String> _openaiVoices = [
    'alloy',
    'ash',
    'ballad',
    'coral',
    'echo',
    'fable',
    'nova',
    'onyx',
    'sage',
    'shimmer',
  ];

  static const List<String> _googleVoices = [
    'en-US-Journey-F',
    'en-US-Journey-D',
    'en-US-Neural2-F',
    'en-US-Neural2-A',
    'en-US-Standard-A',
    'en-US-Standard-B',
    'en-GB-Neural2-A',
    'en-GB-Neural2-F',
  ];

  static const List<String> _aliyunVoices = [
    'longxiaocheng',
    'longxiaoxia',
    'longanyang',
    'longshu',
    'longcheng',
  ];

  static const List<ProviderDef> all = [
    ProviderDef(
      id: 'openai_tts',
      displayName: 'OpenAI TTS',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini-tts',
      defaultVoice: 'nova',
      docsUrl: 'https://platform.openai.com/docs/guides/text-to-speech',
      voices: _openaiVoices,
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'fish_audio',
      displayName: 'Fish Audio',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://api.fish.audio',
      defaultModel: 's1',
      defaultVoice: '',
      docsUrl: 'https://fish.audio',
      note:
          'Rich Chinese/English voices, voice clone. Fetch voice models after entering key.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'elevenlabs',
      displayName: 'ElevenLabs',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://api.elevenlabs.io',
      defaultModel: 'eleven_multilingual_v2',
      defaultVoice: '21m00Tcm4TlvDq8ikWAM',
      docsUrl: 'https://elevenlabs.io',
      note: 'Industry-leading expressiveness. Fetch voices after entering key.',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'azure_tts',
      displayName: 'Azure TTS',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://{region}.tts.speech.microsoft.com',
      defaultModel: '',
      defaultVoice: 'en-US-JennyNeural',
      docsUrl: 'https://learn.microsoft.com/azure/ai-services/speech-service',
      note: 'Set region (e.g. eastus). Fetch voice list after entering key.',
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'google_tts',
      displayName: 'Google Cloud TTS',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://texttospeech.googleapis.com',
      defaultModel: '',
      defaultVoice: 'en-US-Journey-F',
      docsUrl: 'https://console.cloud.google.com/text-to-speech',
      voices: _googleVoices,
      region: ProviderRegion.global,
    ),
    ProviderDef(
      id: 'aliyun_cosyvoice',
      displayName: 'Aliyun CosyVoice (通义)',
      kind: ProviderKind.vendor,
      defaultBaseUrl: 'https://dashscope.aliyuncs.com',
      defaultModel: 'cosyvoice-v2',
      defaultVoice: 'longxiaocheng',
      docsUrl: 'https://help.aliyun.com/zh/model-studio/cosyvoice-tts-http-api',
      voices: _aliyunVoices,
      note:
          'DashScope key. Non-streaming returns a download URL (handled automatically).',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: 'siliconflow_tts',
      displayName: 'SiliconFlow TTS',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: 'https://api.siliconflow.cn/v1',
      defaultModel: 'FishAudio/fish-speech-1.5',
      defaultVoice: '',
      docsUrl: 'https://siliconflow.cn',
      note: 'Domestic OpenAI-compatible /audio/speech relay.',
      region: ProviderRegion.cn,
    ),
    ProviderDef(
      id: customId,
      displayName: 'Custom (OpenAI-compatible / Relay / Local)',
      kind: ProviderKind.openaiCompatible,
      defaultBaseUrl: '',
      defaultModel: 'tts-1',
      defaultVoice: 'alloy',
      docsUrl: '',
      note:
          'Any /audio/speech endpoint: relay stations, local OpenAI-compatible TTS servers, etc.',
      apiKeyRequired: false,
      region: ProviderRegion.global,
      voices: _openaiVoices,
    ),
  ];

  static ProviderDef byId(String id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.firstWhere((p) => p.id == customId),
    );
  }
}
