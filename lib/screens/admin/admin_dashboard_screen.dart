// screens/admin/admin_dashboard_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../models/transaction_record.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/miwodo_button.dart';
import 'admin_shell.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminRole = ref.watch(adminRoleProvider).asData?.value;
    final greetingName = adminRole?.nom ?? adminRole?.email ?? 'Administrateur';
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

    return AdminShell(
      title: "Vue d'ensemble",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour $greetingName',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tableau de bord admin • $formattedDate',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildMetrics(ref),
            const SizedBox(height: 24),
            _buildSectionHeader('Activité récente'),
            const SizedBox(height: 12),
            _buildRecentPrestataires(ref),
            const SizedBox(height: 24),
            _buildSectionHeader('Prestataires à vérifier'),
            const SizedBox(height: 12),
            _buildPendingPrestataires(ref),
            const SizedBox(height: 24),
            _buildSectionHeader('Demandes de retrait en attente'),
            const SizedBox(height: 12),
            _buildPendingRetraits(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(WidgetRef ref) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total prestataires',
                stream: FirestoreService.instance.getPrestatairesCount(),
                isOrange: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Commandes aujourd’hui',
                stream: FirestoreService.instance.getCommandesCountToday(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: _RevenueCard()),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Signalements ouverts',
                stream: FirestoreService.instance.getSignalementsCount(
                  'ouvert',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  Widget _buildRecentPrestataires(WidgetRef ref) {
    return StreamBuilder<List<Prestataire>>(
      stream: FirestoreService.instance.getLatestPrestataires(limit: 5),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (list.isEmpty) {
          return Text(
            'Aucun prestataire récent.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          );
        }
        return Column(
          children: [
            ...list.map(
              (prestataire) => _RecentPrestataireCard(prestataire: prestataire),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  if (context.mounted) {
                    context.go('/admin/prestataires');
                  }
                },
                child: Text(
                  'Voir tout',
                  style: GoogleFonts.inter(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPendingPrestataires(WidgetRef ref) {
    return StreamBuilder<List<Prestataire>>(
      stream: FirestoreService.instance.getUnverifiedPrestataires(),
      builder: (context, snapshot) {
        final pending = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (pending.isEmpty) {
          return Text(
            'Aucun prestataire à vérifier.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          );
        }
        return Column(
          children: pending.map((prestataire) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: AppColors.primaryOrange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${prestataire.nom} ${prestataire.prenom}',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${prestataire.categorie} • ${prestataire.zone}',
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    MiwodoButton(
                      label: 'Vérifier',
                      onPressed: () async {
                        await FirestoreService.instance.verifyPrestataire(
                          prestataire.id,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Prestataire vérifié.',
                                style: GoogleFonts.inter(),
                              ),
                            ),
                          );
                        }
                      },
                      variant: MiwodoButtonVariant.primary,
                      width: 110,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPendingRetraits(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('demandes_retrait')
          .where('statut', isEqualTo: 'enAttente')
          .orderBy('cree_le', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (docs.isEmpty) {
          return Text(
            'Aucune demande de retrait en attente.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          );
        }
        return Column(
          children: [
            ...docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final montant = data['montant'] ?? 0;
              final devise = data['devise'] ?? 'XOF';
              final nom = data['prestataire_nom'] ?? 'N/A';
              final source = data['source'] ?? '';
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.account_balance_wallet, color: AppColors.primaryOrange),
                  title: Text(nom, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text('$montant $devise • $source', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  trailing: TextButton(
                    onPressed: () => context.go('/admin/retraits'),
                    child: Text('Traiter', style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w700)),
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.go('/admin/retraits'),
                child: Text('Voir tout', style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.stream,
    this.isOrange = false,
  });

  final String label;
  final Stream<int> stream;
  final bool isOrange;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: stream,
      builder: (context, snapshot) {
        final value = snapshot.data ?? 0;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isOrange ? AppColors.primaryOrange : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              const BoxShadow(
                color: Color.fromARGB(8, 0, 0, 0),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$value',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isOrange ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isOrange
                      ? AppColors.white.withAlpha(224)
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    return StreamBuilder<List<TransactionRecord>>(
      stream: FirestoreService.instance.getTransactions(from: firstDay),
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        final total = list.fold<double>(0.0, (sum, tx) => sum + tx.montant);
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              const BoxShadow(
                color: Color.fromARGB(8, 0, 0, 0),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${total.toStringAsFixed(0)} F',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Revenus ce mois',
                style: GoogleFonts.inter(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentPrestataireCard extends StatelessWidget {
  const _RecentPrestataireCard({required this.prestataire});

  final Prestataire prestataire;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryOrange.withAlpha(36),
          child: Text(
            prestataire.nom.isNotEmpty ? prestataire.nom[0].toUpperCase() : 'P',
            style: const TextStyle(color: AppColors.primaryOrange),
          ),
        ),
        title: Text(
          '${prestataire.nom} ${prestataire.prenom}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${prestataire.categorie} • ${prestataire.zone}',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
