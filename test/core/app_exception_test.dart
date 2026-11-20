import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/core/errors/app_exception.dart';

void main() {
  group('AppException Tests', () {
    test('maps SocketException to NetworkException', () {
      const error = SocketException('Connection failed');
      final appEx = AppException.from(error);

      expect(appEx, isA<NetworkException>());
      expect(appEx.code, equals('NETWORK_ERROR'));
    });

    test('maps auth-related string to AuthException', () {
      final error = Exception('Invalid login credentials');
      final appEx = AppException.from(error);

      expect(appEx, isA<AuthException>());
      expect(appEx.code, equals('AUTH_ERROR'));
    });

    test('maps permission denied string to PermissionException', () {
      final error = Exception('permission denied for table profiles');
      final appEx = AppException.from(error);

      expect(appEx, isA<PermissionException>());
      expect(appEx.code, equals('PERMISSION_DENIED'));
    });

    test('maps unrecognized errors to UnknownException', () {
      final error = Exception('Some bizarre internal glitch');
      final appEx = AppException.from(error);

      expect(appEx, isA<UnknownException>());
      expect(appEx.code, equals('UNKNOWN_ERROR'));
    });

    test('returns self if already an AppException', () {
      const original = ValidationException('Field is required');
      final appEx = AppException.from(original);

      expect(identical(appEx, original), isTrue);
    });
  });
}
