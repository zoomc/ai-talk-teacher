// Conditional export: only the web platform gets the real E2E bridge.
// All other platforms (and non-E2E builds) get the no-op stub.
//
// The bridge is entirely gated by the `E2E` compile-time flag. When
// `--dart-define=E2E=true` is NOT passed, `kE2E` is `false` and every
// method in `E2eBridge` short-circuits to a no-op. The Dart compiler
// tree-shakes the entire bridge out of production builds.
//
// Usage from `lib/main.dart`:
//   ```dart
//   import 'core/e2e/e2e_bridge_stub.dart'
//       if (dart.library.js_interop) 'core/e2e/e2e_bridge_web.dart'
//       as e2e;
//
//   void main() async {
//     WidgetsFlutterBinding.ensureInitialized();
//     await e2e.E2eBridge.maybeInit();
//     runApp(...);
//   }
//   ```
library speakflow.e2e.bridge;

export 'e2e_bridge_stub.dart'
    if (dart.library.js_interop) 'e2e_bridge_web.dart';
