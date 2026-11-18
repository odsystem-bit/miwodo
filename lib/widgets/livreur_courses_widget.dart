// widgets/livreur_courses_widget.dart
import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../models/commande.dart';
import '../models/demande_retrait.dart';
import '../models/prestataire.dart';
import '../services/commande_vendeur_service.dart';
import '../services/retrait_service.dart';
import 'miwodo_button.dart';
import 'miwodo_svg_icon.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final livreurCoursesProvider = StreamProvider.family<List<CommandeVendeur>, String>((ref, livreurId) {
  return CommandeVendeurService.instance.streamCommandesLivreur(livreurId);
});

final livreurSoldeProvider = StreamProvider.family<SoldeVendeur, String>((ref, livreurId) {
  return CommandeVendeurService.instance.streamSolde(livreurId);
});

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL
// ═══════════════════════════════════════════════════════════════════════════

class LivreurCoursesWidget extends ConsumerStatefulWidget {
  final Prestataire prestataire;

  const LivreurCoursesWidget({super.key, required this.prestataire});

  @override
  ConsumerState<LivreurCoursesWidget> createState() => _LivreurCoursesWidgetState();
}

class _LivreurCoursesWidgetState extends ConsumerState<LivreurCoursesWidget> {
  int _selectedFilterIndex = 0; // 0: Toutes, 1: En cours, 2: À valider, 3: Terminées

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(livreurCoursesProvider(widget.prestataire.id));
    final soldeAsync = ref.watch(livreurSoldeProvider(widget.prestataire.id));

    return Column(
      children: [
        // Solde card
        soldeAsync.when(
          data: (solde) => _SoldeCard(solde: solde, prestataire: widget.prestataire),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),

        // Filtres par statut
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Toutes', 0),
                const SizedBox(width: 8),
                _buildFilterChip('En cours', 1),
                const SizedBox(width: 8),
                _buildFilterChip('À valider', 2),
                const SizedBox(width: 8),
                _buildFilterChip('Terminées', 3),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Liste des courses
        Expanded(
          child: coursesAsync.when(
            data: (courses) {
              if (courses.isEmpty) {
                return _EmptyCoursesView();
              }

              final filtered = courses.where((c) {
                switch (_selectedFilterIndex) {
                  case 1: // En cours
                    return c.statut == StatutCommande.paye ||
                        c.statut == StatutCommande.accepte ||
                        c.statut == StatutCommande.enRoute;
                  case 2: // À valider
                    return c.statut == StatutCommande.livre;
                  case 3: // Terminées
                    return c.statut == StatutCommande.confirme ||
                        c.statut == StatutCommande.forceConfirme;
                  default:
                    return true;
                }
              }).toList();

              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'Aucune course dans cet état.',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  ),
                );
              }

              // Trier : les nouvelles et en cours en tête
              filtered.sort((a, b) => a.statut.index.compareTo(b.statut.index));

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final course = filtered[index];
                  return _CourseCard(
                    course: course,
                    prestataire: widget.prestataire,
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primaryOrange),
            ),
            error: (e, _) => Center(
              child: Text(
                'Erreur: $e',
                style: GoogleFonts.inter(color: AppColors.errorRed),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.brandDarkNavy : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brandDarkNavy : AppColors.borderGray,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.brandDarkNavy.withAlpha(40),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOLDE CARD AVEC CHARTE MIWODO
// ═══════════════════════════════════════════════════════════════════════════

class _SoldeCard extends StatelessWidget {
  final SoldeVendeur solde;
  final Prestataire prestataire;

  const _SoldeCard({required this.solde, required this.prestataire});

  @override
  Widget build(BuildContext context) {
    final devise = prestataire.symbole.isNotEmpty ? prestataire.symbole : 'F CFA';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandMagenta.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.two_wheeler, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Portefeuille Livreur',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Escrow Sécurisé',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${solde.soldeDisponible} $devise',
            style: GoogleFonts.inter(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 13, color: Colors.white70),
              const SizedBox(width: 4),
              Text(
                '${solde.soldeEnAttente} $devise en attente de livraison',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withAlpha(200)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: solde.soldeDisponible > 0
                  ? () => _showRetraitDialog(context, solde)
                  : null,
              icon: const Icon(Icons.arrow_downward_rounded, size: 16),
              label: Text(
                'Demander un retrait Mobile Money',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.brandDarkNavy,
                disabledBackgroundColor: Colors.white.withAlpha(120),
                disabledForegroundColor: AppColors.brandDarkNavy.withAlpha(120),
                padding: const EdgeInsets.symmetric(vertical: 11),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showRetraitDialog(BuildContext context, SoldeVendeur solde) {
    final montantController = TextEditingController();
    final numeroController = TextEditingController();
    final nomController = TextEditingController();
    MethodePaiement methode = MethodePaiement.mobileMoney;
    bool isSubmitting = false;
    final symbole = prestataire.symbole.isNotEmpty ? prestataire.symbole : 'F CFA';
    const retraitMinimum = 1000;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Retrait de gains course',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Disponible:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      Text('${solde.soldeDisponible} $symbole', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant à retirer ($symbole)',
                    hintText: 'Min: $retraitMinimum $symbole',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Méthode de paiement', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...MethodePaiement.values.map((m) => RadioListTile<MethodePaiement>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      groupValue: methode,
                      title: Text(m.label, style: GoogleFonts.inter(fontSize: 13)),
                      onChanged: (v) => setDialogState(() => methode = v!),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: numeroController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: methode == MethodePaiement.virementBancaire
                        ? 'Numéro de compte (RIB)'
                        : 'Numéro T-Money / Moov / Wave',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du compte (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final montant = int.tryParse(montantController.text.trim());
                      if (montant == null || montant <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Montant invalide'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (montant < retraitMinimum) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Minimum: $retraitMinimum $symbole'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (montant > solde.soldeDisponible) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Montant supérieur au solde disponible'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (numeroController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Numéro de paiement requis'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await RetraitService.instance.creerDemandeRetrait(
                          prestataireId: prestataire.id,
                          prestataireNom: '${prestataire.prenom} ${prestataire.nom}',
                          source: RetraitSource.soldeLivreur,
                          montant: montant,
                          devise: prestataire.devise,
                          methodePaiement: methode,
                          numeroDestinataire: numeroController.text.trim(),
                          nomDestinataire: nomController.text.trim().isEmpty ? null : nomController.text.trim(),
                          retraitMinimum: retraitMinimum,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demande de retrait enregistrée avec succès !'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmer le retrait'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EMPTY VIEW
// ═══════════════════════════════════════════════════════════════════════════

class _EmptyCoursesView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryOrangeLight,
                shape: BoxShape.circle,
              ),
              child: const MiwodoSvgIcon('assets/icons/ic_livreur.svg', size: 48, color: AppColors.primaryOrange),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucune course assignée',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Dès qu\'un client commande un produit dans votre zone, la notification apparaîtra ici.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COURSE CARD ULTRA PROFESSIONNELLE
// ═══════════════════════════════════════════════════════════════════════════

class _CourseCard extends ConsumerStatefulWidget {
  final CommandeVendeur course;
  final Prestataire prestataire;

  const _CourseCard({required this.course, required this.prestataire});

  @override
  ConsumerState<_CourseCard> createState() => _CourseCardState();
}

class _CourseCardState extends ConsumerState<_CourseCard> {
  bool _isLoading = false;
  Timer? _timer;
  Duration _tempsRestant = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _CourseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.course.statut != widget.course.statut) {
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (widget.course.statut == StatutCommande.livre && !widget.course.confirmationClient) {
      _tempsRestant = widget.course.tempsRestantConfirmation;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {
            _tempsRestant = widget.course.tempsRestantConfirmation;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ─── ACTIONS COMMUNICATION & NAVIGATION ─────────────────────────────────────

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone, {String message = ''}) async {
    var clean = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!clean.startsWith('228') && clean.length == 8) {
      clean = '228$clean';
    }
    final uri = Uri.parse('https://wa.me/$clean?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openGpsNavigation(GeoPoint? coords, String address) async {
    Uri? uri;
    if (coords != null) {
      uri = Uri.parse('google.navigation:q=${coords.latitude},${coords.longitude}');
      if (!await canLaunchUrl(uri)) {
        uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${coords.latitude},${coords.longitude}');
      }
    } else if (address.isNotEmpty) {
      final query = Uri.encodeComponent(address);
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    }
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir l\'application GPS.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final symbole = widget.prestataire.symbole.isNotEmpty ? widget.prestataire.symbole : 'F CFA';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _borderColor(course.statut),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── HEADER : Numéro, Statut & Gain Livreur ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _headerBgColor(course.statut),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _StatutBadge(statut: course.statut),
                    const SizedBox(width: 8),
                    Text(
                      course.numero,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandDarkNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monetization_on_outlined, size: 13, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        '+ ${course.fraisLivraison} $symbole',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── ÉTAPE 1 : RAMASSAGE COMMERÇANT ──
                _buildPointSection(
                  stepNumber: '1',
                  stepTitle: 'Ramassage Colis (Commerçant)',
                  titleColor: Colors.deepPurple,
                  name: course.vendeurBoutiqueNom ?? course.vendeurNom,
                  subtitle: 'Commerçant / Vendeur',
                  phone: course.vendeurTelephone,
                  isVendor: true,
                ),

                // Ligne de connexion pointillée
                Padding(
                  padding: const EdgeInsets.only(left: 14, top: 4, bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 2,
                        height: 24,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_downward, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Acheminement',
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                // ── ÉTAPE 2 : LIVRAISON CLIENT ──
                _buildPointSection(
                  stepNumber: '2',
                  stepTitle: 'Livraison Destination (Client)',
                  titleColor: AppColors.primaryOrangeDark,
                  name: course.clientNom,
                  subtitle: '${course.clientZone}${course.clientAdresseTexte.isNotEmpty ? ' - ${course.clientAdresseTexte}' : ''}',
                  phone: course.clientTelephone,
                  isVendor: false,
                  coords: course.clientCoords,
                  fullAddress: '${course.clientZone} ${course.clientAdresseTexte}',
                ),

                const SizedBox(height: 12),

                // ── ARTICLES RÉCAPITULATIF ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(
                                'Contenu du colis (${course.articles.length} produit${course.articles.length > 1 ? 's' : ''})',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          Text(
                            'Valeur: ${course.sousTotalArticles} $symbole',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...course.articles.map((art) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    art.nom,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'x${art.quantite}',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── ACTIONS SELON STATUT ──
                _buildActions(course),

                // ── TIMER CONFIRMATION RESTANT ──
                if (course.statut == StatutCommande.livre && !course.confirmationClient)
                  _buildConfirmationTimer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointSection({
    required String stepNumber,
    required String stepTitle,
    required Color titleColor,
    required String name,
    required String subtitle,
    required String? phone,
    required bool isVendor,
    GeoPoint? coords,
    String? fullAddress,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cercle avec numéro d'étape
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: titleColor.withAlpha(25),
            shape: BoxShape.circle,
            border: Border.all(color: titleColor, width: 1.5),
          ),
          child: Center(
            child: Text(
              stepNumber,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: titleColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stepTitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name.isNotEmpty ? name : (isVendor ? 'Boutique commerçant' : 'Client'),
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (!isVendor && (coords != null || (fullAddress != null && fullAddress.isNotEmpty))) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => _openGpsNavigation(coords, fullAddress ?? ''),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.infoBlue.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.navigation_rounded, size: 14, color: AppColors.infoBlue),
                        const SizedBox(width: 4),
                        Text(
                          'Ouvrir itinéraire GPS (Google Maps)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.infoBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (phone != null && phone.isNotEmpty) ...[
          IconButton(
            onPressed: () => _callPhone(phone),
            icon: const Icon(Icons.phone, size: 18, color: AppColors.successGreen),
            tooltip: 'Appeler',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _openWhatsApp(
              phone,
              message: isVendor
                  ? 'Bonjour, je suis votre livreur Miwodo pour la commande ${widget.course.numero}.'
                  : 'Bonjour, je suis votre livreur Miwodo pour la livraison de votre commande ${widget.course.numero}.',
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primaryOrange),
            tooltip: 'WhatsApp',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ],
    );
  }

  Widget _buildActions(CommandeVendeur course) {
    switch (course.statut) {
      case StatutCommande.paye:
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : () => _refuserCourse(course),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  side: const BorderSide(color: AppColors.errorRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text('Refuser', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _accepterCourse(course),
                icon: const Icon(Icons.check, size: 18),
                label: Text('Accepter la course', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        );

      case StatutCommande.accepte:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _marquerEnRoute(course),
            icon: const Icon(Icons.motorcycle, size: 18),
            label: Text(
              'Colis récupéré → Je commence la livraison',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case StatutCommande.enRoute:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _marquerLivre(course),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: Text(
              'Arrivé chez le client → Marquer comme livré',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case StatutCommande.livre:
        if (!course.confirmationLivreur) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _confirmerLivreur(course),
                  icon: const Icon(Icons.verified, size: 18),
                  label: Text(
                    'Confirmer la remise en main propre',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandDarkNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (course.peutEtreForce) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showForceDialog(course),
                  icon: const Icon(Icons.camera_alt, size: 16, color: AppColors.textSecondary),
                  label: Text(
                    'Client injoignable ? Forcer avec photo preuve',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          );
        }
        return _buildWaitingConfirmation();

      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                'Livraison finalisée • Gain validé',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green.shade800),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildWaitingConfirmation() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Remise confirmée par vous. En attente de la confirmation client.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationTimer() {
    final hours = _tempsRestant.inHours;
    final minutes = _tempsRestant.inMinutes % 60;
    final isUrgent = _tempsRestant.inHours <= 2;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUrgent ? Colors.red.shade50 : AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isUrgent ? Colors.red.shade200 : AppColors.borderGray),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 16, color: isUrgent ? AppColors.errorRed : AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Auto-validation client dans : ${hours}h ${minutes}min',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w500,
                  color: isUrgent ? AppColors.errorRed : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIONS API FIRESTORE ──────────────────────────────────────────────────

  Future<void> _accepterCourse(CommandeVendeur course) async {
    setState(() => _isLoading = true);
    try {
      await CommandeVendeurService.instance.accepterCourse(course.id, course.livreurId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course acceptée ! Dirigez-vous vers le commerçant.'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refuserCourse(CommandeVendeur course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Refuser cette course ?'),
        content: const Text('Cette course sera immédiatement transmise à un autre livreur disponible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser la course'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await CommandeVendeurService.instance.refuserCourse(course.id, course.livreurId);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _marquerEnRoute(CommandeVendeur course) async {
    setState(() => _isLoading = true);
    try {
      await CommandeVendeurService.instance.marquerEnRoute(course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course en cours ! Bonne route.'), backgroundColor: AppColors.primaryOrange),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _marquerLivre(CommandeVendeur course) async {
    setState(() => _isLoading = true);
    try {
      await CommandeVendeurService.instance.marquerLivre(course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Livraison effectuée ! Confirmez maintenant la remise.'), backgroundColor: AppColors.primaryOrange),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmerLivreur(CommandeVendeur course) async {
    setState(() => _isLoading = true);
    try {
      await CommandeVendeurService.instance.confirmerLivreur(course.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Remise confirmée !'), backgroundColor: AppColors.successGreen),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForceDialog(CommandeVendeur course) {
    final raisonController = TextEditingController();
    File? photoFile;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Preuve de livraison forcée', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Prenez une photo sur le lieu de livraison (ex: devant la porte ou avec le gardien).',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                if (photoFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(photoFile!, height: 160, width: double.infinity, fit: BoxFit.cover),
                  )
                else
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                      if (image != null) {
                        setDialogState(() => photoFile = File(image.path));
                      }
                    },
                    icon: const Icon(Icons.camera_alt, color: AppColors.primaryOrange),
                    label: const Text('Prendre une photo'),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: raisonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Raison (ex: Client injoignable, colis remis au concierge)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: photoFile != null && raisonController.text.trim().isNotEmpty
                  ? () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await CommandeVendeurService.instance.forcerConfirmation(
                          commandeId: course.id,
                          photoPreuve: photoFile!,
                          raison: raisonController.text.trim(),
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Livraison validée par photo !'), backgroundColor: AppColors.successGreen),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    }
                  : null,
              child: const Text('Valider avec photo'),
            ),
          ],
        ),
      ),
    );
  }

  Color _borderColor(StatutCommande statut) {
    switch (statut) {
      case StatutCommande.paye:
        return AppColors.infoBlue.withAlpha(120);
      case StatutCommande.accepte:
      case StatutCommande.enRoute:
        return AppColors.primaryOrange.withAlpha(140);
      case StatutCommande.livre:
        return Colors.amber.shade400;
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        return Colors.green.shade400;
      default:
        return AppColors.borderGray;
    }
  }

  Color _headerBgColor(StatutCommande statut) {
    switch (statut) {
      case StatutCommande.paye:
        return Colors.blue.shade50;
      case StatutCommande.accepte:
      case StatutCommande.enRoute:
        return AppColors.primaryOrangeLight;
      case StatutCommande.livre:
        return Colors.amber.shade50;
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        return Colors.green.shade50;
      default:
        return AppColors.surfaceGray;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUT BADGE AVEC ICÔNE
// ═══════════════════════════════════════════════════════════════════════════

class _StatutBadge extends StatelessWidget {
  final StatutCommande statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (statut) {
      case StatutCommande.paye:
        label = 'NOUVELLE';
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        icon = Icons.fiber_new_rounded;
        break;
      case StatutCommande.accepte:
        label = 'ACCEPTÉE';
        bgColor = AppColors.primaryOrangeLight;
        textColor = AppColors.primaryOrangeDark;
        icon = Icons.thumb_up_alt_outlined;
        break;
      case StatutCommande.enRoute:
        label = 'EN LIVRAISON';
        bgColor = AppColors.primaryOrangeLight;
        textColor = AppColors.primaryOrangeDark;
        icon = Icons.two_wheeler;
        break;
      case StatutCommande.livre:
        label = 'DÉPOSÉE';
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade900;
        icon = Icons.access_time_rounded;
        break;
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        label = 'TERMINÉE';
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        icon = Icons.check_circle_outline;
        break;
      case StatutCommande.litige:
        label = 'LITIGE';
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.warning_amber_rounded;
        break;
      default:
        label = statut.label.toUpperCase();
        bgColor = Colors.grey.shade200;
        textColor = Colors.grey.shade800;
        icon = Icons.info_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
