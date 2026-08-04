# Runtime modes

`APP_MODE` is a compile-time define with three values:

| Build | Define | Provider path | Database | Network |
|---|---|---|---|---|
| Production | omitted or `production` | user-configured production gateways | `speakflow.db` | provider requests allowed |
| Demo | `demo` | deterministic simulation gateways | `speakflow_demo.db` | external AI requests forbidden |
| E2E | `e2e` | deterministic simulation gateways | `speakflow_e2e.db` | external AI requests forbidden |

The single source of truth is `lib/core/runtime/runtime_config.dart`. Pages read
capabilities and gateways from `lib/shared/providers.dart`; they must not infer a
mode from a URL, local storage, a profile row, or a browser flag.

Production keeps the existing `speakflow.db` name for compatibility. Demo and E2E
also prefix secure-storage keys and TTS cache files with their own namespace, so
saved production credentials and audio cannot be reused by a simulation build.

Simulation mode bypasses onboarding/profile requirements and displays a persistent
mode banner. The banner exposes the fixture selector, reset action, and a clear
statement that no real AI request is made. `/lab/avatar` is registered only in
Demo/E2E builds and has no production route.

## Build commands

```bash
flutter build web --release --dart-define=APP_MODE=production --base-href=/talk/
flutter build web --release --dart-define=APP_MODE=demo --base-href=/talk-demo/
flutter build web --release --dart-define=APP_MODE=e2e
```

Production API configuration remains user-controlled. Demo/E2E direct calls to
`LlmService`, `SttService`, `TtsService`, connection probes, and voice listing are
guarded as a second line of defence; the normal UI uses the simulation gateways.
