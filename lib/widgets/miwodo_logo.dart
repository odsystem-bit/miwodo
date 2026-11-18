// widgets/miwodo_logo.dart
// Miwodo logo widget - reusable across the app
import 'package:flutter/material.dart';
import '../core/theme/app_radius.dart';

class MiwodoLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double textSpacing;

  const MiwodoLogo({
    super.key,
    this.size = 140,
    this.showText = true,
    this.textSpacing = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo container
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF97316), // Orange primary
                Color(0xFFFB923C), // Orange light
              ],
            ),
            borderRadius: BorderRadius.circular(size * 0.18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withAlpha(60),
                blurRadius: size * 0.3,
                offset: Offset(0, size * 0.12),
              ),
            ],
          ),
          child: Center(
            child: Text(
              'M',
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -size * 0.02,
                shadows: [
                  Shadow(
                    color: const Color(0xFF0F172A).withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(height: textSpacing),
          Text(
            'MIWODO',
            style: TextStyle(
              fontSize: size * 0.2,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: size * 0.03,
            ),
          ),
        ],
      ],
    );
  }
}

// Smaller logo for app bar, headers
class MiwodoLogoCompact extends StatelessWidget {
  final double size;

  const MiwodoLogoCompact({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF97316),
            Color(0xFFFB923C),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Center(
        child: Text(
          'M',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// Logo with glow effect for premium screens
class MiwodoLogoGlowing extends StatelessWidget {
  final double size;

  const MiwodoLogoGlowing({super.key, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF97316),
            Color(0xFFFB923C),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withAlpha(80),
            blurRadius: size * 0.5,
            spreadRadius: size * 0.05,
            offset: Offset(0, size * 0.15),
          ),
          BoxShadow(
            color: const Color(0xFFF97316).withAlpha(40),
            blurRadius: size * 0.8,
            spreadRadius: size * 0.1,
          ),
        ],
      ),
      child: Center(
        child: Text(
          'M',
          style: TextStyle(
            fontSize: size * 0.5,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }
}
