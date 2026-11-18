// screens/admin/admin_revenus_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/transaction_record.dart';
import '../../services/firestore_service.dart';
import 'admin_shell.dart';

enum RevenuePeriod { ceMois, troisMois, sixMois, cetteAnnee }

class AdminRevenusScreen extends ConsumerStatefulWidget {
  const AdminRevenusScreen({super.key});

  @override
  AdminRevenusScreenState createState() => AdminRevenusScreenState();
}

class AdminRevenusScreenState extends ConsumerState<AdminRevenusScreen> {
  RevenuePeriod selectedPeriod = RevenuePeriod.ceMois;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final from = _startFromPeriod(now, selectedPeriod);
    return AdminShell(
      title: 'Revenus',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            _buildRevenueCards(from),
            const SizedBox(height: 24),
            Text(
              'Dernieres transactions',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildTransactionList(from)),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Wrap(
      spacing: 10,
      children: RevenuePeriod.values.map((period) {
        final label = {
          RevenuePeriod.ceMois: 'Ce mois',
          RevenuePeriod.troisMois: '3 mois',
          RevenuePeriod.sixMois: '6 mois',
          RevenuePeriod.cetteAnnee: 'Cette annee',
        }[period]!;
        return ChoiceChip(
          label: Text(label),
          selected: selectedPeriod == period,
          selectedColor: AppColors.primaryOrange.withAlpha(46),
          onSelected: (_) => setState(() => selectedPeriod = period),
        );
      }).toList(),
    );
  }

  Widget _buildRevenueCards(DateTime from) {
    return StreamBuilder<List<TransactionRecord>>(
      stream: FirestoreService.instance.getTransactions(from: from),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];
        final inscriptions = transactions.where((tx) => tx.type == 'inscription').toList();
        final pubStandard = transactions.where((tx) => tx.type == 'pub_standard').toList();
        final pubPremium = transactions.where((tx) => tx.type == 'pub_premium').toList();
        final commandes = transactions.where((tx) => tx.type == 'commande').toList();

        final inscriptionTotal = inscriptions.fold<double>(0, (s, tx) => s + tx.montant);
        final pubStandardTotal = pubStandard.fold<double>(0, (s, tx) => s + tx.montant);
        final pubPremiumTotal = pubPremium.fold<double>(0, (s, tx) => s + tx.montant);
        final commandeTotal = commandes.fold<double>(0, (s, tx) => s + tx.montant);
        final total = inscriptionTotal + pubStandardTotal + pubPremiumTotal + commandeTotal;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Inscriptions (${inscriptions.length})',
                    value: '${inscriptionTotal.toStringAsFixed(0)} F',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Pub Standard (${pubStandard.length})',
                    value: '${pubStandardTotal.toStringAsFixed(0)} F',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Pub Premium (${pubPremium.length})',
                    value: '${pubPremiumTotal.toStringAsFixed(0)} F',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    label: 'Commandes (${commandes.length})',
                    value: '${commandeTotal.toStringAsFixed(0)} F',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _TotalCard(total: total)),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionList(DateTime from) {
    return StreamBuilder<List<TransactionRecord>>(
      stream: FirestoreService.instance.getTransactions(from: from),
      builder: (context, snapshot) {
        final transactions = snapshot.data ?? [];
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (transactions.isEmpty) {
          return Text(
            'Aucune transaction trouvee.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final tx = transactions[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                title: Text(
                  tx.paymentId,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${tx.type} - ${tx.createdAt.day}/${tx.createdAt.month}/${tx.createdAt.year}',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                trailing: Text(
                  '${tx.montant.toStringAsFixed(0)} F',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  DateTime _startFromPeriod(DateTime now, RevenuePeriod period) {
    switch (period) {
      case RevenuePeriod.ceMois:
        return DateTime(now.year, now.month, 1);
      case RevenuePeriod.troisMois:
        final month = now.month - 2;
        return DateTime(now.year, month < 1 ? 1 : month, 1);
      case RevenuePeriod.sixMois:
        final month = now.month - 5;
        return DateTime(now.year, month < 1 ? 1 : month, 1);
      case RevenuePeriod.cetteAnnee:
        return DateTime(now.year, 1, 1);
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${total.toStringAsFixed(0)} F',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TOTAL',
            style: GoogleFonts.inter(
              color: AppColors.white.withAlpha(230),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
