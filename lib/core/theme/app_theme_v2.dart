// core/theme/app_theme_v2.dart
// Premium Design System - Senior Level Implementation
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_typography.dart';
import 'app_radius.dart';

class AppThemeV2 {
  AppThemeV2._();

  // Premium color palette
  static const Color _primary = Color(0xFFF97316);
  static const Color _primaryDark = Color(0xFFEA580C);
  static const Color _secondary = Color(0xFF6366F1);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _surfaceElevated = Color(0xFFFFFFFF);
  static const Color _background = Color(0xFFF5F5F5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF475569);
  static const Color _textTertiary = Color(0xFF94A3B8);
  static const Color _error = Color(0xFFEF4444);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: _primary,
        onPrimary: Colors.white,
        primaryContainer: Color(0xFFFFEDD5),
        onPrimaryContainer: _primaryDark,
        secondary: _secondary,
        onSecondary: Colors.white,
        surface: _surface,
        onSurface: _textPrimary,
        surfaceContainerHighest: _surfaceElevated,
        onSurfaceVariant: _textSecondary,
        error: _error,
        onError: Colors.white,
        outline: Color(0xFFE2E8F0),
        outlineVariant: Color(0xFFF1F5F9),
        shadow: Color(0xFF0F172A),
      ),
      scaffoldBackgroundColor: _background,
      
      // Typography
      textTheme: TextTheme(
        displayLarge: AppTypography.displayLarge.copyWith(color: _textPrimary),
        displayMedium: AppTypography.displayMedium.copyWith(color: _textPrimary),
        displaySmall: AppTypography.displaySmall.copyWith(color: _textPrimary),
        headlineLarge: AppTypography.headlineLarge.copyWith(color: _textPrimary),
        headlineMedium: AppTypography.headlineMedium.copyWith(color: _textPrimary),
        headlineSmall: AppTypography.headlineSmall.copyWith(color: _textPrimary),
        titleLarge: AppTypography.titleLarge.copyWith(color: _textPrimary),
        titleMedium: AppTypography.titleMedium.copyWith(color: _textPrimary),
        titleSmall: AppTypography.titleSmall.copyWith(color: _textSecondary),
        bodyLarge: AppTypography.bodyLarge.copyWith(color: _textSecondary),
        bodyMedium: AppTypography.bodyMedium.copyWith(color: _textSecondary),
        bodySmall: AppTypography.bodySmall.copyWith(color: _textTertiary),
        labelLarge: AppTypography.labelLarge.copyWith(color: _textPrimary),
        labelMedium: AppTypography.labelMedium.copyWith(color: _textSecondary),
        labelSmall: AppTypography.labelSmall.copyWith(color: _textTertiary),
      ),

      // AppBar premium
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: _textPrimary,
        centerTitle: true,
        titleTextStyle: AppTypography.headlineSmall.copyWith(
          color: _textPrimary,
          fontWeight: FontWeight.w700,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),

      // Cards glassmorphism-ready
      cardTheme: CardThemeData(
        elevation: 0,
        color: _surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        shadowColor: const Color(0xFF0F172A).withAlpha(8),
      ),

      // Buttons premium
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(double.infinity, 56),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.labelLarge,
          minimumSize: const Size(double.infinity, 56),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: AppTypography.labelLarge.copyWith(color: _primary),
        ),
      ),

      // Input fields premium
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: _error, width: 2),
        ),
        hintStyle: AppTypography.bodyLarge.copyWith(color: _textTertiary),
        labelStyle: AppTypography.bodyMedium.copyWith(color: _textSecondary),
        errorStyle: AppTypography.labelSmall.copyWith(color: _error),
        prefixIconColor: _textTertiary,
        suffixIconColor: _textTertiary,
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _surfaceElevated,
        elevation: 0,
        selectedItemColor: _primary,
        unselectedItemColor: _textTertiary,
        selectedLabelStyle: AppTypography.labelSmall,
        unselectedLabelStyle: AppTypography.labelSmall,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),

      // Dividers
      dividerTheme: DividerThemeData(
        color: const Color(0xFFE2E8F0),
        thickness: 1,
        space: 1,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: _primary.withAlpha(16),
        labelStyle: AppTypography.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
      ),
    );
  }
}
