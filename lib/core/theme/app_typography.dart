// core/theme/app_typography.dart
// Design System Typography - Senior Level
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Typography scale following 1.25 ratio (Major Third)
/// Base: 16px | Scale: 16 → 20 → 25 → 31.25 → 39.06 → 48.83
class AppTypography {
  AppTypography._();

  // Font families
  static final String _displayFont = GoogleFonts.inter().fontFamily!;
  static final String _bodyFont = GoogleFonts.inter().fontFamily!;

  // Display - For headlines, hero text
  static TextStyle get displayLarge => TextStyle(
    fontFamily: _displayFont,
    fontSize: 48,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.02,
  );

  static TextStyle get displayMedium => TextStyle(
    fontFamily: _displayFont,
    fontSize: 39,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.01,
  );

  static TextStyle get displaySmall => TextStyle(
    fontFamily: _displayFont,
    fontSize: 31,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.01,
  );

  // Headline - For section titles
  static TextStyle get headlineLarge => TextStyle(
    fontFamily: _displayFont,
    fontSize: 31,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.01,
  );

  static TextStyle get headlineMedium => TextStyle(
    fontFamily: _displayFont,
    fontSize: 25,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  static TextStyle get headlineSmall => TextStyle(
    fontFamily: _displayFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    letterSpacing: 0,
  );

  // Title - For cards, list items
  static TextStyle get titleLarge => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0,
  );

  static TextStyle get titleMedium => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
    letterSpacing: 0.01,
  );

  static TextStyle get titleSmall => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.01,
  );

  // Body - For paragraphs, descriptions
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.01,
  );

  static TextStyle get bodyMedium => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0.01,
  );

  static TextStyle get bodySmall => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    letterSpacing: 0.02,
  );

  // Label - For buttons, captions, badges
  static TextStyle get labelLarge => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.02,
  );

  static TextStyle get labelMedium => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.02,
  );

  static TextStyle get labelSmall => TextStyle(
    fontFamily: _bodyFont,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.03,
    textBaseline: TextBaseline.ideographic,
  );
}
