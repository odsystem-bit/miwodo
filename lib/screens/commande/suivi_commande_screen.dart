// screens/commande/suivi_commande_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/commande.dart';
import '../../services/app_rating_service.dart';
import '../../services/commande_vendeur_service.dart';
import '../../widgets/miwodo_button.dart';

class SuiviCommandeScreen extends ConsumerWidget {
  final String commandeId;

  const SuiviCommandeScreen({super.key, required this.commandeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: Text('Suivi commande', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/'),
        ),
      ),
      body: StreamBuilder<CommandeVendeur>(
        stream: CommandeVendeurService.instance.streamCommande(commandeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.errorRed),
                  const SizedBox(height: 16),
                  Text('Commande introuvable', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  MiwodoButton(label: 'Retour', onPressed: () => context.go('/')),
                ],
              ),
            );
          }

          final commande = snapshot.data!;
          return _CommandeContent(commande: commande);
        },
      ),
    );
  }
}

class _CommandeContent extends StatelessWidget {
  final CommandeVendeur commande;

  const _CommandeContent({required this.commande});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro commande
          _HeaderCard(commande: commande),
          const SizedBox(height: 16),

          // Timeline
          _TimelineCard(commande: commande),
          const SizedBox(height: 16),

          // Infos livreur
          _LivreurCard(commande: commande),
          const SizedBox(height: 16),

          // Infos vendeur
          _VendeurCard(commande: commande),
          const SizedBox(height: 16),

          // Escrow info
          _EscrowCard(commande: commande),
          const SizedBox(height: 16),

          // Actions client
          if (commande.statut == StatutCommande.livre && !commande.confirmationClient)
            _ConfirmationClientCard(commande: commande),

          // Litige
          if (commande.statut != StatutCommande.confirme && 
              commande.statut != StatutCommande.forceConfirme &&
              commande.statut != StatutCommande.rembourse)
            _LitigeCard(commande: commande),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER CARD
// ═══════════════════════════════════════════════════════════════════════════

class _HeaderCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _HeaderCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commande', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(commande.numero, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
                _StatutBadge(statut: commande.statut),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total payé', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                Text('${commande.totalClient} F CFA', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatutBadge extends StatelessWidget {
  final StatutCommande statut;

  const _StatutBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (statut) {
      case StatutCommande.paye:
      case StatutCommande.accepte:
      case StatutCommande.enRoute:
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case StatutCommande.livre:
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade700;
        break;
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      case StatutCommande.litige:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        break;
      case StatutCommande.rembourse:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(statut.label, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TIMELINE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _TimelineCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _TimelineCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    final steps = [
      _TimelineStep(
        title: 'Commande payée',
        subtitle: 'Paiement reçu',
        isCompleted: true,
        isActive: commande.statut == StatutCommande.paye,
      ),
      _TimelineStep(
        title: 'Livreur en route',
        subtitle: 'Récupération en cours',
        isCompleted: commande.statut.index >= StatutCommande.enRoute.index,
        isActive: commande.statut == StatutCommande.accepte || commande.statut == StatutCommande.enRoute,
      ),
      _TimelineStep(
        title: 'Livraison effectuée',
        subtitle: 'Arrivé à destination',
        isCompleted: commande.statut.index >= StatutCommande.livre.index,
        isActive: commande.statut == StatutCommande.livre,
      ),
      _TimelineStep(
        title: 'Commande confirmée',
        subtitle: commande.forceParLivreur ? 'Confirmé avec photo preuve' : 'Réception confirmée',
        isCompleted: commande.statut == StatutCommande.confirme || commande.statut == StatutCommande.forceConfirme,
        isActive: false,
        isSuccess: true,
      ),
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suivi de livraison', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;
              return _TimelineStepWidget(step: step, isLast: isLast);
            }),
          ],
        ),
      ),
    );
  }
}

class _TimelineStep {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isActive;
  final bool isSuccess;

  _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isActive,
    this.isSuccess = false,
  });
}

class _TimelineStepWidget extends StatelessWidget {
  final _TimelineStep step;
  final bool isLast;

  const _TimelineStepWidget({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    Color circleColor;
    Color lineColor;

    if (step.isSuccess && step.isCompleted) {
      circleColor = AppColors.successGreen;
      lineColor = AppColors.successGreen;
    } else if (step.isCompleted) {
      circleColor = AppColors.primaryOrange;
      lineColor = AppColors.primaryOrange;
    } else if (step.isActive) {
      circleColor = AppColors.primaryOrange;
      lineColor = AppColors.borderGray;
    } else {
      circleColor = AppColors.borderGray;
      lineColor = AppColors.borderGray;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: step.isCompleted || step.isActive ? circleColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: circleColor, width: 2),
              ),
              child: step.isCompleted
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : step.isActive
                      ? Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        )
                      : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: step.isActive || step.isCompleted ? FontWeight.w600 : FontWeight.w400,
                    color: step.isActive || step.isCompleted ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(step.subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LIVREUR CARD
// ═══════════════════════════════════════════════════════════════════════════

class _LivreurCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _LivreurCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Votre livreur', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryOrangeLight,
                  child: Text(
                    commande.livreurNom.isNotEmpty ? commande.livreurNom[0].toUpperCase() : 'L',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: AppColors.primaryOrange, fontSize: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(commande.livreurNom, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(_getEnginIcon(commande.livreurTypeEngin), size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(commande.livreurTypeEngin ?? 'Moto', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (commande.livreurTelephone.isNotEmpty)
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse('tel:${commande.livreurTelephone}')),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.primaryOrangeLight, shape: BoxShape.circle),
                      child: const Icon(Icons.phone, size: 20, color: AppColors.primaryOrange),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEnginIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'moto': return Icons.two_wheeler;
      case 'voiture': return Icons.directions_car;
      case 'velo': return Icons.pedal_bike;
      case 'tricycle': return Icons.electric_rickshaw;
      default: return Icons.local_shipping;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VENDEUR CARD
// ═══════════════════════════════════════════════════════════════════════════

class _VendeurCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _VendeurCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vendeur', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue.shade50,
                  child: const Icon(Icons.store, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(commande.vendeurBoutiqueNom ?? commande.vendeurNom, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                      if (commande.vendeurBoutiqueNom != null)
                        Text(commande.vendeurNom, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (commande.vendeurTelephone != null && commande.vendeurTelephone!.isNotEmpty)
                  IconButton(
                    onPressed: () => launchUrl(Uri.parse('tel:${commande.vendeurTelephone}')),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                      child: Icon(Icons.phone, size: 20, color: Colors.blue.shade700),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ESCROW CARD
// ═══════════════════════════════════════════════════════════════════════════

class _EscrowCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _EscrowCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    final isLibere = commande.escrowStatut == EscrowStatut.libere || commande.escrowStatut == EscrowStatut.force;
    final isRembourse = commande.escrowStatut == EscrowStatut.rembourse;

    Color bgColor;
    Color iconColor;
    String title;
    String subtitle;

    if (isLibere) {
      bgColor = Colors.green.shade50;
      iconColor = Colors.green.shade700;
      title = 'Paiement libéré';
      subtitle = 'Le vendeur a reçu son paiement.';
    } else if (isRembourse) {
      bgColor = Colors.grey.shade100;
      iconColor = Colors.grey.shade700;
      title = 'Paiement remboursé';
      subtitle = 'Vous avez été remboursé.';
    } else {
      bgColor = AppColors.primaryOrangeLight;
      iconColor = AppColors.primaryOrange;
      title = 'Paiement sécurisé';
      subtitle = 'Votre paiement de ${commande.totalClient} F est protégé jusqu\'à confirmation de livraison.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(isLibere ? Icons.check_circle : Icons.lock, size: 24, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: iconColor)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIRMATION CLIENT CARD
// ═══════════════════════════════════════════════════════════════════════════

class _ConfirmationClientCard extends ConsumerWidget {
  final CommandeVendeur commande;

  const _ConfirmationClientCard({required this.commande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text('Confirmer la réception', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Avez-vous bien reçu votre commande ? Confirmez pour libérer le paiement au vendeur.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            MiwodoButton(
              label: 'J\'ai bien reçu ma commande',
              fullWidth: true,
              onPressed: () => _showConfirmationDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la réception'),
        content: Text('Confirmez-vous avoir reçu votre commande ${commande.numero} ?\n\nCette action libérera le paiement au vendeur.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.successGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              await CommandeVendeurService.instance.confirmerClient(commande.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Réception confirmée !'), backgroundColor: AppColors.successGreen),
                );
                await AppRatingService.instance.showRatingDialog(
                  context,
                  source: 'commande_livree_${commande.numero}',
                );
              }
            },
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LITIGE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _LitigeCard extends ConsumerWidget {
  final CommandeVendeur commande;

  const _LitigeCard({required this.commande});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (commande.statut == StatutCommande.litige) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Text('Litige en cours', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Notre équipe examine votre signalement. Vous serez contacté sous 24h.',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              if (commande.litigeDescription != null) ...[
                const SizedBox(height: 8),
                Text('Motif : ${commande.litigeDescription}', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton.icon(
          onPressed: () => _showLitigeDialog(context),
          icon: Icon(Icons.warning_amber, size: 18, color: Colors.red.shade700),
          label: Text('Signaler un problème', style: GoogleFonts.inter(color: Colors.red.shade700, fontSize: 13)),
        ),
      ),
    );
  }

  void _showLitigeDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Signaler un problème'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Décrivez le problème rencontré avec cette commande.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Ex: Je n\'ai pas reçu ma commande...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () async {
              if (controller.text.isEmpty) return;
              Navigator.pop(ctx);
              await CommandeVendeurService.instance.signalerLitige(
                commandeId: commande.id,
                description: controller.text,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Signalement envoyé'), backgroundColor: AppColors.primaryOrange),
                );
              }
            },
            child: const Text('Envoyer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
