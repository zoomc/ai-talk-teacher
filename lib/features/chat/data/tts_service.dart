import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/util/openai_endpoint.dart';
import '../../profile/domain/profile_models.dart';
import '../../profile/domain/provider_catalog.dart';

/// Text-to-speech service.
///
/// Dispatches on [TtsProfile.kind]:
/// - [ProviderKind.openaiCompatible] → POST `{base}/audio/speech`
///   (OpenAI TTS, SiliconFlow TTS, custom relays/local servers).
/// - [ProviderKind.vendor] → dedicated adapters for Fish Audio, ElevenLabs,
///   Azure TTS, Google TTS, Aliyun CosyVoice.
class TtsService {
  final TtsProfile profile;
  TtsService(this.profile);

  /// Synthesize text to audio bytes (mp3 unless the vendor picks otherwise).
  Future<Uint8List> synthesize(String text) async {
    switch (profile.kind) {
      case ProviderKind.openaiCompatible:
        return _synthesizeOpenAICompatible(text);
      case ProviderKind.vendor:
        switch (profile.providerId) {
          case 'fish_audio':
            return _synthesizeFishAudio(text);
          case 'elevenlabs':
            return _synthesizeElevenLabs(text);
          case 'azure_tts':
            return _synthesizeAzure(text);
          case 'google_tts':
            return _synthesizeGoogle(text);
          case 'aliyun_cosyvoice':
            return _synthesizeAliyun(text);
          case 'deepgram_tts':
            return _synthesizeDeepgram(text);
          case 'volcengine_tts':
          case 'xfyun_tts':
          case 'tencent_tts':
            throw UnimplementedError(
              '${profile.providerDisplayName} is not directly supported by '
              'SpeakFlow. Deploy a relay or use a custom OpenAI-compatible '
              'TTS endpoint instead. See the provider note for details.',
            );
          default:
            return _synthesizeOpenAICompatible(text);
        }
    }
  }

  // ── OpenAI-compatible (/audio/speech) ────────────────────────────────────
  Future<Uint8List> _synthesizeOpenAICompatible(String text) async {
    final model = profile.model.isEmpty ? 'tts-1' : profile.model;
    final voice = (profile.voiceId?.isNotEmpty ?? false)
        ? profile.voiceId!
        : (profile.providerDef.defaultVoice ?? 'alloy');

    final response = await http
        .post(
          Uri.parse(openAiEndpoint(profile.baseUrl, 'audio/speech')),
          headers: {
            'Authorization': 'Bearer ${profile.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'input': text,
            'voice': voice,
            'response_format': 'mp3',
            'speed': profile.speed,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        '${profile.providerDisplayName} error: '
        '${response.statusCode} - ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  // ── Deepgram TTS (Aura) ──────────────────────────────────────────────────
  // Endpoint: /v1/speak?model=. Auth: "Token <key>". Returns audio bytes.
  Future<Uint8List> _synthesizeDeepgram(String text) async {
    final base = profile.baseUrl.isEmpty
        ? 'https://api.deepgram.com'
        : profile.baseUrl;
    final model = profile.model.isEmpty ? 'aura-asteria-en' : profile.model;
    final response = await http
        .post(
          Uri.parse('$base/v1/speak?model=$model'),
          headers: {
            'Authorization': 'Token ${profile.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'text': text}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        'Deepgram TTS error: ${response.statusCode} - ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  // ── Fish Audio ───────────────────────────────────────────────────────────
  // Endpoint: /api/open/tts (NOT /tts). Bearer auth. Returns audio bytes.
  Future<Uint8List> _synthesizeFishAudio(String text) async {
    final base = profile.baseUrl.isEmpty
        ? 'https://api.fish.audio'
        : profile.baseUrl;
    final model = profile.model.isEmpty ? 's1' : profile.model;
    final response = await http
        .post(
          Uri.parse('$base/api/open/tts'),
          headers: {
            'Authorization': 'Bearer ${profile.apiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'text': text,
            'reference_id': profile.voiceId ?? '',
            'format': 'mp3',
            'speed': profile.speed,
            if (model.isNotEmpty) 'model': model,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        'Fish Audio error: ${response.statusCode} - ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  // ── ElevenLabs ───────────────────────────────────────────────────────────
  // Endpoint: /v1/text-to-speech/{voice_id}. Header: xi-api-key.
  Future<Uint8List> _synthesizeElevenLabs(String text) async {
    final base = profile.baseUrl.isEmpty
        ? 'https://api.elevenlabs.io'
        : profile.baseUrl;
    final voiceId = (profile.voiceId?.isNotEmpty ?? false)
        ? profile.voiceId!
        : (profile.providerDef.defaultVoice ?? '21m00Tcm4TlvDq8ikWAM');
    final model = profile.model.isEmpty
        ? 'eleven_multilingual_v2'
        : profile.model;

    final response = await http
        .post(
          Uri.parse('$base/v1/text-to-speech/$voiceId'),
          headers: {
            'xi-api-key': profile.apiKey,
            'Content-Type': 'application/json',
            'Accept': 'audio/mpeg',
          },
          body: jsonEncode({
            'text': text,
            'model_id': model,
            'voice_settings': {'stability': 0.5, 'similarity_boost': 0.75},
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        'ElevenLabs error: ${response.statusCode} - ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  // ── Azure TTS (SSML) ─────────────────────────────────────────────────────
  Future<Uint8List> _synthesizeAzure(String text) async {
    final region = profile.region;
    final base = profile.baseUrl.isEmpty
        ? 'https://$region.tts.speech.microsoft.com'
        : profile.baseUrl.replaceAll('{region}', region);
    final voice = (profile.voiceId?.isNotEmpty ?? false)
        ? profile.voiceId!
        : (profile.providerDef.defaultVoice ?? 'en-US-JennyNeural');
    final rate = _speedToSsmlRate(profile.speed);

    final ssml =
        '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <voice name="$voice">
    <prosody rate="$rate">${_escapeXml(text)}</prosody>
  </voice>
</speak>''';

    final response = await http
        .post(
          Uri.parse('$base/cognitiveservices/v1'),
          headers: {
            'Ocp-Apim-Subscription-Key': profile.apiKey,
            'Content-Type': 'application/ssml+xml',
            'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          },
          body: ssml,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        'Azure TTS error: ${response.statusCode} - ${response.body}',
      );
    }
    return response.bodyBytes;
  }

  // ── Google Cloud TTS ─────────────────────────────────────────────────────
  // Endpoint: /v1/text:synthesize?key=. Returns base64 audio in response.
  Future<Uint8List> _synthesizeGoogle(String text) async {
    final base = profile.baseUrl.isEmpty
        ? 'https://texttospeech.googleapis.com'
        : profile.baseUrl;
    final voice = (profile.voiceId?.isNotEmpty ?? false)
        ? profile.voiceId!
        : (profile.providerDef.defaultVoice ?? 'en-US-Journey-F');

    final response = await http
        .post(
          Uri.parse('$base/v1/text:synthesize?key=${profile.apiKey}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'input': {'text': text},
            'voice': {
              'languageCode': voice.split('-').take(2).join('-'),
              'name': voice,
            },
            'audioConfig': {
              'audioEncoding': 'MP3',
              'speakingRate': profile.speed,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        'Google TTS error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final audioB64 = data['audioContent'] as String?;
    if (audioB64 == null) {
      throw TtsException('Google TTS returned no audio content.');
    }
    return base64Decode(audioB64);
  }

  // ── Aliyun CosyVoice (DashScope) ─────────────────────────────────────────
  // Non-streaming returns JSON with output.audio.url → HTTP-GET the URL.
  Future<Uint8List> _synthesizeAliyun(String text) async {
    final base = profile.baseUrl.isEmpty
        ? 'https://dashscope.aliyuncs.com'
        : profile.baseUrl;
    final model = profile.model.isEmpty ? 'cosyvoice-v2' : profile.model;
    final voice = (profile.voiceId?.isNotEmpty ?? false)
        ? profile.voiceId!
        : (profile.providerDef.defaultVoice ?? 'longxiaocheng');

    final response = await http
        .post(
          Uri.parse('$base/api/v1/services/audio/tts/SpeechSynthesizer'),
          headers: {
            'Authorization': 'Bearer ${profile.apiKey}',
            'Content-Type': 'application/json',
            'X-DashScope-DataInspection': 'enable',
          },
          body: jsonEncode({
            'model': model,
            'input': {'text': text},
            'parameters': {
              'voice': voice,
              'format': 'mp3',
              'sample_rate': 16000,
              if (profile.speed != 1.0) 'speed': profile.speed,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw TtsException(
        'Aliyun CosyVoice error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final output = data['output'] as Map<String, dynamic>?;
    final audio = output?['audio'] as Map<String, dynamic>?;
    final url = audio?['url'] as String?;
    if (url == null) {
      // Some responses stream bytes directly; treat body as audio in that case.
      if (response.bodyBytes.isNotEmpty &&
          response.headers['content-type']?.startsWith('audio/') == true) {
        return response.bodyBytes;
      }
      throw TtsException('Aliyun CosyVoice did not return an audio URL.');
    }

    // Download the audio from the returned URL.
    final dl = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 60));
    if (dl.statusCode != 200) {
      throw TtsException('Aliyun audio download failed: ${dl.statusCode}');
    }
    return dl.bodyBytes;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _speedToSsmlRate(double speed) {
    if (speed <= 0.8) return '-20%';
    if (speed < 1.0) return '-10%';
    if (speed == 1.0) return '0%';
    if (speed <= 1.2) return '+10%';
    if (speed <= 1.5) return '+20%';
    return '+30%';
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  // ── Connectivity test + voice fetching ───────────────────────────────────

  /// Test connectivity + credentials. Throws [TtsException] on failure.
  Future<void> testConnection() async {
    switch (profile.kind) {
      case ProviderKind.openaiCompatible:
        // No dedicated "voices" list endpoint; /models is the best probe.
        final response = await http
            .get(
              Uri.parse(openAiEndpoint(profile.baseUrl, 'models')),
              headers: {'Authorization': 'Bearer ${profile.apiKey}'},
            )
            .timeout(const Duration(seconds: 15));
        _checkAuth(response, profile.providerDisplayName);
        break;
      case ProviderKind.vendor:
        switch (profile.providerId) {
          case 'fish_audio':
            final base = profile.baseUrl.isEmpty
                ? 'https://api.fish.audio'
                : profile.baseUrl;
            final r = await http
                .get(
                  Uri.parse('$base/api/open/v1/model/list?page_size=1'),
                  headers: {'Authorization': 'Bearer ${profile.apiKey}'},
                )
                .timeout(const Duration(seconds: 15));
            _checkAuth(r, 'Fish Audio');
            break;
          case 'elevenlabs':
            final base = profile.baseUrl.isEmpty
                ? 'https://api.elevenlabs.io'
                : profile.baseUrl;
            final r = await http
                .get(
                  Uri.parse('$base/v1/voices'),
                  headers: {'xi-api-key': profile.apiKey},
                )
                .timeout(const Duration(seconds: 15));
            _checkAuth(r, 'ElevenLabs');
            break;
          case 'azure_tts':
            if (profile.region.isEmpty) {
              throw TtsException(
                'Azure region is required. Set it in the form.',
              );
            }
            break;
          case 'google_tts':
          case 'aliyun_cosyvoice':
            // No safe read-only probe; rely on synthesize-time errors.
            break;
          case 'deepgram_tts':
            final base = profile.baseUrl.isEmpty
                ? 'https://api.deepgram.com'
                : profile.baseUrl;
            final r = await http
                .get(
                  Uri.parse('$base/v1/projects'),
                  headers: {'Authorization': 'Token ${profile.apiKey}'},
                )
                .timeout(const Duration(seconds: 15));
            _checkAuth(r, 'Deepgram TTS');
            break;
          case 'volcengine_tts':
          case 'xfyun_tts':
          case 'tencent_tts':
            throw TtsException(
              '${profile.providerDisplayName} is not directly supported. '
              'Use a custom OpenAI-compatible TTS endpoint instead.',
            );
          default:
            break;
        }
        break;
    }
  }

  /// Placeholder voice id for the Fish Audio probe path (kept short on purpose).
  static const String defaultVoiceProbe = '';

  /// Fetch available voices/models for providers that expose a list endpoint.
  ///
  /// Returns a list of `{id, name}` maps. Empty list for providers that don't
  /// support listing (callers fall back to the catalog's static voice list).
  Future<List<VoiceOption>> fetchVoices() async {
    switch (profile.kind) {
      case ProviderKind.openaiCompatible:
        return []; // Use catalog static voices.
      case ProviderKind.vendor:
        switch (profile.providerId) {
          case 'elevenlabs':
            return _fetchElevenLabsVoices();
          case 'fish_audio':
            return _fetchFishAudioVoices();
          case 'azure_tts':
            return _fetchAzureVoices();
          default:
            return [];
        }
    }
  }

  Future<List<VoiceOption>> _fetchElevenLabsVoices() async {
    final base = profile.baseUrl.isEmpty
        ? 'https://api.elevenlabs.io'
        : profile.baseUrl;
    final response = await http
        .get(
          Uri.parse('$base/v1/voices'),
          headers: {'xi-api-key': profile.apiKey},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    final voices = data['voices'] as List? ?? [];
    return voices
        .map(
          (v) => VoiceOption(
            id: v['voice_id'] as String,
            name: v['name'] as String? ?? v['voice_id'] as String,
          ),
        )
        .toList();
  }

  Future<List<VoiceOption>> _fetchFishAudioVoices() async {
    final base = profile.baseUrl.isEmpty
        ? 'https://api.fish.audio'
        : profile.baseUrl;
    final response = await http
        .get(
          Uri.parse('$base/api/open/v1/model/list?page_size=100'),
          headers: {'Authorization': 'Bearer ${profile.apiKey}'},
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return [];
    final data = jsonDecode(response.body);
    final items =
        (data['data']?['items'] as List?) ?? (data['items'] as List?) ?? [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(
          (v) => VoiceOption(
            id: v['_id'] as String? ?? v['id'] as String? ?? '',
            name: v['title'] as String? ?? v['name'] as String? ?? 'Untitled',
          ),
        )
        .where((v) => v.id.isNotEmpty)
        .toList();
  }

  Future<List<VoiceOption>> _fetchAzureVoices() async {
    final region = profile.region;
    final tokenUri = Uri.parse(
      'https://$region.api.cognitive.microsoft.com/sts/v1.0/issueToken',
    );
    final tokenResp = await http
        .post(tokenUri, headers: {'Ocp-Apim-Subscription-Key': profile.apiKey})
        .timeout(const Duration(seconds: 15));
    if (tokenResp.statusCode != 200) return [];
    final accessToken = tokenResp.body;
    final listResp = await http
        .get(
          Uri.parse(
            'https://$region.tts.speech.microsoft.com/cognitiveservices/voices/list',
          ),
          headers: {'Authorization': 'Bearer $accessToken'},
        )
        .timeout(const Duration(seconds: 15));
    if (listResp.statusCode != 200) return [];
    final List<dynamic> items = jsonDecode(listResp.body) as List;
    return items
        .whereType<Map<String, dynamic>>()
        .where((v) => (v['Locale'] as String?)?.startsWith('en') ?? false)
        .map(
          (v) => VoiceOption(
            id: v['ShortName'] as String,
            name: '${v['DisplayName']} (${v['LocaleName']})',
          ),
        )
        .toList();
  }

  void _checkAuth(http.Response response, String label) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw TtsException(
        '$label rejected the API key (${response.statusCode}).',
      );
    }
    if (response.statusCode >= 500) {
      throw TtsException('$label server error (${response.statusCode}).');
    }
  }
}

/// A selectable voice returned by [TtsService.fetchVoices].
class VoiceOption {
  final String id;
  final String name;
  const VoiceOption({required this.id, required this.name});
}

class TtsException implements Exception {
  final String message;
  TtsException(this.message);

  @override
  String toString() => 'TtsException: $message';
}
