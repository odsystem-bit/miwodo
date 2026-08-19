// widgets/animated_button.dart
// Premium animated button with micro-interactions
import 'package:flutter/material.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_typography.dart';

class AnimatedButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isSecondary;
  final Widget? icon;
  final double? width;

  const AnimatedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isSecondary = false,
    this.icon,
    this.width,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  void _onTapCancel() {
    _controller.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: widget.width ?? double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: widget.isSecondary
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _isPressed
                          ? [const Color(0xFFEA580C), const Color(0xFFF97316)]
                          : [const Color(0xFFF97316), const Color(0xFFFB923C)],
                    ),
              color: widget.isSecondary ? Colors.white : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: widget.isSecondary
                  ? Border.all(color: const Color(0xFFE2E8F0), width: 1.5)
                  : null,
              boxShadow: isDisabled
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFF97316).withAlpha(_isPressed ? 20 : 40),
                        blurRadius: _isPressed ? 8 : 16,
                        offset: const Offset(0, 4),
                        spreadRadius: _isPressed ? -2 : 0,
                      ),
                    ],
            ),
            child: Center(
              child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isSecondary ? const Color(0xFFF97316) : Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          widget.icon!,
                          const SizedBox(width: 12),
                        ],
                        Text(
                          widget.label,
                          style: AppTypography.labelLarge.copyWith(
                            color: widget.isSecondary
                                ? const Color(0xFF0F172A)
                                : Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
