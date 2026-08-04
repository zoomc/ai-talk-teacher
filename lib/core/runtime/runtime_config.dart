/// Compile-time runtime selection for the three supported web distributions.
///
/// The mode is intentionally read once from `APP_MODE`; it cannot be changed
/// by a URL parameter, local storage value, or a browser console command.
/// Production is the safe default when the define is omitted.
enum AppRuntimeMode { production, demo, e2e }

const _compiledAppMode = String.fromEnvironment(
  'APP_MODE',
  defaultValue: 'production',
);

AppRuntimeMode _parseAppMode(String value) {
  switch (value.trim().toLowerCase()) {
    case 'demo':
      return AppRuntimeMode.demo;
    case 'e2e':
      return AppRuntimeMode.e2e;
    case 'production':
    default:
      return AppRuntimeMode.production;
  }
}

/// Immutable, process-wide runtime configuration.
final class RuntimeConfig {
  RuntimeConfig._();

  static final AppRuntimeMode mode = _parseAppMode(_compiledAppMode);

  static bool get isProduction => mode == AppRuntimeMode.production;
  static bool get isDemo => mode == AppRuntimeMode.demo;
  static bool get isE2E => mode == AppRuntimeMode.e2e;
  static bool get isSimulation => isDemo || isE2E;

  /// The production name is kept for backwards compatibility with existing
  /// user data. Demo and E2E use separate IndexedDB/SQLite files.
  static String get databaseName => switch (mode) {
    AppRuntimeMode.production => 'speakflow.db',
    AppRuntimeMode.demo => 'speakflow_demo.db',
    AppRuntimeMode.e2e => 'speakflow_e2e.db',
  };

  static String get storageNamespace => switch (mode) {
    AppRuntimeMode.production => 'prod',
    AppRuntimeMode.demo => 'demo',
    AppRuntimeMode.e2e => 'e2e',
  };

  static String get serviceWorkerScope => isProduction ? '/' : '/';

  /// Demo/E2E never contact user-configured or remote AI providers.
  static bool get externalNetworkAllowed => isProduction;

  /// E2E is a compile-time mode, with the old define retained for backwards
  /// compatibility during local migration of the Playwright command.
  static bool get e2eBridgeEnabled =>
      isE2E || const bool.fromEnvironment('E2E', defaultValue: false);

  static String get displayName => switch (mode) {
    AppRuntimeMode.production => 'Production',
    AppRuntimeMode.demo => 'Demo Simulation',
    AppRuntimeMode.e2e => 'E2E Simulation',
  };
}
