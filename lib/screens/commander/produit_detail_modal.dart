// screens/commander/produit_detail_modal.dart
// Fiche détail produit commerçant complète, élégante et interactive

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../models/produit.dart';
import '../../providers/pays_provider.dart';
import '../../services/firestore_service.dart';
import '../../widgets/badge_verifie.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';
import 'commande_providers.dart';

/// Fonction d'ouverture de la fiche produit en BottomSheet immersif
Future<void> showProduitDetailSheet(
  BuildContext context, {
  required Produit produit,
  Prestataire? vendeur,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProduitDetailModal(
      produit: produit,
      initialVendeur: vendeur,
    ),
  );
}

class ProduitDetailModal extends ConsumerStatefulWidget {
  final Produit produit;
  final Prestataire? initialVendeur;

  const ProduitDetailModal({
    super.key,
    required this.produit,
    this.initialVendeur,
  });

  @override
  ConsumerState<ProduitDetailModal> createState() => _ProduitDetailModalState();
}

class _ProduitDetailModalState extends ConsumerState<ProduitDetailModal> {
  int _quantity = 1;
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();
  Prestataire? _vendeur;
  bool _loadingVendeur = false;

  @override
  void initState() {
    super.initState();
    _vendeur = widget.initialVendeur;
    if (_vendeur == null && widget.produit.prestataireId.isNotEmpty) {
      _loadVendeur();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVendeur() async {
    setState(() => _loadingVendeur = true);
    try {
      final p = await FirestoreService.instance.getPrestataire(widget.produit.prestataireId);
      if (mounted) {
        setState(() {
          _vendeur = p;
          _loadingVendeur = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVendeur = false);
    }
  }

  List<String> get _allImages {
    final list = <String>[];
    if (widget.produit.imageUrl != null && widget.produit.imageUrl!.isNotEmpty) {
      list.add(widget.produit.imageUrl!);
    }
    for (final img in widget.produit.images) {
      if (img.isNotEmpty && !list.contains(img)) {
        list.add(img);
      }
    }
    return list;
  }

  void _increment() {
    HapticFeedback.selectionClick();
    setState(() => _quantity++);
  }

  void _decrement() {
    if (_quantity > 1) {
      HapticFeedback.selectionClick();
      setState(() => _quantity--);
    }
  }

  void _ajouterAuPanier() {
    HapticFeedback.mediumImpact();
    ref.read(cartProvider.notifier).addMultiple(widget.produit, _quantity);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$_quantity x ${widget.produit.nom} ajouté au panier',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Voir panier',
          textColor: AppColors.primaryOrange,
          onPressed: () => context.push('/panier'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pays = ref.watch(paysSelectionneProvider);
    final symbole = _vendeur?.symbole.isNotEmpty == true 
        ? _vendeur!.symbole 
        : (pays?.symbole ?? 'F CFA');
    final images = _allImages;
    final totalLigne = widget.produit.prix * _quantity;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Poignée de glissement & Barre d'en-tête
              Container(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.borderGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // Contenu défilable
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Galerie Photos
                    _buildGallery(images),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges Disponibilité & Catégorie
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: widget.produit.estDisponible
                                      ? AppColors.successGreen.withAlpha(25)
                                      : AppColors.errorRed.withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.produit.estDisponible
                                          ? Icons.check_circle_rounded
                                          : Icons.cancel_rounded,
                                      size: 14,
                                      color: widget.produit.estDisponible
                                          ? AppColors.successGreen
                                          : AppColors.errorRed,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.produit.estDisponible ? 'En stock' : 'Rupture de stock',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: widget.produit.estDisponible
                                          ? AppColors.successGreen
                                          : AppColors.errorRed,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.produit.categorie.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceGray,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    widget.produit.categorie,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Nom du produit
                          Text(
                            widget.produit.nom,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Prix du produit
                          Text(
                            '${widget.produit.prix.toStringAsFixed(0)} $symbole',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Divider(color: AppColors.borderGray, height: 1),
                          const SizedBox(height: 16),

                          // Carte Commerçant / Boutique
                          _buildCommercantCard(context),
                          const SizedBox(height: 20),

                          // Description du produit
                          Text(
                            'Description du produit',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGray,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              widget.produit.description?.isNotEmpty == true
                                  ? widget.produit.description!
                                  : 'Aucune description détaillée renseignée pour cet article.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: widget.produit.description?.isNotEmpty == true
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Barre d'action fixe en bas
              _buildBottomActionBar(symbole, totalLigne),
            ],
          ),
        );
      },
    );
  }

  // ─── GALERIE D'IMAGES ──────────────────────────────────────────────────────
  Widget _buildGallery(List<String> images) {
    if (images.isEmpty) {
      return Container(
        height: 260,
        color: AppColors.surfaceGray,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 48, color: AppColors.borderGray),
              SizedBox(height: 8),
              Text('Aucune image disponible', style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (context, index) {
              return CachedNetworkImage(
                imageUrl: images[index],
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceGray,
                  child: const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.surfaceGray,
                  child: const Center(child: Icon(Icons.broken_image, size: 48, color: Colors.grey)),
                ),
              );
            },
          ),
        ),

        // Bouton Fermer en haut à droite
        Positioned(
          top: 12,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),

        // Indicateur de points carrousel si plusieurs photos
        if (images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => Container(
                  width: _currentImageIndex == i ? 20 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _currentImageIndex == i ? AppColors.primaryOrange : Colors.white70,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── CARTE COMMERÇANT / BOUTIQUE ───────────────────────────────────────────
  Widget _buildCommercantCard(BuildContext context) {
    if (_loadingVendeur) {
      return Container(
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final vendeur = _vendeur;
    final nomBoutique = vendeur?.nomCommercial?.isNotEmpty == true
        ? vendeur!.nomCommercial!
        : (vendeur != null ? '${vendeur.prenom} ${vendeur.nom}' : 'Commerçant Miwodo');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray.withAlpha(60)),
      ),
      child: Row(
        children: [
          // Photo du commerçant / boutique
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: vendeur?.photoUrl != null && vendeur!.photoUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: vendeur.photoUrl!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(width: 50, height: 50, color: AppColors.borderGray),
                    errorWidget: (_, __, ___) => _buildAvatarPlaceholder(),
                  )
                : _buildAvatarPlaceholder(),
          ),
          const SizedBox(width: 12),

          // Infos commerçant
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nomBoutique,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (vendeur?.verifie == true) ...[
                      const SizedBox(width: 4),
                      const BadgeVerifie(size: 14),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vendeur?.zone.isNotEmpty == true ? vendeur!.zone : 'Lomé, Togo',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bouton voir la boutique
          if (vendeur != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/profil/${vendeur.id}');
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Boutique',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: AppColors.primaryOrangeLight,
      child: const Center(
        child: MiwodoSvgIcon('assets/icons/ic_vendeur.svg', size: 24, color: AppColors.primaryOrange),
      ),
    );
  }

  // ─── BARRE D'ACTION EN BAS ─────────────────────────────────────────────────
  Widget _buildBottomActionBar(String symbole, double totalLigne) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sélecteur de quantité
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceGray,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderGray),
            ),
            child: Row(
              children: [
                _buildQuantityBtn(
                  icon: Icons.remove_rounded,
                  onTap: _decrement,
                  enabled: _quantity > 1,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '$_quantity',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _buildQuantityBtn(
                  icon: Icons.add_rounded,
                  onTap: _increment,
                  enabled: widget.produit.estDisponible,
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Bouton Ajouter au Panier
          Expanded(
            child: MiwodoButton(
              label: widget.produit.estDisponible
                  ? 'Ajouter • ${totalLigne.toStringAsFixed(0)} $symbole'
                  : 'Indisponible',
              icon: 'assets/icons/ic_cart.svg',
              onPressed: widget.produit.estDisponible ? _ajouterAuPanier : null,
              fullWidth: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.borderGray,
        ),
      ),
    );
  }
}
