// widgets/vendeur_solde_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../models/commande.dart';
import '../models/demande_retrait.dart';
import '../models/prestataire.dart';
import '../services/commande_vendeur_service.dart';
import '../services/retrait_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS
// ═══════════════════════════════════════════════════════════════════════════

final vendeurSoldeProvider = StreamProvider.family<SoldeVendeur, String>((ref, vendeurId) {
  return CommandeVendeurService.instance.streamSolde(vendeurId);
});

final vendeurCommandesProvider = StreamProvider.family<List<CommandeVendeur>, String>((ref, vendeurId) {
  return CommandeVendeurService.instance.streamCommandesVendeur(vendeurId);
});

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET SOLDE HEADER
// ═══════════════════════════════════════════════════════════════════════════

class VendeurSoldeHeader extends ConsumerWidget {
  final Prestataire prestataire;

  const VendeurSoldeHeader({super.key, required this.prestataire});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soldeAsync = ref.watch(vendeurSoldeProvider(prestataire.id));

    return soldeAsync.when(
      data: (solde) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primaryOrange, Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryOrange.withAlpha(60),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mon solde Miwodo', style: GoogleFonts.inter(fontSize: 14, color: Colors.white70)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('Escrow', style: GoogleFonts.inter(fontSize: 11, color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${_formatMontant(solde.soldeDisponible)} F CFA',
              style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _SoldeDetail(label: 'En attente', value: '${_formatMontant(solde.soldeEnAttente)} F', icon: Icons.hourglass_empty),
                const SizedBox(width: 20),
                _SoldeDetail(label: 'Total encaissé', value: '${_formatMontant(solde.totalEncaisse)} F', icon: Icons.trending_up),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: solde.soldeDisponible > 0 ? () => _showRetraitDialog(context, solde) : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: solde.soldeDisponible > 0 ? Colors.white : Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.account_balance_wallet, size: 18),
                    label: Text('Demander un retrait', style: GoogleFonts.inter(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      loading: () => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceGray,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatMontant(int montant) {
    if (montant >= 1000000) {
      return '${(montant / 1000000).toStringAsFixed(1)}M';
    } else if (montant >= 1000) {
      return '${(montant / 1000).toStringAsFixed(0)}K';
    }
    return montant.toString();
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
                          source: RetraitSource.soldeVendeur,
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

class _SoldeDetail extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SoldeDetail({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 10, color: Colors.white60)),
            Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET COMMANDES VENDEUR
// ═══════════════════════════════════════════════════════════════════════════

class VendeurCommandesWidget extends ConsumerWidget {
  final Prestataire prestataire;

  const VendeurCommandesWidget({super.key, required this.prestataire});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commandesAsync = ref.watch(vendeurCommandesProvider(prestataire.id));

    return commandesAsync.when(
      data: (commandes) {
        if (commandes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('Aucune commande', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Vos commandes apparaîtront ici.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: commandes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final commande = commandes[index];
            return _VendeurCommandeCard(commande: commande);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
    );
  }
}

class _VendeurCommandeCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _VendeurCommandeCard({required this.commande});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(commande.numero, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    _EscrowBadge(statut: commande.escrowStatut),
                  ],
                ),
                Text(
                  '${commande.montantVendeur} F',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(commande.clientNom, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                const Text(' · ', style: TextStyle(color: AppColors.textSecondary)),
                Text(commande.clientZone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatutChip(statut: commande.statut),
                const Spacer(),
                Text(
                  _formatDate(commande.createdAt),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.difference(date).inDays == 0) {
      return 'Aujourd\'hui ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(date).inDays == 1) {
      return 'Hier';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _EscrowBadge extends StatelessWidget {
  final EscrowStatut statut;

  const _EscrowBadge({required this.statut});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (statut) {
      case EscrowStatut.enAttente:
        bgColor = Colors.amber.shade50;
        textColor = Colors.amber.shade800;
        icon = Icons.hourglass_empty;
        break;
      case EscrowStatut.libere:
      case EscrowStatut.force:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case EscrowStatut.rembourse:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(statut.label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }
}

class _StatutChip extends StatelessWidget {
  final StatutCommande statut;

  const _StatutChip({required this.statut});

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
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(statut.label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
    );
  }
}
