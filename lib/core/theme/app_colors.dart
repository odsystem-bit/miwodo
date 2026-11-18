// core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryOrange = Color(0xFFF97316);
  static const Color primaryOrangeDark = Color(0xFFEA6C0A);
  static const Color primaryOrangeLight = Color(0xFFFFF4ED);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surfaceGray = Color(0xFFF9F9F9);
  static const Color borderGray = Color(0xFFEEEEEE);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color warningYellow = Color(0xFFF59E0B);

  // Brand Identity (Miwodo Logo & Affiches Officielles)
  static const Color brandOrange = Color(0xFFFF7A00);
  static const Color brandMagenta = Color(0xFFE11D48);
  static const Color brandPurple = Color(0xFFC026D3);
  static const Color brandDarkNavy = Color(0xFF0F172A);
  static const Color brandNavySurface = Color(0xFF1E293B);

  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient brandGradientHorizontal = LinearGradient(
    colors: [Color(0xFFFF7A00), Color(0xFFE11D48)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}
