import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../features/profile/domain/profile_models.dart';

class SttService {
  final SttProfile profile;
  SttService(this.profile);

  /// Transcribe audio to text
  Future<String> transcribe(Uint8List audioData) async {
    switch (profile.provider) {
      case SttProvider.deepgram:
        return _transcribeDeepgram(audioData);
      case SttProvider.openaiWhisper:
        return _transcribeOpenAI(audioData);
      case SttProvider.googleCloud:
        return _transcribeGoogle(audioData);
      case SttProvider.azure:
        return _transcribeAzure(audioData);
    }
  }

  Future<String> _transcribeDeepgram(Uint8List audioData) async {
    final response = await http.post(
      Uri.parse('https://api.deepgram.com/v1/listen?language=en&model=nova-2&smart_format=true'),
      headers: {
        'Authorization': 'Token ${profile.apiKey}',
        'Content-Type': 'audio/wav',
      },
      body: audioData,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw SttException('Deepgram error: ${response.statusCode}');
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

  Future<String> _transcribeOpenAI(Uint8List audioData) async {
    // OpenAI Whisper API requires multipart form
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    );
    request.headers['Authorization'] = 'Bearer ${profile.apiKey}';
    request.fields['model'] = 'whisper-1';
    request.fields['language'] = 'en';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      audioData,
      filename: 'audio.wav',
    ));

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw SttException('OpenAI error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['text'] as String? ?? '';
  }

  Future<String> _transcribeGoogle(Uint8List audioData) async {
    // Google Cloud Speech-to-Text REST API
    final response = await http.post(
      Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=${profile.apiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'config': {
          'encoding': 'LINEAR16',
          'sampleRateHertz': 16000,
          'languageCode': 'en-US',
        },
        'audio': {
          'content': base64Encode(audioData),
        },
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw SttException('Google error: ${response.statusCode}');
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

  Future<String> _transcribeAzure(Uint8List audioData) async {
    // Azure Speech Services
    final response = await http.post(
      Uri.parse('https://eastus.stt.speech.microsoft.com/speech/recognition/conversation/cognitiveservices/v1?language=en-US'),
      headers: {
        'Ocp-Apim-Subscription-Key': profile.apiKey,
        'Content-Type': 'audio/wav',
      },
      body: audioData,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw SttException('Azure error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['DisplayText'] as String? ?? '';
  }
}

class SttException implements Exception {
  final String message;
  SttException(this.message);

  @override
  String toString() => 'SttException: $message';
}
