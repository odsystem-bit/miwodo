// screens/admin/admin_prestataires_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import 'admin_shell.dart';

enum PrestataireAdminFilter { tous, verifies, nonVerifies, suspendus }

final adminPrestataireSearchProvider = StateProvider<String>((ref) => '');
final adminPrestataireFilterProvider = StateProvider<PrestataireAdminFilter>(
  (ref) => PrestataireAdminFilter.tous,
);
final adminPrestataireCategorieProvider = StateProvider<Categorie?>(
  (ref) => null,
);

class AdminPrestatairesScreen extends ConsumerWidget {
  const AdminPrestatairesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(adminPrestataireSearchProvider);
    final filter = ref.watch(adminPrestataireFilterProvider);
    final category = ref.watch(adminPrestataireCategorieProvider);
    final adminRole = ref.watch(adminRoleProvider).asData?.value;
    final zone = adminRole?.zone;

    return AdminShell(
      title: 'Prestataires',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildSearchBar(context, ref, query),
            const SizedBox(height: 14),
            _buildFilterChips(context, ref, filter),
            const SizedBox(height: 14),
            _buildCategoryDropdown(context, ref, category),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Prestataire>>(
                stream: FirestoreService.instance.getPrestataires(
                  categorie: category,
                  zone: zone,
                ),
                builder: (context, snapshot) {
                  final list = snapshot.data ?? [];
                  final filtered = _applyFilters(list, query, filter);
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (filtered.isEmpty) {
                    return Text(
                      'Aucun prestataire ne correspond aux filtres.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    );
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _PrestataireAdminRow(prestataire: filtered[index]);
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

  Widget _buildSearchBar(BuildContext context, WidgetRef ref, String query) {
    return TextField(
      onChanged: (value) =>
          ref.read(adminPrestataireSearchProvider.notifier).state = value,
      decoration: InputDecoration(
        hintText: 'Rechercher un prestataire',
        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    WidgetRef ref,
    PrestataireAdminFilter filter,
  ) {
    return Wrap(
      spacing: 10,
      children: PrestataireAdminFilter.values.map((option) {
        final label = {
          PrestataireAdminFilter.tous: 'Tous',
          PrestataireAdminFilter.verifies: 'Vérifiés',
          PrestataireAdminFilter.nonVerifies: 'Non vérifiés',
          PrestataireAdminFilter.suspendus: 'Suspendus',
        }[option]!;
        return ChoiceChip(
          label: Text(label),
          selected: filter == option,
          selectedColor: AppColors.primaryOrange.withAlpha(46),
          onSelected: (_) =>
              ref.read(adminPrestataireFilterProvider.notifier).state = option,
        );
      }).toList(),
    );
  }

  Widget _buildCategoryDropdown(
    BuildContext context,
    WidgetRef ref,
    Categorie? category,
  ) {
    return Row(
      children: [
        const Icon(Icons.category, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButton<Categorie?>(
            value: category,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('Toutes catégories'),
              ),
              DropdownMenuItem(
                value: Categorie.artisan,
                child: Text('Artisans'),
              ),
              DropdownMenuItem(
                value: Categorie.liberal,
                child: Text('Libéraux'),
              ),
              DropdownMenuItem(
                value: Categorie.vendeur,
                child: Text('Vendeurs'),
              ),
              DropdownMenuItem(
                value: Categorie.livreur,
                child: Text('Livreurs'),
              ),
            ],
            onChanged: (value) =>
                ref.read(adminPrestataireCategorieProvider.notifier).state =
                    value,
          ),
        ),
      ],
    );
  }

  List<Prestataire> _applyFilters(
    List<Prestataire> list,
    String query,
    PrestataireAdminFilter filter,
  ) {
    var results = list;
    if (query.isNotEmpty) {
      results = results.where((item) {
        final search = query.toLowerCase();
        return item.nom.toLowerCase().contains(search) ||
            item.prenom.toLowerCase().contains(search) ||
            item.categorie.toLowerCase().contains(search) ||
            item.zone.toLowerCase().contains(search);
      }).toList();
    }
    switch (filter) {
      case PrestataireAdminFilter.tous:
        return results;
      case PrestataireAdminFilter.verifies:
        return results.where((item) => item.estVerifie && item.actif).toList();
      case PrestataireAdminFilter.nonVerifies:
        return results.where((item) => !item.estVerifie && item.actif).toList();
      case PrestataireAdminFilter.suspendus:
        return results.where((item) => !item.actif).toList();
    }
  }
}

class _PrestataireAdminRow extends StatelessWidget {
  const _PrestataireAdminRow({required this.prestataire});

  final Prestataire prestataire;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primaryOrange.withAlpha(36),
              child: Text(
                prestataire.nom.isNotEmpty
                    ? prestataire.nom[0].toUpperCase()
                    : 'P',
                style: const TextStyle(color: AppColors.primaryOrange),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${prestataire.nom} ${prestataire.prenom}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${prestataire.categorie} • ${prestataire.zone}',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatusBadge(
                        text: prestataire.estVerifie
                            ? 'Vérifié'
                            : 'Non vérifié',
                        color: prestataire.estVerifie
                            ? AppColors.primaryOrange.withAlpha(36)
                            : AppColors.errorRed.withAlpha(31),
                      ),
                      const SizedBox(width: 8),
                      if (!prestataire.actif)
                        _StatusBadge(
                          text: 'Suspendu',
                          color: AppColors.errorRed.withAlpha(31),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (action) => _handleAction(context, action),
              itemBuilder: (context) => [
                if (!prestataire.estVerifie)
                  const PopupMenuItem(value: 'verify', child: Text('Vérifier')),
                if (prestataire.isArtisan)
                  PopupMenuItem(
                    value: 'zones',
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Text('Zones (${prestataire.maxZonesIntervention})'),
                      ],
                    ),
                  ),
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(
                  value: 'suspend',
                  child: Text(prestataire.actif ? 'Suspendre' : 'Réactiver'),
                ),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(BuildContext context, String action) {
    switch (action) {
      case 'verify':
        FirestoreService.instance.verifyPrestataire(prestataire.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Prestataire vérifié.')));
        break;
      case 'zones':
        _showZonesDialog(context);
        break;
      case 'edit':
        _showEditDialog(context);
        break;
      case 'suspend':
        if (prestataire.actif) {
          FirestoreService.instance.suspendPrestataire(prestataire.id);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Prestataire suspendu.')));
        } else {
          FirestoreService.instance.togglePrestataireActif(prestataire.id, true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Prestataire réactivé.')));
        }
        break;
      case 'delete':
        _confirmDelete(context);
        break;
    }
  }

  Future<void> _showZonesDialog(BuildContext context) async {
    int maxZones = prestataire.maxZonesIntervention;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.primaryOrange),
                  const SizedBox(width: 8),
                  const Text('Limite de zones'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${prestataire.prenom} ${prestataire.nom}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zones actuelles : ${prestataire.zonesIntervention.length}/${prestataire.maxZonesIntervention}',
                    style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Text('Nouvelle limite :', style: GoogleFonts.inter(fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: maxZones > 1 ? () => setDialogState(() => maxZones--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: AppColors.primaryOrange,
                        iconSize: 32,
                      ),
                      Container(
                        width: 60,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$maxZones',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                        ),
                      ),
                      IconButton(
                        onPressed: maxZones < 10 ? () => setDialogState(() => maxZones++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: AppColors.primaryOrange,
                        iconSize: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4ED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.primaryOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Le prestataire pourra sélectionner jusqu\'à $maxZones zones d\'intervention.',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
                  onPressed: () async {
                    await FirestoreService.instance.updatePrestataire(prestataire.id, {
                      'max_zones_intervention': maxZones,
                    });
                    if (!context.mounted) return;
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Limite de zones mise à jour : $maxZones'),
                        backgroundColor: AppColors.successGreen,
                      ),
                    );
                  },
                  child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditDialog(BuildContext context) async {
    final nameController = TextEditingController(text: prestataire.nom);
    final zoneController = TextEditingController(text: prestataire.zone);
    final categorieController = TextEditingController(
      text: prestataire.categorie,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifier le profil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: zoneController,
                decoration: const InputDecoration(labelText: 'Zone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categorieController,
                decoration: const InputDecoration(labelText: 'Catégorie'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                await FirestoreService.instance
                    .updatePrestataire(prestataire.id, {
                      'nom': nameController.text.trim(),
                      'zone': zoneController.text.trim(),
                      'categorie': categorieController.text.trim(),
                    });
                if (!context.mounted) return;
                navigator.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Profil mis à jour.')),
                );
              },
              child: const Text('Sauvegarder'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer le prestataire'),
          content: const Text(
            'Cette action est irréversible. Confirmez-vous la suppression ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await FirestoreService.instance.deletePrestataire(prestataire.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Prestataire supprimé.')));
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
