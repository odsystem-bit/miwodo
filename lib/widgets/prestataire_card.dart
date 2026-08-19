// widgets/prestataire_card.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/categories.dart';
import '../core/theme/app_colors.dart';
import '../models/prestataire.dart';
import 'badge_verifie.dart';
import 'miwodo_svg_icon.dart';
import 'star_rating.dart';

class PrestataireCard extends StatelessWidget {
  final Prestataire prestataire;
  final VoidCallback onTap;
  final bool compact;

  const PrestataireCard({
    super.key,
    required this.prestataire,
    required this.onTap,
    this.compact = false,
  });

  String get _categoryLabel {
    final enumCategory = Categorie.values.firstWhere(
      (c) => c.name == prestataire.categorie,
      orElse: () => Categorie.artisan,
    );
    return enumCategory.label;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: compact ? _buildCompactCard() : _buildNormalCard(),
    );
  }

  Widget _buildNormalCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _buildAvatar(radius: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${prestataire.nom} ${prestataire.prenom}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (prestataire.estVerifie) const SizedBox(width: 8),
                    if (prestataire.estVerifie) const BadgeVerifie(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const MiwodoSvgIcon('assets/icons/ic_briefcase.svg', size: 14, color: Color(0xFF9CA3AF)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$_categoryLabel · ${prestataire.zone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StarRating(noteMoyenne: prestataire.noteMoyenne, nbAvis: prestataire.nombreAvis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: prestataire.estDisponible ? AppColors.successGreen.withAlpha(30) : AppColors.errorRed.withAlpha(30),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  prestataire.estDisponible ? 'Disponible' : 'Occupé',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: prestataire.estDisponible ? AppColors.successGreen : AppColors.errorRed,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (prestataire.estVerifie)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'SPONSORISÉ',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCard() {
    final hasPortfolio = prestataire.photosPortfolio.isNotEmpty;
    final portfolioImage = hasPortfolio 
        ? prestataire.photosPortfolio.first 
        : (prestataire.photoUrl != null && prestataire.photoUrl!.isNotEmpty ? prestataire.photoUrl : null);
    
    return Container(
      width: 160,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image de travail ou avatar
          SizedBox(
            height: 80,
            child: portfolioImage != null
                ? CachedNetworkImage(
                    imageUrl: portfolioImage,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.primaryOrangeLight,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.primaryOrangeLight,
                      child: const Center(
                        child: Icon(Icons.image, color: AppColors.primaryOrange, size: 32),
                      ),
                    ),
                  )
                : Container(
                    color: AppColors.primaryOrangeLight,
                    child: Center(child: _buildAvatar(radius: 24)),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(radius: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${prestataire.prenom} ${prestataire.nom}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (prestataire.estVerifie)
                      const Icon(Icons.verified, size: 14, color: AppColors.primaryOrange),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _categoryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StarRating(noteMoyenne: prestataire.noteMoyenne, nbAvis: prestataire.nombreAvis, compact: true),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: prestataire.estDisponible ? AppColors.successGreen.withAlpha(30) : AppColors.errorRed.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        prestataire.estDisponible ? '✓' : '✗',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: prestataire.estDisponible ? AppColors.successGreen : AppColors.errorRed,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double radius}) {
    final avatar = prestataire.photoUrl;
    if (avatar != null && avatar.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: avatar,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: radius * 2,
            height: radius * 2,
            color: AppColors.primaryOrangeLight,
            child: Center(
              child: SizedBox(
                width: radius - 4,
                height: radius - 4,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _buildInitials(radius),
        ),
      );
    }

    return _buildInitials(radius);
  }

  Widget _buildInitials(double radius) {
    final initials = prestataire.nom.isNotEmpty ? prestataire.nom[0].toUpperCase() : 'P';
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: AppColors.primaryOrangeLight,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.inter(
            fontSize: radius - 8,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryOrange,
          ),
        ),
      ),
    );
  }
}
