import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/demande_retrait.dart';
import '../../services/retrait_service.dart';

final adminRetraitsProvider = StreamProvider.family<List<DemandeRetrait>, RetraitStatut?>((ref, statut) {
  return RetraitService.instance.streamAllDemandesRetrait(filtreStatut: statut);
});

final adminProfileProvider = FutureProvider<Map<String, String?>>((ref) async {
  return {'uid': null, 'nom': 'Admin'};
});

class AdminRetraitsScreen extends ConsumerStatefulWidget {
  const AdminRetraitsScreen({super.key});

  @override
  ConsumerState<AdminRetraitsScreen> createState() => _AdminRetraitsScreenState();
}

class _AdminRetraitsScreenState extends ConsumerState<AdminRetraitsScreen> {
  RetraitStatut? _filtre = RetraitStatut.enAttente;

  @override
  Widget build(BuildContext context) {
    final retraitsAsync = ref.watch(adminRetraitsProvider(_filtre));

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        title: Text('Demandes de retrait', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          PopupMenuButton<RetraitStatut?>(
            icon: const Icon(Icons.filter_list, color: AppColors.primaryOrange),
            onSelected: (v) => setState(() => _filtre = v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('Toutes')),
              const PopupMenuItem(value: RetraitStatut.enAttente, child: Text('En attente')),
              const PopupMenuItem(value: RetraitStatut.approuve, child: Text('Approuvées')),
              const PopupMenuItem(value: RetraitStatut.refuse, child: Text('Refusées')),
              const PopupMenuItem(value: RetraitStatut.paye, child: Text('Payées')),
            ],
          ),
        ],
      ),
      body: retraitsAsync.when(
        data: (retraits) {
          if (retraits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 64, color: AppColors.borderGray),
                  const SizedBox(height: 16),
                  Text('Aucune demande de retrait', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: retraits.length,
            itemBuilder: (context, index) => _AdminRetraitCard(demande: retraits[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e', style: GoogleFonts.inter(color: AppColors.errorRed))),
      ),
    );
  }
}

class _AdminRetraitCard extends ConsumerStatefulWidget {
  final DemandeRetrait demande;

  const _AdminRetraitCard({required this.demande});

  @override
  ConsumerState<_AdminRetraitCard> createState() => _AdminRetraitCardState();
}

class _AdminRetraitCardState extends ConsumerState<_AdminRetraitCard> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.demande;
    final statutColor = Color(d.statut.colorValue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.prestataireNom,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      d.source.label,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statutColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  d.statut.label,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: statutColor),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${d.montant} ${d.devise}',
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Méthode', d.methodePaiement.label),
                    const SizedBox(height: 4),
                    _infoRow('Destinataire', d.numeroDestinataire),
                    if (d.nomDestinataire != null) ...[
                      const SizedBox(height: 4),
                      _infoRow('Nom', d.nomDestinataire!),
                    ],
                    const SizedBox(height: 4),
                    _infoRow('Date', '${d.creeLe.day}/${d.creeLe.month}/${d.creeLe.year} ${d.creeLe.hour}h${d.creeLe.minute.toString().padLeft(2, '0')}'),
                    if (d.adminNom != null) ...[
                      const SizedBox(height: 4),
                      _infoRow('Traité par', d.adminNom!),
                    ],
                    if (d.raisonRefus != null) ...[
                      const SizedBox(height: 4),
                      _infoRow('Raison refus', d.raisonRefus!, color: AppColors.errorRed),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (d.statut == RetraitStatut.enAttente) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : () => _showRefusDialog(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.errorRed,
                      side: const BorderSide(color: AppColors.errorRed),
                    ),
                    child: Text('Refuser', style: GoogleFonts.inter(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : () => _approuver(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Approuver', style: GoogleFonts.inter(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
          if (d.statut == RetraitStatut.approuve) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _marquerPaye(context),
                icon: const Icon(Icons.check_circle, size: 18),
                label: Text('Marquer comme payé', style: GoogleFonts.inter(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? AppColors.textPrimary)),
        ),
      ],
    );
  }

  Future<void> _approuver(BuildContext context) async {
    setState(() => _isProcessing = true);
    try {
      await RetraitService.instance.approuverDemande(
        demandeId: widget.demande.id,
        adminId: 'admin',
        adminNom: 'Admin',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande approuvée'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRefusDialog(BuildContext context) {
    final raisonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Refuser la demande', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: raisonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Raison du refus',
            hintText: 'Ex: Solde insuffisant, numéro invalide...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              if (raisonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez indiquer une raison'), backgroundColor: AppColors.errorRed),
                );
                return;
              }
              Navigator.pop(ctx);
              setState(() => _isProcessing = true);
              try {
                await RetraitService.instance.refuserDemande(
                  demandeId: widget.demande.id,
                  adminId: 'admin',
                  adminNom: 'Admin',
                  raisonRefus: raisonController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demande refusée'), backgroundColor: AppColors.errorRed),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Confirmer le refus'),
          ),
        ],
      ),
    );
  }

  Future<void> _marquerPaye(BuildContext context) async {
    setState(() => _isProcessing = true);
    try {
      await RetraitService.instance.marquerCommePaye(demandeId: widget.demande.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Marqué comme payé'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
