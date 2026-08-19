// screens/admin/admin_sponsoring_screen.dart
// Écran d'administration pour gérer les campagnes de sponsoring de services

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/sponsoring_campaign.dart';
import '../../models/sponsoring_validation.dart';
import '../../services/sponsoring_service.dart';
import '../../services/sponsoring_validation_service.dart';
import '../../widgets/miwodo_button.dart';
import 'admin_shell.dart';

enum SponsoringFilter { toutes, enAttente, actives, suspendues, refusees, expirees }

extension SponsoringFilterX on SponsoringFilter {
  String get label {
    switch (this) {
      case SponsoringFilter.toutes:
        return 'Toutes';
      case SponsoringFilter.enAttente:
        return 'En attente';
      case SponsoringFilter.actives:
        return 'Actives';
      case SponsoringFilter.suspendues:
        return 'Suspendues';
      case SponsoringFilter.refusees:
        return 'Refusées';
      case SponsoringFilter.expirees:
        return 'Expirées';
    }
  }

  CampaignStatut? get statut {
    switch (this) {
      case SponsoringFilter.enAttente:
        return CampaignStatut.enAttente;
      case SponsoringFilter.actives:
        return CampaignStatut.active;
      case SponsoringFilter.suspendues:
        return CampaignStatut.suspendue;
      case SponsoringFilter.refusees:
        return CampaignStatut.refusee;
      case SponsoringFilter.expirees:
        return CampaignStatut.expiree;
      case SponsoringFilter.toutes:
        return null;
    }
  }
}

final sponsoringFilterProvider = StateProvider<SponsoringFilter>((ref) => SponsoringFilter.toutes);

class AdminSponsoringScreen extends ConsumerWidget {
  const AdminSponsoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(sponsoringFilterProvider);

    return AdminShell(
      title: 'Sponsoring',
      child: Column(
        children: [
          _buildFilterBar(context, ref, filter),
          const SizedBox(height: 8),
          Expanded(child: _buildCampaignsList(ref, filter)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, WidgetRef ref, SponsoringFilter current) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SponsoringFilter.values.map((f) {
                  final isSelected = f == current;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(f.label),
                      selected: isSelected,
                      onSelected: (_) {
                        ref.read(sponsoringFilterProvider.notifier).state = f;
                      },
                      selectedColor: AppColors.primaryOrange,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                      ),
                      backgroundColor: AppColors.white,
                      side: BorderSide(color: AppColors.borderGray),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.primaryOrange),
            tooltip: 'Configuration de la validation',
            onPressed: () => context.go('/admin/sponsoring/config'),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignsList(WidgetRef ref, SponsoringFilter filter) {
    Stream<List<SponsoringCampaign>> stream;
    if (filter == SponsoringFilter.toutes) {
      stream = SponsoringService.instance.getAllCampaigns();
    } else {
      stream = SponsoringService.instance.getCampaignsByStatut(filter.statut!);
    }

    return StreamBuilder<List<SponsoringCampaign>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final campaigns = snapshot.data ?? [];
        if (campaigns.isEmpty) {
          return Center(
            child: Text(
              'Aucune campagne ${filter == SponsoringFilter.toutes ? "" : filter.label.toLowerCase()}',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: campaigns.length,
          itemBuilder: (context, index) {
            return _AdminCampaignCard(campaign: campaigns[index]);
          },
        );
      },
    );
  }
}

class _AdminCampaignCard extends ConsumerWidget {
  final SponsoringCampaign campaign;

  const _AdminCampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Header: service name + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.serviceName,
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: campaign.statut.color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  campaign.statut.displayLabel,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: campaign.statut.color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _ValidationScoreBadge(campaignId: campaign.id),
            ],
          ),
          const SizedBox(height: 8),

          // Prestataire info
          Row(
            children: [
              Icon(Icons.person, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(
                campaign.prestataireNom,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Details row
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _detailChip('Plan', campaign.plan.displayLabel),
              _detailChip('Montant', '${campaign.montant} ${campaign.devise}'),
              _detailChip('Période', '${_formatDate(campaign.dateDebut)} → ${_formatDate(campaign.dateFin)}'),
              if (campaign.isActive)
                _detailChip('Stats', '${campaign.vues} vues · ${campaign.clics} clics · ${campaign.joursRestants}j restants'),
            ],
          ),

          if (campaign.adminNote != null && campaign.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: ${campaign.adminNote}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],

          // Action buttons based on status
          const SizedBox(height: 12),
          _buildActions(context, ref),
        ],
      ),
    );
  }

  Widget _detailChip(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textPrimary),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    switch (campaign.statut) {
      case CampaignStatut.enAttente:
        return Row(
          children: [
            Expanded(
              child: MiwodoButton(
                label: 'Valider',
                variant: MiwodoButtonVariant.primary,
                onPressed: () => _showNoteDialog(context, 'Valider la campagne', CampaignStatut.active),
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiwodoButton(
                label: 'Refuser',
                variant: MiwodoButtonVariant.danger,
                onPressed: () => _showNoteDialog(context, 'Refuser la campagne', CampaignStatut.refusee),
                fullWidth: true,
              ),
            ),
          ],
        );
      case CampaignStatut.active:
        return Row(
          children: [
            Expanded(
              child: MiwodoButton(
                label: 'Suspendre',
                variant: MiwodoButtonVariant.secondary,
                onPressed: () => _showNoteDialog(context, 'Suspendre la campagne', CampaignStatut.suspendue),
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 8),
            if (campaign.isExpired)
              Expanded(
                child: MiwodoButton(
                  label: 'Marquer expirée',
                  variant: MiwodoButtonVariant.secondary,
                  onPressed: () async {
                    await SponsoringService.instance.updateCampaignStatut(campaign.id, CampaignStatut.expiree);
                  },
                  fullWidth: true,
                ),
              ),
          ],
        );
      case CampaignStatut.suspendue:
        return Row(
          children: [
            Expanded(
              child: MiwodoButton(
                label: 'Réactiver',
                variant: MiwodoButtonVariant.primary,
                onPressed: () async {
                  await SponsoringService.instance.updateCampaignStatut(campaign.id, CampaignStatut.active);
                },
                fullWidth: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MiwodoButton(
                label: 'Refuser définitivement',
                variant: MiwodoButtonVariant.danger,
                onPressed: () => _showNoteDialog(context, 'Refuser la campagne', CampaignStatut.refusee),
                fullWidth: true,
              ),
            ),
          ],
        );
      case CampaignStatut.refusee:
      case CampaignStatut.expiree:
      case CampaignStatut.annulee:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showNoteDialog(BuildContext context, String title, CampaignStatut newStatut) async {
    final noteController = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: noteController,
          decoration: InputDecoration(
            labelText: 'Note (optionnel)',
            labelStyle: GoogleFonts.inter(fontSize: 13),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Annuler', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(noteController.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            child: Text('Confirmer', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      await SponsoringService.instance.updateCampaignStatut(
        campaign.id,
        newStatut,
        adminNote: result.isNotEmpty ? result : null,
      );
    }
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _ValidationScoreBadge extends StatelessWidget {
  final String campaignId;

  const _ValidationScoreBadge({required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SponsoringValidationLog>>(
      stream: SponsoringValidationService.instance.getLogsForCampaign(campaignId),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return const SizedBox.shrink();

        final log = logs.first;
        Color color;
        if (log.score >= 95) {
          color = AppColors.successGreen;
        } else if (log.score >= 80) {
          color = const Color(0xFFF59E0B);
        } else {
          color = AppColors.errorRed;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(60), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                log.autoApproved ? Icons.verified : Icons.warning_amber,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 3),
              Text(
                '${log.score.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ),
        );
      },
    );
  }
}
