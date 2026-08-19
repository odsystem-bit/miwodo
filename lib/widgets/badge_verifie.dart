// widgets/badge_verifie.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import 'miwodo_svg_icon.dart';

class BadgeVerifie extends StatelessWidget {
  const BadgeVerifie({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiwodoSvgIcon(
          'assets/icons/ic_verified.svg',
          size: 16,
          color: AppColors.primaryOrange,
        ),
        const SizedBox(width: 4),
        Text(
          'Vérifié',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.primaryOrange,
          ),
        ),
      ],
    );
  }
}
