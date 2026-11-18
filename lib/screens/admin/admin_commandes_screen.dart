// screens/admin/admin_commandes_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/commande.dart';
import '../../services/firestore_service.dart';
import 'admin_shell.dart';

class AdminCommandesScreen extends ConsumerStatefulWidget {
  const AdminCommandesScreen({super.key});

  @override
  ConsumerState<AdminCommandesScreen> createState() => _AdminCommandesScreenState();
}

class _AdminCommandesScreenState extends ConsumerState<AdminCommandesScreen> {
  String _statusFilter = 'tous';
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<CommandeVendeur> _allCommandes = [];

  static const int _pageSize = 25;

  final _statusFilters = [
    ('tous', 'Tous'),
    ('paye', 'Payées'),
    ('accepte', 'Acceptées'),
    ('enRoute', 'En route'),
    ('livre', 'Livrées'),
    ('confirme', 'Confirmées'),
    ('litige', 'En litige'),
    ('rembourse', 'Remboursées'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Commandes',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commandes récentes',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _statusFilters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (value, label) = _statusFilters[index];
                  return ChoiceChip(
                    label: Text(label),
                    selected: _statusFilter == value,
                    selectedColor: AppColors.primaryOrange.withAlpha(46),
                    onSelected: (_) => setState(() => _statusFilter = value),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('commandes')
                    .limit(_pageSize)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  _allCommandes = docs.map((doc) {
                    final data = doc.data();
                    data['id'] = doc.id;
                    return CommandeVendeur.fromJson(data, doc.id);
                  }).toList()
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                  _lastDoc = docs.isNotEmpty ? docs.last : null;
                  _hasMore = docs.length == _pageSize;

                  var commandes = _allCommandes;
                  if (_statusFilter != 'tous') {
                    commandes = commandes.where((c) => c.statut.name == _statusFilter).toList();
                  }
                  if (commandes.isEmpty) {
                    return Text(
                      'Aucune commande pour ce filtre.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    );
                  }
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemCount: commandes.length,
                          itemBuilder: (context, index) {
                            final commande = commandes[index];
                            return _CommandeCard(commande: commande);
                          },
                        ),
                      ),
                      if (_hasMore) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: _isLoadingMore ? null : _loadMoreCommandes,
                            icon: _isLoadingMore
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.expand_more),
                            label: Text(_isLoadingMore ? 'Chargement...' : 'Charger plus', style: GoogleFonts.inter(fontSize: 13)),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _loadMoreCommandes() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('commandes')
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      if (snap.docs.isEmpty) {
        _hasMore = false;
      } else {
        final newCommandes = snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return CommandeVendeur.fromJson(data, doc.id);
        }).toList();
        _allCommandes.addAll(newCommandes);
        _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length == _pageSize;
      }
    } catch (e) {
      if (kDebugMode) print('[AdminCommandes] loadMore error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }
}

class _CommandeCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _CommandeCard({required this.commande});

  Color _statusColor() {
    switch (commande.statut) {
      case StatutCommande.paye:
        return AppColors.primaryOrange;
      case StatutCommande.accepte:
      case StatutCommande.enRoute:
        return const Color(0xFF2196F3);
      case StatutCommande.livre:
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        return AppColors.successGreen;
      case StatutCommande.litige:
        return AppColors.errorRed;
      case StatutCommande.rembourse:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        title: Text(
          commande.numero.isNotEmpty ? commande.numero : 'CMD-${commande.id.substring(0, 8)}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _statusColor().withAlpha(30),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                commande.statut.label,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: _statusColor()),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              commande.clientNom,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        trailing: Text(
          '${commande.totalClient.toStringAsFixed(0)} F',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primaryOrange, fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Client', '${commande.clientNom} • ${commande.clientTelephone}'),
                _infoRow('Zone', commande.clientZone),
                _infoRow('Adresse', commande.clientAdresseTexte),
                _infoRow('Vendeur', '${commande.vendeurNom}${commande.vendeurBoutiqueNom != null ? ' (${commande.vendeurBoutiqueNom})' : ''}'),
                _infoRow('Livreur', '${commande.livreurNom} • ${commande.livreurTelephone}'),
                _infoRow('Articles', '${commande.articles.length} article(s)'),
                _infoRow('Sous-total', '${commande.sousTotalArticles.toStringAsFixed(0)} F'),
                _infoRow('Frais livraison', '${commande.fraisLivraison.toStringAsFixed(0)} F'),
                _infoRow('Commission', '${commande.commissionMiwodo.toStringAsFixed(0)} F'),
                _infoRow('Montant vendeur', '${commande.montantVendeur.toStringAsFixed(0)} F'),
                _infoRow('Escrow', commande.escrowStatut.label),
                _infoRow('Date', '${commande.createdAt.day}/${commande.createdAt.month}/${commande.createdAt.hour}:${commande.createdAt.minute.toString().padLeft(2, '0')}'),
                if (commande.litigeDescription != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.errorRed.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Litige', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.errorRed, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(commande.litigeDescription!, style: GoogleFonts.inter(fontSize: 12)),
                        if (commande.litigeNoteAdmin != null) ...[
                          const SizedBox(height: 4),
                          Text('Note admin: ${commande.litigeNoteAdmin}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (commande.statut == StatutCommande.litige) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text('Résoudre (confirmer)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _changeStatut(context, 'confirme'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Rembourser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _changeStatut(context, 'rembourse'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (commande.statut != StatutCommande.confirme && commande.statut != StatutCommande.forceConfirme && commande.statut != StatutCommande.rembourse)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.gavel, size: 18),
                          label: const Text('Mettre en litige'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorRed,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _changeStatut(context, 'litige'),
                        ),
                      if (commande.statut != StatutCommande.rembourse)
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Rembourser'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textSecondary,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _changeStatut(context, 'rembourse'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Future<void> _changeStatut(BuildContext context, String newStatut) async {
    try {
      await FirestoreService.instance.updateCommandeStatut(commande.id, newStatut);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Statut mis à jour: $newStatut')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}
