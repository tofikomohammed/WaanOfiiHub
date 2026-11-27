import 'package:flutter/material.dart';

/// Semantic color palette for WAAN-OFIIHUB matching the premium design.html
class AppColors {
  AppColors._();

  // Primary Brand Colors (Deep Forest Emerald Green)
  static const Color primary = Color(0xFF0B3B32);
  static const Color primaryLight = Color(0xFF147A66);
  static const Color primaryDark = Color(0xFF06251F);
  static const Color primaryContainer = Color(0xFFE1ECE7);
  static const Color onPrimaryContainer = Color(0xFF0B3B32);

  // Secondary Accent (Warm Amber / Gold)
  static const Color secondary = Color(0xFFF5B738);
  static const Color secondaryLight = Color(0xFFF8C864);
  static const Color secondaryDark = Color(0xFFD6981C);

  // Palette Specialties from design.html
  static const Color accentAmber = Color(0xFFF5B738);
  static const Color accentAmberContainer = Color(0xFFFDF0D5);
  static const Color mintContainer = Color(0xFFE1ECE7);
  static const Color coralContainer = Color(0xFFFCE8E6);
  static const Color sidebarDark = Color(0xFF0B3B32);
  static const Color sidebarItemText = Color(0xFFA3C6B9);
  static const Color sidebarActivePill = Colors.white;

  // Status & Feedback
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF5B738);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Light Mode Surfaces
  static const Color lightBackground = Color(0xFFEEF3F0);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFDCE5E1);
  static const Color lightTextPrimary = Color(0xFF0F2620);
  static const Color lightTextSecondary = Color(0xFF5A7067);
  static const Color lightTextMuted = Color(0xFF8BA097);

  // Dark Mode Surfaces
  static const Color darkBackground = Color(0xFF081C18);
  static const Color darkSurface = Color(0xFF0E2A24);
  static const Color darkCard = Color(0xFF0E2A24);
  static const Color darkBorder = Color(0xFF1B423A);
  static const Color darkTextPrimary = Color(0xFFF0F5F3);
  static const Color darkTextSecondary = Color(0xFFA3C6B9);
  static const Color darkTextMuted = Color(0xFF6B8A7E);
}
