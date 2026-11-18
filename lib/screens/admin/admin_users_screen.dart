// screens/admin/admin_users_screen.dart
// Gestion des utilisateurs (comptes prestataires) — suspendre, vérifier
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../services/firestore_service.dart';
import '../../widgets/miwodo_button.dart';
import 'admin_shell.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  String _searchQuery = '';
  String _filterStatus = 'tous'; // tous, actifs, suspendus, verifies

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Utilisateurs',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Barre de recherche
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, téléphone, email...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Filtres statut
            Wrap(
              spacing: 10,
              children: [
                _buildFilterChip('tous', 'Tous'),
                _buildFilterChip('actifs', 'Actifs'),
                _buildFilterChip('suspendus', 'Suspendus'),
                _buildFilterChip('verifies', 'Vérifiés'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Prestataire>>(
                stream: FirestoreService.instance.getPrestataires(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  var list = snapshot.data ?? [];
                  // Filtrage
                  if (_searchQuery.isNotEmpty) {
                    list = list.where((p) {
                      return p.nom.toLowerCase().contains(_searchQuery) ||
                          p.prenom.toLowerCase().contains(_searchQuery) ||
                          p.telephone.toLowerCase().contains(_searchQuery) ||
                          (p.email?.toLowerCase().contains(_searchQuery) ?? false);
                    }).toList();
                  }
                  switch (_filterStatus) {
                    case 'actifs':
                      list = list.where((p) => p.actif).toList();
                      break;
                    case 'suspendus':
                      list = list.where((p) => !p.actif).toList();
                      break;
                    case 'verifies':
                      list = list.where((p) => p.estVerifie).toList();
                      break;
                  }
                  if (list.isEmpty) {
                    return Text(
                      'Aucun utilisateur trouvé.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    );
                  }
                  return ListView.separated(
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final p = list[index];
                      return _UserCard(prestataire: p, onRefresh: () => setState(() {}));
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filterStatus == value,
      selectedColor: AppColors.primaryOrange.withAlpha(46),
      onSelected: (_) => setState(() => _filterStatus = value),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Prestataire prestataire;
  final VoidCallback onRefresh;

  const _UserCard({required this.prestataire, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryOrangeLight,
          child: Text(
            '${prestataire.prenom[0]}${prestataire.nom[0]}',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
          ),
        ),
        title: Text(
          '${prestataire.prenom} ${prestataire.nom}',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            if (prestataire.estVerifie)
              _badge('Vérifié', AppColors.successGreen)
            else
              _badge('Non vérifié', AppColors.textSecondary),
            const SizedBox(width: 6),
            if (!prestataire.actif) _badge('Suspendu', AppColors.errorRed),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Téléphone', prestataire.telephone),
                _infoRow('Email', prestataire.email ?? '—'),
                _infoRow('Catégorie', prestataire.categorie),
                _infoRow('Pays', prestataire.paysNom),
                _infoRow('Ville', prestataire.ville),
                _infoRow('Zone', prestataire.zone),
                _infoRow('Note', '${prestataire.noteMoyenne.toStringAsFixed(1)}/5 (${prestataire.nombreAvis} avis)'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!prestataire.estVerifie)
                      MiwodoButton(
                        label: 'Vérifier',
                        onPressed: () async {
                          await FirestoreService.instance.verifyPrestataire(prestataire.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Prestataire vérifié ✓')),
                            );
                          }
                          onRefresh();
                        },
                        width: 120,
                      ),
                    MiwodoButton(
                      label: prestataire.actif ? 'Suspendre' : 'Réactiver',
                      variant: prestataire.actif ? MiwodoButtonVariant.secondary : MiwodoButtonVariant.primary,
                      onPressed: () async {
                        await FirestoreService.instance.togglePrestataireActif(prestataire.id, !prestataire.actif);
                        onRefresh();
                      },
                      width: 130,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
