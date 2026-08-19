// widgets/miwodo_svg_icon.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MiwodoSvgIcon extends StatelessWidget {
  final String assetPath;
  final double size;
  final Color? color;

  const MiwodoSvgIcon(
    this.assetPath, {
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
