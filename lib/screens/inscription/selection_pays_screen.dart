// screens/inscription/selection_pays_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../models/pays.dart';
import '../../providers/pays_provider.dart';

class SelectionPaysScreen extends ConsumerStatefulWidget {
  /// Code ISO du pays détecté par GPS (peut être null).
  final String? detectedCountryCode;

  const SelectionPaysScreen({super.key, this.detectedCountryCode});

  @override
  ConsumerState<SelectionPaysScreen> createState() => _SelectionPaysScreenState();
}

class _SelectionPaysScreenState extends ConsumerState<SelectionPaysScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paysAsync = ref.watch(tousLesPaysProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Où êtes-vous ?',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sélectionnez votre pays pour continuer',
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Rechercher votre pays…',
                      hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: AppColors.surfaceGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: paysAsync.when(
                data: (tousPays) {
                  final filtered = _query.isEmpty
                      ? tousPays
                      : tousPays.where((p) =>
                          p.nom.toLowerCase().contains(_query) ||
                          p.id.toLowerCase().contains(_query)).toList();

                  // Grouper par région
                  final Map<String, List<Pays>> grouped = {};
                  for (final p in filtered) {
                    grouped.putIfAbsent(p.region, () => []).add(p);
                  }

                  // Ordre des régions
                  const regionOrder = [
                    'afrique_ouest', 'afrique_centrale', 'afrique_est',
                    'europe', 'amerique',
                  ];
                  final regions = regionOrder
                      .where((r) => grouped.containsKey(r))
                      .toList();

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: regions.length,
                    itemBuilder: (context, idx) {
                      final region = regions[idx];
                      final list = grouped[region]!;
                      return _RegionSection(
                        regionLabel: _regionLabel(region),
                        pays: list,
                        detectedCode: widget.detectedCountryCode,
                        onSelect: (pays) => _onSelectPays(pays),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _regionLabel(String region) {
    switch (region) {
      case 'afrique_ouest': return 'Afrique de l\'Ouest';
      case 'afrique_centrale': return 'Afrique Centrale';
      case 'afrique_est': return 'Afrique de l\'Est';
      case 'europe': return 'Europe';
      case 'amerique': return 'Amériques';
      default: return region;
    }
  }

  Future<void> _onSelectPays(Pays pays) async {
    await ref.read(paysSelectionneProvider.notifier).selectionner(pays);
    if (mounted) context.go('/accueil');
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _RegionSection extends StatelessWidget {
  final String regionLabel;
  final List<Pays> pays;
  final String? detectedCode;
  final void Function(Pays) onSelect;

  const _RegionSection({
    required this.regionLabel,
    required this.pays,
    required this.detectedCode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            regionLabel,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        ...pays.map((p) => _PaysListTile(
              pays: p,
              isDetected: p.id == detectedCode,
              onSelect: p.actif ? () => onSelect(p) : null,
            )),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class _PaysListTile extends StatelessWidget {
  final Pays pays;
  final bool isDetected;
  final VoidCallback? onSelect;

  const _PaysListTile({
    required this.pays,
    required this.isDetected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !pays.actif;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDetected ? AppColors.primaryOrangeLight : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isDetected ? Border.all(color: AppColors.primaryOrange.withAlpha(80)) : null,
          ),
          child: Row(
            children: [
              // Drapeau emoji
              Text(pays.drapeauEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 14),
              // Nom + devise
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          pays.nom,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: isDisabled ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                        if (isDetected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Votre position',
                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pays.devise} · ${pays.symbole}',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Prix inscription
              if (!isDisabled)
                Text(
                  formatPrix(pays.inscriptionMontant, pays.symbole),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOrange,
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Bientôt',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
