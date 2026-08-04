import 'package:flutter_test/flutter_test.dart';
import 'package:speakflow/core/runtime/runtime_config.dart';

void main() {
  test('omitted APP_MODE is safe production with legacy storage names', () {
    expect(RuntimeConfig.mode, AppRuntimeMode.production);
    expect(RuntimeConfig.databaseName, 'speakflow.db');
    expect(RuntimeConfig.storageNamespace, 'prod');
    expect(RuntimeConfig.externalNetworkAllowed, isTrue);
    expect(RuntimeConfig.isSimulation, isFalse);
  });
}
