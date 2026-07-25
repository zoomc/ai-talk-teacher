// Conditional export for E2E mock services.
//
// Services (LlmService, SttService, TtsService) import from this file:
//   ```dart
//   import 'package:speakflow/core/e2e/e2e_mock_services.dart';
//
//   Future<String> complete(...) async {
//     final canned = E2eMockServices.cannedLlmReply(prompt);
//     if (canned != null) return canned;
//     // ... real HTTP implementation
//   }
//   ```
//
// On non-web platforms or non-E2E builds, the stub returns nulls (no mocking).
// On web with --dart-define=E2E=true, the web version returns canned data
// when `mockModeEnabled` is true.
library speakflow.e2e.mock_services;

export 'e2e_mock_services_stub.dart'
    if (dart.library.js_interop) 'e2e_mock_services_web.dart';
