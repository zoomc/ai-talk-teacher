import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../features/profile/domain/profile_models.dart';

class TtsService {
  final TtsProfile profile;
  TtsService(this.profile);

  /// Convert text to speech audio
  Future<Uint8List> synthesize(String text) async {
    switch (profile.provider) {
      case TtsProvider.fishAudio:
        return _synthesizeFishAudio(text);
      case TtsProvider.elevenLabs:
        return _synthesizeElevenLabs(text);
      case TtsProvider.openaiTts:
        return _synthesizeOpenAI(text);
      case TtsProvider.azure:
        return _synthesizeAzure(text);
    }
  }

  Future<Uint8List> _synthesizeFishAudio(String text) async {
    final response = await http.post(
      Uri.parse('https://api.fish.audio/tts'),
      headers: {
        'Authorization': 'Bearer ${profile.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'reference_id': profile.voiceId ?? 'default',
        'format': 'mp3',
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw TtsException('Fish Audio error: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  Future<Uint8List> _synthesizeElevenLabs(String text) async {
    final voiceId = profile.voiceId ?? '21m00Tcm4TlvDq8ikWAM'; // Rachel
    final response = await http.post(
      Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId'),
      headers: {
        'xi-api-key': profile.apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'text': text,
        'model_id': 'eleven_monolingual_v1',
        'voice_settings': {
          'stability': 0.5,
          'similarity_boost': 0.75,
        },
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw TtsException('ElevenLabs error: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  Future<Uint8List> _synthesizeOpenAI(String text) async {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/audio/speech'),
      headers: {
        'Authorization': 'Bearer ${profile.apiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'tts-1',
        'input': text,
        'voice': profile.voiceName ?? 'alloy',
        'response_format': 'mp3',
        'speed': profile.speed,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw TtsException('OpenAI TTS error: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  Future<Uint8List> _synthesizeAzure(String text) async {
    final ssml = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="en-US">
  <voice name="${profile.voiceName ?? 'en-US-JennyNeural'}">
    <prosody rate="${profile.speed}">${_escapeXml(text)}</prosody>
  </voice>
</speak>''';

    final response = await http.post(
      Uri.parse('https://eastus.tts.speech.microsoft.com/cognitiveservices/v1'),
      headers: {
        'Ocp-Apim-Subscription-Key': profile.apiKey,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
      },
      body: ssml,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw TtsException('Azure TTS error: ${response.statusCode}');
    }

    return response.bodyBytes;
  }

  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

class TtsException implements Exception {
  final String message;
  TtsException(this.message);

  @override
  String toString() => 'TtsException: $message';
}
