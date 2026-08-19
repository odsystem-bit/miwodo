// screens/prestataires_screen.dart
// Écran de liste des prestataires avec filtres ville et pays

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/zones.dart';
import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../widgets/prestataire_card.dart';
import '../../providers/pays_provider.dart';

// Provider pour les prestataires filtrés
final filteredPrestatairesProvider = StreamProvider.family<List<Prestataire>, String>((ref, filtersKey) {
  // Parse filtersKey: "categorie|paysId"
  final parts = filtersKey.split('|');
  final categorie = parts[0].isEmpty ? null : parts[0];
  final paysId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  
  Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('prestataires');  
  
  // Filtrer uniquement les prestataires actifs
  query = query.where('actif', isEqualTo: true);
  
  if (categorie != null && categorie.isNotEmpty) {
    query = query.where('categorie', isEqualTo: categorie);
  }
  if (paysId != null && paysId.isNotEmpty) {
    query = query.where('paysId', isEqualTo: paysId);
  }
  // Note: on ne filtre plus 'zone' au niveau Firestore car la zone peut être
  // "Ville - Quartier", on filtre la ville en mémoire après récupération
  
  return query.limit(30).snapshots().map((snap) {
    final list = snap.docs.map((d) => Prestataire.fromJson({...d.data(), 'id': d.id})).toList();
    
    // Trier en mémoire: vérifiés, puis par date
    list.sort((a, b) {
      if (a.estVerifie && !b.estVerifie) return -1;
      if (!a.estVerifie && b.estVerifie) return 1;
      return b.creeLe.compareTo(a.creeLe);
    });
    
    return list;
  }).transform(
    StreamTransformer.fromHandlers(
      handleError: (error, stack, sink) {
        if (kDebugMode) print('[filteredPrestatairesProvider] error: $error');
        sink.add(<Prestataire>[]);
      },
    ),
  );
});

class PrestatairesScreen extends ConsumerStatefulWidget {
  const PrestatairesScreen({super.key});

  @override
  ConsumerState<PrestatairesScreen> createState() => _PrestatairesScreenState();
}

class _PrestatairesScreenState extends ConsumerState<PrestatairesScreen> {
  String? _selectedCategorie;
  String? _selectedVille;
  String? _selectedPaysId;
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = ['Tous', 'Artisan', 'Libéral', 'Vendeur', 'Livreur'];
  
  String? _categorieToFirestore(String? label) {
    if (label == null || label == 'Tous') return null;
    switch (label) {
      case 'Artisan': return 'artisan';
      case 'Libéral': return 'liberal';
      case 'Vendeur': return 'vendeur';
      case 'Livreur': return 'livreur';
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final paysAsync = ref.watch(tousLesPaysProvider);
    final paysList = paysAsync.valueOrNull ?? [];
    
    final catFs = _categorieToFirestore(_selectedCategorie);
    final filtersKey = '${catFs ?? ''}|${_selectedPaysId ?? ''}';
    
    final prestatairesAsync = ref.watch(filteredPrestatairesProvider(filtersKey));

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        title: Text(
          'Prestataires',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un prestataire...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.borderGray),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),
          // Filtres
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtre Catégorie
                Text(
                  'Catégorie',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final categorie = _categories[index];
                      final isSelected = _selectedCategorie == categorie;
                      return FilterChip(
                        label: Text(categorie),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategorie = selected ? categorie : null;
                          });
                        },
                        selectedColor: AppColors.primaryOrangeLight,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Filtre Pays
                Text(
                  'Pays',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: paysList.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FilterChip(
                          label: const Text('Tous'),
                          selected: _selectedPaysId == null,
                          onSelected: (selected) {
                            setState(() {
                              _selectedPaysId = selected ? null : null;
                            });
                          },
                          selectedColor: AppColors.primaryOrangeLight,
                          labelStyle: GoogleFonts.inter(
                            fontSize: 13,
                            color: _selectedPaysId == null ? AppColors.primaryOrange : AppColors.textSecondary,
                          ),
                        );
                      }
                      final pays = paysList[index - 1];
                      final isSelected = _selectedPaysId == pays.id;
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(pays.drapeauEmoji),
                            const SizedBox(width: 4),
                            Text(pays.nom),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedPaysId = selected ? pays.id : null;
                          });
                        },
                        selectedColor: AppColors.primaryOrangeLight,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Filtre Ville (dynamique selon le pays sélectionné)
                Text(
                  'Ville',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final villes = _selectedPaysId != null
                      ? ['Toutes', ...Zones.villesParPays(_selectedPaysId!)]
                      : ['Toutes', ...Zones.villesParPays('TG')];
                  return SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: villes.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final ville = villes[index];
                        final isSelected = _selectedVille == ville;
                        return FilterChip(
                          label: Text(ville),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedVille = selected ? ville : null;
                            });
                          },
                        selectedColor: AppColors.primaryOrangeLight,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 13,
                          color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                );
                }),
              ],
            ),
          ),
          const Divider(height: 1),
          // Liste des prestataires
          Expanded(
            child: prestatairesAsync.when(
              data: (prestataires) {
                final searchQuery = _searchController.text.toLowerCase();
                final villeFilter = (_selectedVille != null && _selectedVille != 'Toutes') ? _selectedVille : null;
                
                final filtered = prestataires.where((p) {
                  // Filtre par ville en mémoire
                  if (villeFilter != null) {
                    final pVille = p.zone.contains(' - ') ? p.zone.split(' - ').first : p.zone;
                    if (pVille != villeFilter) return false;
                  }
                  // Filtre par recherche texte
                  if (searchQuery.isEmpty) return true;
                  return p.nom.toLowerCase().contains(searchQuery) ||
                      p.prenom.toLowerCase().contains(searchQuery) ||
                      p.categorie.toLowerCase().contains(searchQuery) ||
                      p.zone.toLowerCase().contains(searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: AppColors.borderGray,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun prestataire trouvé',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final prestataire = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: PrestataireCard(
                        prestataire: prestataire,
                        onTap: () => context.push('/prestataire/${prestataire.id}'),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Erreur: $error',
                  style: GoogleFonts.inter(color: AppColors.errorRed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
