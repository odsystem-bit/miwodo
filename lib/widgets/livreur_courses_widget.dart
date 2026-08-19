// widgets/livreur_courses_widget.dart
import 'dart:async';
import 'dart:io';
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

class LivreurCoursesWidget extends ConsumerWidget {
  final Prestataire prestataire;

  const LivreurCoursesWidget({super.key, required this.prestataire});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(livreurCoursesProvider(prestataire.id));
    final soldeAsync = ref.watch(livreurSoldeProvider(prestataire.id));

    return Column(
      children: [
        // Solde card
        soldeAsync.when(
          data: (solde) => _SoldeCard(solde: solde, prestataire: prestataire),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),

        // Courses
        Expanded(
          child: coursesAsync.when(
            data: (courses) {
              if (courses.isEmpty) {
                return _EmptyCoursesView();
              }

              // Trier par statut (nouvelles en premier)
              final sorted = List<CommandeVendeur>.from(courses)
                ..sort((a, b) => a.statut.index.compareTo(b.statut.index));

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final course = sorted[index];
                  return _CourseCard(course: course);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SOLDE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _SoldeCard extends StatelessWidget {
  final SoldeVendeur solde;
  final Prestataire prestataire;

  const _SoldeCard({required this.solde, required this.prestataire});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mon solde Miwodo', style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text('Sécurisé', style: GoogleFonts.inter(fontSize: 10, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${solde.soldeDisponible} F CFA',
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            '${solde.soldeEnAttente} F en attente',
            style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: solde.soldeDisponible > 0
                      ? () => _showRetraitDialog(context, solde)
                      : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Demander un retrait', style: GoogleFonts.inter(fontSize: 12)),
                ),
              ),
            ],
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
    final retraitMinimum = 1000;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Demander un retrait', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Solde disponible: ${solde.soldeDisponible} $symbole',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                Text('Minimum: $retraitMinimum $symbole',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant à retirer ($symbole)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Méthode de paiement', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
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
                        ? 'Numéro de compte bancaire (RIB)'
                        : 'Numéro Mobile Money / Téléphone',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du destinataire (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
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
                          const SnackBar(content: Text('Montant supérieur au solde'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (numeroController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Numéro destinataire requis'), backgroundColor: AppColors.errorRed),
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
                              content: Text('Demande de retrait envoyée!'),
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
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Confirmer'),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MiwodoSvgIcon('ic_truck.svg', size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text('Aucune course', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Les nouvelles courses apparaîtront ici.',
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COURSE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _CourseCard extends ConsumerStatefulWidget {
  final CommandeVendeur course;

  const _CourseCard({required this.course});

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

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    Color cardColor;
    Color borderColor;

    switch (course.statut) {
      case StatutCommande.paye:
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        break;
      case StatutCommande.accepte:
      case StatutCommande.enRoute:
        cardColor = AppColors.primaryOrangeLight;
        borderColor = AppColors.primaryOrange;
        break;
      case StatutCommande.livre:
        cardColor = Colors.amber.shade50;
        borderColor = Colors.amber.shade400;
        break;
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        cardColor = Colors.green.shade50;
        borderColor = Colors.green.shade400;
        break;
      default:
        cardColor = Colors.white;
        borderColor = AppColors.borderGray;
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      color: cardColor,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _StatutBadge(statut: course.statut),
                    const SizedBox(width: 8),
                    Text(course.numero, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                Text(
                  '${course.fraisLivraison} F',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Client info
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(course.clientNom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                ),
                IconButton(
                  onPressed: () => launchUrl(Uri.parse('tel:${course.clientTelephone}')),
                  icon: const Icon(Icons.phone, size: 18, color: AppColors.primaryOrange),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${course.clientZone}${course.clientAdresseTexte.isNotEmpty ? ' - ${course.clientAdresseTexte}' : ''}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Articles
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${course.articles.length} article${course.articles.length > 1 ? 's' : ''}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  ...course.articles.take(2).map((a) => Text('• ${a.quantite}x ${a.nom}', style: GoogleFonts.inter(fontSize: 12))),
                  if (course.articles.length > 2)
                    Text('+ ${course.articles.length - 2} autre(s)', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Actions selon statut
            _buildActions(course),

            // Timer pour confirmation
            if (course.statut == StatutCommande.livre && !course.confirmationClient)
              _buildConfirmationTimer(),
          ],
        ),
      ),
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
                ),
                child: Text('Refuser', style: GoogleFonts.inter(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MiwodoButton(
                label: 'Accepter',
                isLoading: _isLoading,
                onPressed: () => _accepterCourse(course),
              ),
            ),
          ],
        );

      case StatutCommande.accepte:
        return MiwodoButton(
          label: 'Je suis en route → livraison',
          fullWidth: true,
          isLoading: _isLoading,
          onPressed: () => _marquerEnRoute(course),
        );

      case StatutCommande.enRoute:
        return MiwodoButton(
          label: 'Marquer comme livré',
          fullWidth: true,
          isLoading: _isLoading,
          onPressed: () => _marquerLivre(course),
        );

      case StatutCommande.livre:
        if (!course.confirmationLivreur) {
          return Column(
            children: [
              MiwodoButton(
                label: 'Confirmer la livraison',
                fullWidth: true,
                isLoading: _isLoading,
                onPressed: () => _confirmerLivreur(course),
              ),
              if (course.peutEtreForce && _tempsRestant.inHours <= 2) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showForceDialog(course),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: Text('Forcer avec photo preuve', style: GoogleFonts.inter(fontSize: 12)),
                ),
              ],
            ],
          );
        }
        return _buildWaitingConfirmation();

      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 18),
              const SizedBox(width: 8),
              Text('Livraison terminée', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade800)),
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
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'En attente de confirmation du client...',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.amber.shade900),
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
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isUrgent ? Colors.red.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.timer, size: 16, color: isUrgent ? Colors.red : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              'Temps restant: ${hours}h ${minutes}min',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400,
                color: isUrgent ? Colors.red : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Actions
  Future<void> _accepterCourse(CommandeVendeur course) async {
    setState(() => _isLoading = true);
    try {
      await CommandeVendeurService.instance.accepterCourse(course.id, course.livreurId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course acceptée !'), backgroundColor: AppColors.successGreen),
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

  Future<void> _refuserCourse(CommandeVendeur course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser la course ?'),
        content: const Text('Cette course sera proposée à un autre livreur.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser', style: TextStyle(color: Colors.white)),
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
          const SnackBar(content: Text('Livraison marquée ! En attente de confirmation.'), backgroundColor: AppColors.primaryOrange),
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
          title: const Text('Forcer la confirmation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Prenez une photo comme preuve de livraison.'),
                const SizedBox(height: 16),
                if (photoFile != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(photoFile!, height: 150, fit: BoxFit.cover),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(source: ImageSource.camera);
                      if (image != null) {
                        setDialogState(() => photoFile = File(image.path));
                      }
                    },
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Prendre une photo'),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: raisonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Raison (ex: Client absent, laissé chez le voisin...)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: photoFile != null && raisonController.text.isNotEmpty
                  ? () async {
                      Navigator.pop(ctx);
                      setState(() => _isLoading = true);
                      try {
                        await CommandeVendeurService.instance.forcerConfirmation(
                          commandeId: course.id,
                          photoPreuve: photoFile!,
                          raison: raisonController.text,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Confirmation forcée avec succès'), backgroundColor: AppColors.successGreen),
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
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STATUT BADGE
// ═══════════════════════════════════════════════════════════════════════════

class _StatutBadge extends StatelessWidget {
  final StatutCommande statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;

    switch (statut) {
      case StatutCommande.paye:
        label = 'NOUVELLE';
        bgColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case StatutCommande.accepte:
        label = 'ACCEPTÉE';
        bgColor = AppColors.primaryOrangeLight;
        textColor = AppColors.primaryOrange;
        break;
      case StatutCommande.enRoute:
        label = 'EN ROUTE';
        bgColor = AppColors.primaryOrangeLight;
        textColor = AppColors.primaryOrange;
        break;
      case StatutCommande.livre:
        label = 'LIVRÉE';
        bgColor = Colors.amber.shade100;
        textColor = Colors.amber.shade800;
        break;
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        label = 'TERMINÉE';
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case StatutCommande.litige:
        label = 'LITIGE';
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      default:
        label = statut.label.toUpperCase();
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textColor)),
    );
  }
}
