import 'package:flutter/material.dart';

/// Typography definitions for WAAN-OFIIHUB
class AppTextStyles {
  AppTextStyles._();

  static const TextStyle displayLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
  );

  static TextTheme createTextTheme(Color primaryText, Color secondaryText) {
    return TextTheme(
      displayLarge: displayLarge.copyWith(color: primaryText),
      headlineMedium: headlineMedium.copyWith(color: primaryText),
      titleMedium: titleMedium.copyWith(color: primaryText),
      bodyLarge: bodyMedium.copyWith(fontSize: 16, color: primaryText),
      bodyMedium: bodyMedium.copyWith(color: primaryText),
      bodySmall: bodySmall.copyWith(color: secondaryText),
      labelMedium: labelMedium.copyWith(color: secondaryText),
    );
  }
}
