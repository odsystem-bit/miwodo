// widgets/glass_card.dart
// Glassmorphism card widget - Premium UI
import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blur;
  final double opacity;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? shadows;
  final Border? border;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blur = 20,
    this.opacity = 0.7,
    this.backgroundColor,
    this.borderRadius,
    this.shadows,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.lg),
        boxShadow: shadows ?? AppShadows.md,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.white.withAlpha((255 * opacity).round()),
              borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.lg),
              border: border ?? Border.all(
                color: Colors.white.withAlpha(40),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Simplified frosted container without clip
class FrostedContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double blur;
  final double opacity;
  final BorderRadius? borderRadius;

  const FrostedContainer({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.blur = 12,
    this.opacity = 0.8,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withAlpha((255 * opacity).round()),
          borderRadius: borderRadius,
        ),
        child: child,
      ),
    );
  }
}
