import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/core/config/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    test('has expected app name and version', () {
      expect(EnvConfig.appName, equals('WAAN-OFIIHUB'));
      expect(EnvConfig.appVersion, equals('1.0.0'));
    });

    test(
      'isConfigured returns false when environment variables are not supplied',
      () {
        // In default test runner without dart-define, should be false
        expect(EnvConfig.isConfigured, isFalse);
      },
    );
  });
}
