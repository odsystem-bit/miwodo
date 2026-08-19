// widgets/star_rating.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import 'miwodo_svg_icon.dart';

class StarRating extends StatelessWidget {
  const StarRating({
    super.key, 
    required this.noteMoyenne, 
    required this.nbAvis,
    this.compact = false,
  });

  final double noteMoyenne;
  final int nbAvis;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fullStars = noteMoyenne.floor();
    final emptyStars = 5 - fullStars;
    final starSize = compact ? 10.0 : 14.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < fullStars; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: MiwodoSvgIcon(
              'assets/icons/ic_star.svg',
              size: starSize,
              color: AppColors.primaryOrange,
            ),
          ),
        for (int i = 0; i < emptyStars; i++)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: MiwodoSvgIcon(
              'assets/icons/ic_star_empty.svg',
              size: starSize,
              color: AppColors.borderGray,
            ),
          ),
        SizedBox(width: compact ? 3 : 6),
        Text(
          noteMoyenne.toStringAsFixed(1),
          style: GoogleFonts.inter(
            fontSize: compact ? 10 : 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 4),
          Text(
            '($nbAvis avis)',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
