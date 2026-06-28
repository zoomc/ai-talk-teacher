import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/util/openai_endpoint.dart';
import '../../profile/domain/profile_models.dart';
import '../../profile/domain/provider_catalog.dart';

/// Speech-to-text service.
///
/// Dispatches on [SttProfile.kind]:
/// - [ProviderKind.openaiCompatible] → multipart POST to `{base}/audio/transcriptions`
///   (OpenAI Whisper, Groq Whisper, SiliconFlow, custom relays/local servers).
/// - [ProviderKind.vendor] → dedicated adapters for Deepgram, Azure, Google.
class SttService {
  final SttProfile profile;
  SttService(this.profile);

  /// Transcribe audio (WAV bytes, 16kHz mono recommended) to text.
  Future<String> transcribe(Uint8List audioData) async {
    switch (profile.kind) {
      case ProviderKind.openaiCompatible:
        return _transcribeOpenAICompatible(audioData);
      case ProviderKind.vendor:
        switch (profile.providerId) {
          case 'deepgram':
            return _transcribeDeepgram(audioData);
          case 'azure':
            return _transcribeAzure(audioData);
          case 'google':
            return _transcribeGoogle(audioData);
          default:
            // Unknown vendor → fall back to OpenAI-compatible surface.
            return _transcribeOpenAICompatible(audioData);
        }
    }
  }

  // ── OpenAI-compatible (Whisper) ──────────────────────────────────────────

  Future<String> _transcribeOpenAICompatible(Uint8List audioData) async {
    final model = profile.model.isEmpty ? 'whisper-1' : profile.model;
    // OpenAI Whisper accepts ISO-639-1 (e.g. "en"); keep user value as-is.
    final language = profile.language;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(openAiEndpoint(profile.baseUrl, 'audio/transcriptions')),
    );
    request.headers['Authorization'] = 'Bearer ${profile.apiKey}';
    request.fields['model'] = model;
    request.fields['language'] = _toShortLangCode(language);
    request.fields['response_format'] = 'json';
    request.files.add(
      http.MultipartFile.fromBytes('file', audioData, filename: 'audio.wav'),
    );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 60),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw SttException(
        '${profile.providerDisplayName} error: '
        '${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    // OpenAI returns {"text": "..."}; some relays wrap differently.
    return (data['text'] as String?) ?? (data['transcript'] as String?) ?? '';
  }

  // ── Deepgram ─────────────────────────────────────────────────────────────
  // Auth: "Token <key>" (NOT Bearer). Endpoint: /v1/listen.
  Future<String> _transcribeDeepgram(Uint8List audioData) async {
    final model = profile.model.isEmpty ? 'nova-3' : profile.model;
    final lang = _toShortLangCode(profile.language);
    final base = profile.baseUrl.isEmpty
        ? 'https://api.deepgram.com'
        : profile.baseUrl;
    final url = Uri.parse(
      '$base/v1/listen?model=$model&language=$lang&smart_format=true',
    );

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Token ${profile.apiKey}',
            'Content-Type': 'audio/wav',
          },
          body: audioData,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw SttException(
        'Deepgram error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final results = data['results'];
    if (results != null && results['channels'] != null) {
      final channels = results['channels'] as List;
      if (channels.isNotEmpty) {
        final alternatives = channels[0]['alternatives'] as List;
        if (alternatives.isNotEmpty) {
          return alternatives[0]['transcript'] as String;
        }
      }
    }
    return '';
  }

  // ── Azure Speech ─────────────────────────────────────────────────────────
  // URL: https://{region}.stt.speech.microsoft.com/speech/recognition/...
  // Response uses "DisplayText" (NOT "text").
  Future<String> _transcribeAzure(Uint8List audioData) async {
    final region = profile.region;
    final lang = profile.language;
    final base = profile.baseUrl.isEmpty
        ? 'https://$region.stt.speech.microsoft.com'
        : profile.baseUrl.replaceAll('{region}', region);

    final response = await http
        .post(
          Uri.parse(
            '$base/speech/recognition/conversation/cognitiveservices/v1?language=$lang',
          ),
          headers: {
            'Ocp-Apim-Subscription-Key': profile.apiKey,
            'Content-Type': 'audio/wav; codecs=audio/pcm; samplerate=16000',
            'Accept': 'application/json',
          },
          body: audioData,
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw SttException(
        'Azure STT error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    return (data['DisplayText'] as String?) ?? '';
  }

  // ── Google Cloud Speech ──────────────────────────────────────────────────
  // Uses API key as ?key=. REST: /v1/speech:recognize with base64 audio.
  Future<String> _transcribeGoogle(Uint8List audioData) async {
    final base = profile.baseUrl.isEmpty
        ? 'https://speech.googleapis.com'
        : profile.baseUrl;
    final response = await http
        .post(
          Uri.parse('$base/v1/speech:recognize?key=${profile.apiKey}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'config': {
              'encoding': 'LINEAR16',
              'sampleRateHertz': 16000,
              'languageCode': profile.language,
            },
            'audio': {'content': base64Encode(audioData)},
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw SttException(
        'Google STT error: ${response.statusCode} - ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final results = data['results'] as List?;
    if (results != null && results.isNotEmpty) {
      final alternatives = results[0]['alternatives'] as List;
      if (alternatives.isNotEmpty) {
        return alternatives[0]['transcript'] as String;
      }
    }
    return '';
  }

  /// Test connectivity + credentials. Throws [SttException] on failure.
  ///
  /// For OpenAI-compatible providers, hits `/models`. For vendors without a
  /// lightweight auth endpoint, performs a minimal probe that returns 401 on
  /// bad keys (which we treat as "reachable but unauthorized").
  Future<void> testConnection() async {
    switch (profile.kind) {
      case ProviderKind.openaiCompatible:
        final response = await http
            .get(
              Uri.parse(openAiEndpoint(profile.baseUrl, 'models')),
              headers: {'Authorization': 'Bearer ${profile.apiKey}'},
            )
            .timeout(const Duration(seconds: 15));
        _checkAuth(response, profile.providerDisplayName);
        break;
      case ProviderKind.vendor:
        // Vendors: a tiny authenticated probe. We don't need a 200, just a
        // response that isn't a network/auth error.
        switch (profile.providerId) {
          case 'deepgram':
            final base = profile.baseUrl.isEmpty
                ? 'https://api.deepgram.com'
                : profile.baseUrl;
            final r = await http
                .get(
                  Uri.parse('$base/v1/projects'),
                  headers: {'Authorization': 'Token ${profile.apiKey}'},
                )
                .timeout(const Duration(seconds: 15));
            _checkAuth(r, 'Deepgram');
            break;
          case 'azure':
          case 'google':
            // No safe read-only probe; validate region/URL parse instead.
            if (profile.baseUrl.isEmpty && profile.providerId == 'azure') {
              throw SttException(
                'Azure region is required. Set it in the form.',
              );
            }
            break;
          default:
            break;
        }
        break;
    }
  }

  void _checkAuth(http.Response response, String label) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SttException(
        '$label rejected the API key (${response.statusCode}).',
      );
    }
    if (response.statusCode >= 500) {
      throw SttException('$label server error (${response.statusCode}).');
    }
    // 200/400/404 etc. all imply the endpoint is reachable and the key format
    // was accepted; specific model issues surface at transcribe time.
  }

  /// "en-US" → "en" (Whisper wants ISO-639-1).
  String _toShortLangCode(String code) {
    if (code.isEmpty) return 'en';
    final dash = code.indexOf('-');
    return dash > 0 ? code.substring(0, dash) : code;
  }
}

class SttException implements Exception {
  final String message;
  SttException(this.message);

  @override
  String toString() => 'SttException: $message';
}
