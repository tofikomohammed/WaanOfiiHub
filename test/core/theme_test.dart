import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/core/theme/app_colors.dart';
import 'package:waan_ofii_hub/core/theme/app_theme.dart';

void main() {
  group('AppTheme Tests', () {
    test('lightTheme has correct brightness and primary color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.colorScheme.primary, equals(AppColors.primary));
      expect(theme.useMaterial3, isTrue);
    });

    test('darkTheme has correct brightness and primary color', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, equals(Brightness.dark));
      expect(theme.colorScheme.primary, equals(AppColors.primaryLight));
      expect(theme.useMaterial3, isTrue);
    });
  });
}
