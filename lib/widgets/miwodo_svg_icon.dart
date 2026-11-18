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

  String get _resolvedPath {
    final clean = assetPath.trim();
    if (clean == 'ic_truck.svg' || clean.endsWith('/ic_truck.svg')) {
      return 'assets/icons/ic_livreur.svg';
    }
    if (clean == 'ic_sad.svg' || clean.endsWith('/ic_sad.svg')) {
      return 'assets/icons/ic_info.svg';
    }
    if (!clean.startsWith('assets/')) {
      return 'assets/icons/$clean';
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _resolvedPath,
      width: size,
      height: size,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
    );
  }
}
