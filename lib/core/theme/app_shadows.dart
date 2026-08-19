// core/theme/app_shadows.dart
// Sophisticated shadow system for depth hierarchy
import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  // Elevation 0 - Flat
  static const List<BoxShadow> none = [];

  // Elevation 1 - Subtle (cards at rest)
  static final List<BoxShadow> xs = [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(4),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  // Elevation 2 - Light (hovered cards)
  static final List<BoxShadow> sm = [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(8),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(4),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  // Elevation 3 - Medium (floating elements)
  static final List<BoxShadow> md = [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(12),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(6),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  // Elevation 4 - High (modals, drawers)
  static final List<BoxShadow> lg = [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(16),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(8),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // Elevation 5 - Ultra (dialogs, overlays)
  static final List<BoxShadow> xl = [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(24),
      blurRadius: 32,
      offset: const Offset(0, 16),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(12),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // Special: Glassmorphism glow
  static final List<BoxShadow> glassGlow = [
    BoxShadow(
      color: const Color(0xFFF97316).withAlpha(20),
      blurRadius: 40,
      spreadRadius: -8,
      offset: const Offset(0, 8),
    ),
  ];

  // Special: Inner shadow effect
  static final List<BoxShadow> inner = [
    BoxShadow(
      color: const Color(0xFF0F172A).withAlpha(8),
      blurRadius: 4,
      offset: const Offset(0, 2),
      blurStyle: BlurStyle.inner,
    ),
  ];
}
