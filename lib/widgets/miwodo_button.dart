// widgets/miwodo_button.dart
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'miwodo_svg_icon.dart';

enum MiwodoButtonVariant { primary, secondary, danger }

class MiwodoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final MiwodoButtonVariant variant;
  final bool isLoading;
  final double? width;
  final bool fullWidth;
  final String? icon;

  const MiwodoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = MiwodoButtonVariant.primary,
    this.isLoading = false,
    this.width,
    this.fullWidth = false,
    this.icon,
  });

  Color get _backgroundColor {
    switch (variant) {
      case MiwodoButtonVariant.primary:
        return AppColors.primaryOrange;
      case MiwodoButtonVariant.secondary:
        return Colors.transparent;
      case MiwodoButtonVariant.danger:
        return AppColors.errorRed;
    }
  }

  Color get _textColor {
    switch (variant) {
      case MiwodoButtonVariant.primary:
        return Colors.white;
      case MiwodoButtonVariant.secondary:
        return AppColors.primaryOrange;
      case MiwodoButtonVariant.danger:
        return Colors.white;
    }
  }

  BorderSide? get _borderSide {
    switch (variant) {
      case MiwodoButtonVariant.secondary:
        return BorderSide(color: AppColors.primaryOrange, width: 1.5);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;

    final Widget content = isLoading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(_textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                MiwodoSvgIcon(icon!, size: 18, color: _textColor),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    final ButtonStyle style = ButtonStyle(
      minimumSize: WidgetStateProperty.all<Size>(const Size.fromHeight(52)),
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (variant == MiwodoButtonVariant.secondary) return Colors.transparent;
        if (states.contains(WidgetState.disabled))
          return _backgroundColor.withAlpha(128);
        return _backgroundColor;
      }),
      foregroundColor: WidgetStateProperty.all<Color>(_textColor),
      overlayColor: WidgetStateProperty.all<Color>(Colors.black12),
      elevation: WidgetStateProperty.all<double>(
        variant == MiwodoButtonVariant.secondary ? 0 : 2,
      ),
      shape: WidgetStateProperty.all<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: _borderSide ?? BorderSide.none,
        ),
      ),
    );

    Widget button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: style,
      child: content,
    );

    if (fullWidth) {
      button = SizedBox(width: double.infinity, child: button);
    } else if (width != null) {
      button = SizedBox(width: width, child: button);
    }

    if (disabled) {
      return Opacity(opacity: 0.5, child: button);
    }

    return button;
  }
}
