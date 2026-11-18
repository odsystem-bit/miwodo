// screens/admin/admin_stats_screen.dart
// Statistiques détaillées — métriques, tendances, graphiques simples
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../services/firestore_service.dart';
import '../../services/sponsoring_service.dart';
import 'admin_shell.dart';

class AdminStatsScreen extends ConsumerWidget {
  const AdminStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: 'Statistiques',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Vue d'ensemble",
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            // Métriques principales
            StreamBuilder<int>(
              stream: FirestoreService.instance.getPrestatairesCount(),
              builder: (context, snap) {
                return _buildMetricGrid(
                  total: snap.data ?? 0,
                  verified: 0,
                  sponsored: 0,
                  signalements: 0,
                );
              },
            ),
            const SizedBox(height: 24),
            // Compteurs détaillés
            _buildSectionTitle('Compteurs détaillés'),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: FirestoreService.instance.getVerifiedCount(),
              builder: (context, snap) {
                return _buildStatRow('Prestataires vérifiés', snap.data ?? 0, Icons.verified, AppColors.successGreen);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: SponsoringService.instance.getActiveCampaignsCount(),
              builder: (context, snap) {
                return _buildStatRow('Campagnes sponsoring actives', snap.data ?? 0, Icons.campaign, AppColors.primaryOrange);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: SponsoringService.instance.getPendingCampaignsCount(),
              builder: (context, snap) {
                return _buildStatRow('Campagnes en attente', snap.data ?? 0, Icons.hourglass_top, AppColors.primaryOrange);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: FirestoreService.instance.getSignalementsCount('ouvert'),
              builder: (context, snap) {
                return _buildStatRow('Signalements ouverts', snap.data ?? 0, Icons.flag, AppColors.errorRed);
              },
            ),
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: FirestoreService.instance.getCommandesCountToday(),
              builder: (context, snap) {
                return _buildStatRow("Commandes aujourd'hui", snap.data ?? 0, Icons.shopping_bag, AppColors.primaryOrange);
              },
            ),
            const SizedBox(height: 24),
            // Inscriptions récentes
            _buildSectionTitle('Inscriptions récentes (30 jours)'),
            const SizedBox(height: 12),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreService.instance.getRecentInscriptions(days: 30),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return Text(
                    'Aucune inscription récente.',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  );
                }
                return Column(
                  children: list.take(10).map((data) {
                    final nom = data['nom'] as String? ?? '';
                    final prenom = data['prenom'] as String? ?? '';
                    final categorie = data['categorie'] as String? ?? '';
                    final paysNom = data['paysNom'] as String? ?? '';
                    final creeLe = data['creeLe'];
                    String dateStr = '';
                    if (creeLe is Timestamp) {
                      final dt = creeLe.toDate();
                      dateStr = '${dt.day}/${dt.month}/${dt.year}';
                    }
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryOrangeLight,
                          child: Text(
                            '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}',
                            style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w700),
                          ),
                        ),
                        title: Text('$prenom $nom', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('$categorie • $paysNom • $dateStr', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGrid({
    required int total,
    required int verified,
    required int sponsored,
    required int signalements,
  }) {
    return StreamBuilder<int>(
      stream: FirestoreService.instance.getVerifiedCount(),
      builder: (context, snap1) {
        return StreamBuilder<int>(
          stream: SponsoringService.instance.getActiveCampaignsCount(),
          builder: (context, snap2) {
            return StreamBuilder<int>(
              stream: FirestoreService.instance.getSignalementsCount('ouvert'),
              builder: (context, snap3) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _MetricBox('Total prestataires', total, AppColors.primaryOrange)),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricBox('Vérifiés', snap1.data ?? 0, AppColors.successGreen)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _MetricBox('Campagnes actives', snap2.data ?? 0, AppColors.primaryOrange)),
                        const SizedBox(width: 12),
                        Expanded(child: _MetricBox('Signalements', snap3.data ?? 0, AppColors.errorRed)),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildStatRow(String label, int value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
            ),
            Text(
              value.toString(),
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MetricBox(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(30), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
