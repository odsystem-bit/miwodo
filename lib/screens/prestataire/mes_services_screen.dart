// screens/prestataire/mes_services_screen.dart
// Écran complet de gestion des services adapté par catégorie (ARTISAN, LIBÉRAL, VENDEUR, LIVREUR)

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../models/config_models.dart';
import '../../models/prestataire.dart';
import '../../models/service_prestataire.dart';
import '../../providers/config_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

// Provider pour les services d'un prestataire
final servicesProvider = StreamProvider.family<List<ServicePrestataire>, String>((ref, prestataireId) {
  return FirebaseFirestore.instance
      .collection('services')
      .where('prestataireId', isEqualTo: prestataireId)
      .limit(50)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => ServicePrestataire.fromJson({...d.data(), 'id': d.id})).toList();
        list.sort((a, b) => a.ordre.compareTo(b.ordre));
        return list;
      });
});

// Provider pour le prestataire connecté
final currentPrestataireProvider = StreamProvider.family<Prestataire?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('prestataires')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? Prestataire.fromJson({...snap.data()!, 'id': snap.id}) : null);
});

const List<String> _jours = ['lun', 'mar', 'mer', 'jeu', 'ven', 'sam', 'dim'];
const List<String> _joursLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const List<String> _languesOptions = ['Français', 'Éwé', 'Kabyè', 'Mina', 'Anglais', 'Autre'];
const List<String> _experienceOptions = ["Moins d'1 an", "1-2 ans", "3-5 ans", "6-10 ans", "Plus de 10 ans"];
const List<String> _delaiOptions = ['Immédiat', '15 minutes', '30 minutes', '1 heure', '2 heures', 'Sur demande'];
const List<String> _capaciteOptions = ['Petits colis (< 5kg)', 'Moyen (5-20kg)', 'Lourd (> 20kg)'];

class MesServicesScreen extends ConsumerStatefulWidget {
  final String prestataireId;

  const MesServicesScreen({super.key, required this.prestataireId});

  @override
  ConsumerState<MesServicesScreen> createState() => _MesServicesScreenState();
}

class _MesServicesScreenState extends ConsumerState<MesServicesScreen> {
  bool _hasChanges = false;
  bool _isSaving = false;

  // Champs communs
  List<String> _joursDisponibles = [];
  bool _disponible = true;

  // Champs ARTISAN
  List<String> _zonesIntervention = [];
  String? _anneesExperience;
  String _specialites = '';

  // Champs LIBÉRAL
  String _cabinetNom = '';
  String _cabinetAdresse = '';
  String _diplome = '';
  bool _consultationDomicile = false;
  int _surcoutDeplacement = 0;
  List<String> _langues = [];

  // Champs VENDEUR
  String _boutiqueNom = '';
  String _boutiqueDescription = '';
  String? _delaiPreparation;
  bool _livraisonDisponible = false;
  List<String> _zonesLivraison = [];
  bool _retraitPlace = false;
  String _politiqueRetour = '';
  bool _charteAcceptee = false;

  // Champs LIVREUR
  String? _typeEngin;
  String? _capaciteCharge;
  Map<String, int> _tarifsZones = {};
  bool _livraisonExpress = false;
  int _surcoutExpress = 0;
  bool _disponibleWeekend = false;
  bool _disponibleNuit = false;

  @override
  void initState() {
    super.initState();
    _loadPrestataireData();
  }

  Future<void> _loadPrestataireData() async {
    final doc = await FirebaseFirestore.instance.collection('prestataires').doc(widget.prestataireId).get();
    if (!doc.exists) return;
    final p = Prestataire.fromJson({...doc.data()!, 'id': doc.id});
    
    setState(() {
      _joursDisponibles = List.from(p.joursDisponibles);
      _disponible = p.estDisponible;
      _zonesIntervention = List.from(p.zonesIntervention);
      _anneesExperience = p.anneesExperience;
      _specialites = p.specialites ?? '';
      _cabinetNom = p.cabinetNom ?? '';
      _cabinetAdresse = p.cabinetAdresse ?? '';
      _diplome = p.diplome ?? '';
      _consultationDomicile = p.consultationDomicile;
      _surcoutDeplacement = p.surcoutDeplacement ?? 0;
      _langues = List.from(p.langues);
      _boutiqueNom = p.boutiqueNom ?? '';
      _boutiqueDescription = p.boutiqueDescription ?? '';
      _delaiPreparation = p.delaiPreparation;
      _livraisonDisponible = p.livraisonDisponible;
      _zonesLivraison = List.from(p.zonesLivraison);
      _retraitPlace = p.retraitPlace;
      _politiqueRetour = p.politiqueRetour ?? '';
      _charteAcceptee = p.charteAcceptee;
      _typeEngin = p.typeEngin;
      _capaciteCharge = p.capaciteCharge;
      _tarifsZones = Map.from(p.tarifsZones ?? {});
      _livraisonExpress = p.livraisonExpress;
      _surcoutExpress = p.surcoutExpress ?? 0;
      _disponibleWeekend = p.disponibleWeekend;
      _disponibleNuit = p.disponibleNuit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prestataireAsync = ref.watch(currentPrestataireProvider(widget.prestataireId));
    final servicesAsync = ref.watch(servicesProvider(widget.prestataireId));
    final zonesAsync = ref.watch(configZonesActivesFullProvider);

    return prestataireAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (prestataire) {
        if (prestataire == null) {
          return Scaffold(body: Center(child: Text('Prestataire non trouvé')));
        }
        
        final categorie = prestataire.categorie.toUpperCase();
        final maxServices = prestataire.isLiberal ? 8 : 10;

        return Scaffold(
          backgroundColor: AppColors.surfaceGray,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const MiwodoSvgIcon('assets/icons/ic_arrow_back.svg', size: 24),
              onPressed: () => context.pop(),
            ),
            title: Row(
              children: [
                Text('Mes services', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(categorie, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: _hasChanges && !_isSaving ? () => _saveAll(prestataire) : null,
                child: Text(
                  'Enregistrer',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _hasChanges ? AppColors.primaryOrange : AppColors.primaryOrange.withAlpha(100),
                  ),
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: AppColors.borderGray),
            ),
          ),
          body: servicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Erreur: $e')),
            data: (services) => zonesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Erreur zones: $e')),
              data: (zones) => SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Barre de complétion
                    _buildCompletionCard(prestataire, services),
                    const SizedBox(height: 20),

                    // Sections selon catégorie
                    if (prestataire.isArtisan) ..._buildArtisanSections(services, zones, maxServices, prestataire.maxZonesIntervention),
                    if (prestataire.isLiberal) ..._buildLiberalSections(services, zones, maxServices),
                    if (prestataire.isVendeur) ..._buildVendeurSections(services, zones),
                    if (prestataire.isLivreur) ..._buildLivreurSections(zones),
                    if (!prestataire.isArtisan && !prestataire.isLiberal && !prestataire.isVendeur && !prestataire.isLivreur)
                      Card(
                        color: AppColors.primaryOrange.withAlpha(20),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Catégorie non reconnue',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Catégorie actuelle: "${prestataire.categorie}". Veuillez mettre à jour votre profil avec une catégorie valide (Artisan, Libéral, Vendeur ou Livreur).',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 12),
                              MiwodoButton(
                                label: 'Modifier mon profil',
                                onPressed: () => context.push('/profil/${widget.prestataireId}'),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BARRE DE COMPLÉTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCompletionCard(Prestataire p, List<ServicePrestataire> services) {
    final completion = _calculateCompletion(p, services);
    return Card(
      color: const Color(0xFFFFF4ED),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const MiwodoSvgIcon('assets/icons/ic_star.svg', size: 18, color: AppColors.primaryOrange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Complétion de votre profil', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: completion,
                    backgroundColor: AppColors.borderGray,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primaryOrange),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${(completion * 100).toInt()}% complet · Un profil complet reçoit 3× plus de contacts',
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateCompletion(Prestataire p, List<ServicePrestataire> services) {
    int points = 0;
    int total = 5;
    if (services.isNotEmpty) points++;
    if (_joursDisponibles.isNotEmpty) points++;
    if (p.description != null && p.description!.isNotEmpty) points++;
    if (p.photosPortfolio.isNotEmpty) points++;
    if (p.isArtisan && _zonesIntervention.isNotEmpty) points++;
    if (p.isLiberal && _diplome.isNotEmpty) points++;
    if (p.isVendeur && _boutiqueNom.isNotEmpty) points++;
    if (p.isLivreur && _typeEngin != null) points++;
    return points / total;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTIONS ARTISAN
  // ═══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildArtisanSections(List<ServicePrestataire> services, List<ConfigZone> zones, int maxServices, int maxZones) {
    return [
      _buildServicesSection(services, maxServices, ['F/jour', 'F/m²', 'F/pièce', 'F/heure', 'Sur devis']),
      const SizedBox(height: 24),
      _buildZonesSection(zones, maxZones),
      const SizedBox(height: 24),
      _buildExperienceSection(),
      const SizedBox(height: 24),
      _buildDisponibilitesSection(),
    ];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTIONS LIBÉRAL
  // ═══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildLiberalSections(List<ServicePrestataire> services, List<ConfigZone> zones, int maxServices) {
    return [
      _buildServicesSection(services, maxServices, ['F/consultation', 'F/heure', 'F/dossier', 'F/séance', 'Sur devis']),
      const SizedBox(height: 24),
      _buildCabinetSection(),
      const SizedBox(height: 24),
      _buildLanguesSection(),
      const SizedBox(height: 24),
      _buildDisponibilitesSection(),
    ];
  }

  Widget _buildCabinetSection() {
    return _buildSection(
      title: 'Informations professionnelles',
      children: [
        _buildTextField('Nom du cabinet / Structure', _cabinetNom, (v) {
          setState(() { _cabinetNom = v; _hasChanges = true; });
        }, hint: 'ex: Cabinet Mensah & Associés'),
        const SizedBox(height: 12),
        _buildTextField('Adresse du cabinet', _cabinetAdresse, (v) {
          setState(() { _cabinetAdresse = v; _hasChanges = true; });
        }, hint: 'ex: Rue des Ambassadeurs, Tokoin'),
        const SizedBox(height: 12),
        _buildTextField('Diplôme / Certification principale', _diplome, (v) {
          setState(() { _diplome = v; _hasChanges = true; });
        }, hint: 'ex: Barreau du Togo, Ordre des Médecins'),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _consultationDomicile,
              onChanged: (v) => setState(() { _consultationDomicile = v; _hasChanges = true; }),
              activeTrackColor: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text('Consultation à domicile possible', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        if (_consultationDomicile) ...[
          const SizedBox(height: 8),
          _buildTextField('Surcoût déplacement (F CFA)', _surcoutDeplacement.toString(), (v) {
            setState(() { _surcoutDeplacement = int.tryParse(v) ?? 0; _hasChanges = true; });
          }, keyboardType: TextInputType.number),
        ],
      ],
    );
  }

  Widget _buildLanguesSection() {
    return _buildSection(
      title: 'Langues de travail',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _languesOptions.map((langue) {
            final selected = _langues.contains(langue);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (selected) {
                    _langues.remove(langue);
                  } else {
                    _langues.add(langue);
                  }
                  _hasChanges = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryOrange : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(langue, style: GoogleFonts.inter(fontSize: 13, color: selected ? Colors.white : const Color(0xFF6B7280))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTIONS VENDEUR
  // ═══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildVendeurSections(List<ServicePrestataire> services, List<ConfigZone> zones) {
    return [
      _buildBoutiqueSection(),
      const SizedBox(height: 24),
      // Section produits
      _buildSection(
        title: 'Mes produits',
        subtitle: 'Gérez votre inventaire',
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primaryOrange, width: 1, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2, size: 40, color: AppColors.primaryOrange),
                const SizedBox(height: 12),
                Text('Gérez vos produits', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Ajoutez, modifiez et supprimez vos produits', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                MiwodoButton(
                  label: 'Aller à mes produits',
                  variant: MiwodoButtonVariant.secondary,
                  fullWidth: true,
                  onPressed: () => context.push('/mes-produits/${widget.prestataireId}'),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      _buildHorairesVendeurSection(),
      const SizedBox(height: 24),
      _buildLivraisonVendeurSection(zones),
      const SizedBox(height: 24),
      _buildCharteMiwodoSection(),
    ];
  }

  Widget _buildBoutiqueSection() {
    return _buildSection(
      title: 'Informations boutique',
      children: [
        _buildTextField('Nom de la boutique *', _boutiqueNom, (v) {
          setState(() { _boutiqueNom = v; _hasChanges = true; });
        }, hint: 'ex: Boutique Espoir, Restaurant Saveur', maxLength: 40),
        const SizedBox(height: 12),
        _buildTextField('Description de la boutique', _boutiqueDescription, (v) {
          setState(() { _boutiqueDescription = v; _hasChanges = true; });
        }, hint: 'Décrivez vos produits, votre spécialité...', maxLines: 3, maxLength: 200),
      ],
    );
  }

  Widget _buildHorairesVendeurSection() {
    return _buildSection(
      title: 'Horaires & Livraison',
      children: [
        _buildJoursSelector(),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _delaiPreparation,
          decoration: _inputDecoration('Délai de préparation commande'),
          items: _delaiOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
          onChanged: (v) => setState(() { _delaiPreparation = v; _hasChanges = true; }),
        ),
      ],
    );
  }

  Widget _buildLivraisonVendeurSection(List<ConfigZone> zones) {
    return _buildSection(
      title: 'Livraison & Retrait',
      children: [
        Row(
          children: [
            Switch(
              value: _livraisonDisponible,
              onChanged: (v) => setState(() { _livraisonDisponible = v; _hasChanges = true; }),
              activeTrackColor: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text('Livraison disponible', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        if (_livraisonDisponible) ...[
          const SizedBox(height: 12),
          Text('Zones livrées', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: zones.map((z) {
              final selected = _zonesLivraison.contains(z.id);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _zonesLivraison.remove(z.id);
                    } else {
                      _zonesLivraison.add(z.id);
                    }
                    _hasChanges = true;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryOrange : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(z.nom, style: GoogleFonts.inter(fontSize: 13, color: selected ? Colors.white : const Color(0xFF6B7280))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildTextField('Politique de retour / échange', _politiqueRetour, (v) {
            setState(() { _politiqueRetour = v; _hasChanges = true; });
          }, maxLines: 2),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _retraitPlace,
              onChanged: (v) => setState(() { _retraitPlace = v; _hasChanges = true; }),
              activeTrackColor: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text('Retrait sur place possible', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildCharteMiwodoSection() {
    return Card(
      color: const Color(0xFFFFF4ED),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.primaryOrange, size: 18),
                const SizedBox(width: 8),
                Text('Charte Miwodo', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryOrange)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Miwodo interdit formellement la vente de produits illicites, contrefaits, dangereux, ou de contrebande. Tout manquement constaté entraîne la suspension immédiate et définitive du compte sans remboursement.',
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: _charteAcceptee,
                  onChanged: (v) => setState(() { _charteAcceptee = v ?? false; _hasChanges = true; }),
                  activeColor: AppColors.primaryOrange,
                ),
                Expanded(child: Text("J'accepte la charte vendeur Miwodo", style: GoogleFonts.inter(fontSize: 13))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECTIONS LIVREUR
  // ═══════════════════════════════════════════════════════════════════════════

  List<Widget> _buildLivreurSections(List<ConfigZone> zones) {
    return [
      _buildVehiculeSection(),
      const SizedBox(height: 24),
      _buildTarifsZonesSection(zones),
      const SizedBox(height: 24),
      _buildDisponibilitesLivreurSection(),
    ];
  }

  Widget _buildVehiculeSection() {
    final vehicules = [
      {'id': 'moto', 'label': 'Moto', 'icon': Icons.two_wheeler},
      {'id': 'voiture', 'label': 'Voiture', 'icon': Icons.directions_car},
      {'id': 'velo', 'label': 'Vélo', 'icon': Icons.pedal_bike},
      {'id': 'tricycle', 'label': 'Tricycle', 'icon': Icons.electric_rickshaw},
    ];

    return _buildSection(
      title: 'Mon véhicule',
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: vehicules.map((v) {
            final selected = _typeEngin == v['id'];
            return GestureDetector(
              onTap: () => setState(() { _typeEngin = v['id'] as String; _hasChanges = true; }),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFFF4ED) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AppColors.primaryOrange : AppColors.borderGray, width: selected ? 2 : 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(v['icon'] as IconData, size: 32, color: selected ? AppColors.primaryOrange : AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text(v['label'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? AppColors.primaryOrange : AppColors.textPrimary)),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _capaciteCharge,
          decoration: _inputDecoration('Capacité de charge'),
          items: _capaciteOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() { _capaciteCharge = v; _hasChanges = true; }),
        ),
      ],
    );
  }

  Widget _buildTarifsZonesSection(List<ConfigZone> zones) {
    return _buildSection(
      title: 'Tarifs de livraison',
      subtitle: 'Définissez votre tarif pour chaque zone desservie',
      children: [
        ...zones.map((z) {
          final enabled = _tarifsZones.containsKey(z.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Switch(
                  value: enabled,
                  onChanged: (v) {
                    setState(() {
                      if (v) {
                        _tarifsZones[z.id] = 500;
                      } else {
                        _tarifsZones.remove(z.id);
                      }
                      _hasChanges = true;
                    });
                  },
                  activeTrackColor: AppColors.primaryOrange,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(z.nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500))),
                if (enabled)
                  SizedBox(
                    width: 100,
                    child: _PersistentTextField(
                      label: 'Tarif',
                      value: _tarifsZones[z.id]?.toString() ?? '',
                      onChanged: (v) {
                        _tarifsZones[z.id] = int.tryParse(v) ?? 0;
                        _hasChanges = true;
                      },
                      keyboardType: TextInputType.number,
                      decoration: _inputDecoration('F CFA'),
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _livraisonExpress,
              onChanged: (v) => setState(() { _livraisonExpress = v; _hasChanges = true; }),
              activeTrackColor: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text('Livraison express disponible', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        if (_livraisonExpress) ...[
          const SizedBox(height: 8),
          _buildTextField('Surcoût express (F CFA)', _surcoutExpress.toString(), (v) {
            setState(() { _surcoutExpress = int.tryParse(v) ?? 0; _hasChanges = true; });
          }, keyboardType: TextInputType.number),
        ],
      ],
    );
  }

  Widget _buildDisponibilitesLivreurSection() {
    return _buildSection(
      title: 'Mes horaires de livraison',
      children: [
        _buildJoursSelector(),
        const SizedBox(height: 16),
        Row(
          children: [
            Switch(
              value: _disponibleWeekend,
              onChanged: (v) => setState(() { _disponibleWeekend = v; _hasChanges = true; }),
              activeTrackColor: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text('Disponible les weekends', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        Row(
          children: [
            Switch(
              value: _disponibleNuit,
              onChanged: (v) => setState(() { _disponibleNuit = v; _hasChanges = true; }),
              activeTrackColor: AppColors.primaryOrange,
            ),
            const SizedBox(width: 8),
            Text('Disponible la nuit (après 20h)', style: GoogleFonts.inter(fontSize: 14)),
          ],
        ),
        const SizedBox(height: 12),
        _buildDisponibleSwitch(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WIDGETS COMMUNS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildServicesSection(List<ServicePrestataire> services, int maxServices, List<String> unites) {
    return _buildSection(
      title: 'Mes prestations',
      subtitle: 'Jusqu\'à $maxServices services',
      children: [
        if (services.isEmpty)
          _buildEmptyServicesState()
        else
          ...services.map((s) => _ServiceCard(
            key: ValueKey(s.id),
            service: s,
            onEdit: () => _showAddEditServiceDialog(context, service: s),
            onDelete: () => _deleteService(s),
            onToggleActive: () => _toggleServiceActive(s),
          )),
        const SizedBox(height: 12),
        MiwodoButton(
          label: '+ Ajouter une prestation',
          variant: MiwodoButtonVariant.secondary,
          fullWidth: true,
          onPressed: services.length >= maxServices ? null : () => _showAddEditServiceDialog(context, unites: unites),
        ),
        if (services.length >= maxServices)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Maximum $maxServices prestations atteint', style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryOrange)),
          ),
      ],
    );
  }

  Widget _buildEmptyServicesState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.primaryOrange, width: 1, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          const MiwodoSvgIcon('assets/icons/ic_plus.svg', size: 32, color: AppColors.primaryOrange),
          const SizedBox(height: 12),
          Text('Aucune prestation ajoutée', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Ajoutez vos services pour que les clients sachent ce que vous faites', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildZonesSection(List<ConfigZone> zones, int maxZones) {
    return _buildSection(
      title: 'Zones d\'intervention',
      subtitle: 'Sélectionnez jusqu\'à $maxZones zones',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: zones.map((z) {
            final selected = _zonesIntervention.contains(z.id);
            final disabled = !selected && _zonesIntervention.length >= maxZones;
            return GestureDetector(
              onTap: disabled ? null : () {
                setState(() {
                  if (selected) {
                    _zonesIntervention.remove(z.id);
                  } else {
                    _zonesIntervention.add(z.id);
                  }
                  _hasChanges = true;
                });
              },
              child: Opacity(
                opacity: disabled ? 0.35 : 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primaryOrange : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(z.nom, style: GoogleFonts.inter(fontSize: 13, color: selected ? Colors.white : const Color(0xFF6B7280))),
                ),
              ),
            );
          }).toList(),
        ),
        if (_zonesIntervention.length >= maxZones)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Maximum $maxZones zones atteint', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primaryOrange)),
          ),
      ],
    );
  }

  Widget _buildExperienceSection() {
    return _buildSection(
      title: 'Expérience & Spécialités',
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _anneesExperience,
                decoration: _inputDecoration('Années d\'expérience'),
                items: _experienceOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() { _anneesExperience = v; _hasChanges = true; }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField('Spécialités', _specialites, (v) {
          setState(() { _specialites = v; _hasChanges = true; });
        }, hint: 'ex: Carrelage, Finitions, Rénovation...', maxLength: 120),
        Text('Séparez vos spécialités par des virgules', style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildDisponibilitesSection() {
    return _buildSection(
      title: 'Mes jours de travail',
      children: [
        _buildJoursSelector(),
        const SizedBox(height: 16),
        _buildDisponibleSwitch(),
      ],
    );
  }

  Widget _buildJoursSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final jour = _jours[i];
        final selected = _joursDisponibles.contains(jour);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _joursDisponibles.remove(jour);
              } else {
                _joursDisponibles.add(jour);
              }
              _hasChanges = true;
            });
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryOrange : const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(_joursLabels[i], style: GoogleFonts.inter(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400, color: selected ? Colors.white : AppColors.textSecondary)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDisponibleSwitch() {
    return Row(
      children: [
        Switch(
          value: _disponible,
          onChanged: (v) async {
            setState(() => _disponible = v);
            await FirebaseFirestore.instance.collection('prestataires').doc(widget.prestataireId).update({'estDisponible': v});
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Statut mis à jour ✓'), backgroundColor: AppColors.successGreen, duration: const Duration(seconds: 1)));
            }
          },
          activeTrackColor: AppColors.primaryOrange,
        ),
        const SizedBox(width: 8),
        Text('Disponible en ce moment', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildSection({required String title, String? subtitle, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildTextField(String label, String value, ValueChanged<String> onChanged, {String? hint, int maxLines = 1, int? maxLength, TextInputType? keyboardType}) {
    return _PersistentTextField(
      label: label,
      value: value,
      onChanged: onChanged,
      hint: hint,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      decoration: _inputDecoration(hint ?? label).copyWith(labelText: label),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SAUVEGARDE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveAll(Prestataire p) async {
    // Validation
    if (p.isVendeur && !_charteAcceptee) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vous devez accepter la charte Miwodo'), backgroundColor: AppColors.errorRed));
      return;
    }
    if (p.isVendeur && _boutiqueNom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom de votre boutique est requis'), backgroundColor: AppColors.errorRed));
      return;
    }
    if (p.isLivreur && _typeEngin == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Choisissez votre type de véhicule'), backgroundColor: AppColors.errorRed));
      return;
    }
    if (p.isLivreur && _tarifsZones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activez au moins 1 zone de livraison'), backgroundColor: AppColors.errorRed));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'jours_disponibles': _joursDisponibles,
      };

      if (p.isArtisan) {
        data['zones_intervention'] = _zonesIntervention;
        data['annees_experience'] = _anneesExperience;
        data['specialites'] = _specialites;
      }

      if (p.isLiberal) {
        data['cabinet_nom'] = _cabinetNom;
        data['cabinet_adresse'] = _cabinetAdresse;
        data['diplome'] = _diplome;
        data['consultation_domicile'] = _consultationDomicile;
        data['surcout_deplacement'] = _surcoutDeplacement;
        data['langues'] = _langues;
      }

      if (p.isVendeur) {
        data['boutique_nom'] = _boutiqueNom;
        data['boutique_description'] = _boutiqueDescription;
        data['delai_preparation'] = _delaiPreparation;
        data['livraison_disponible'] = _livraisonDisponible;
        data['zones_livraison'] = _zonesLivraison;
        data['retrait_place'] = _retraitPlace;
        data['politique_retour'] = _politiqueRetour;
        data['charte_acceptee'] = _charteAcceptee;
      }

      if (p.isLivreur) {
        data['type_engin'] = _typeEngin;
        data['capacite_charge'] = _capaciteCharge;
        data['tarifs_zones'] = _tarifsZones;
        data['livraison_express'] = _livraisonExpress;
        data['surcout_express'] = _surcoutExpress;
        data['disponible_weekend'] = _disponibleWeekend;
        data['disponible_nuit'] = _disponibleNuit;
      }

      await FirebaseFirestore.instance.collection('prestataires').doc(widget.prestataireId).update(data);

      setState(() { _hasChanges = false; _isSaving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Services mis à jour ✓'), backgroundColor: AppColors.successGreen));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  Future<void> _showAddEditServiceDialog(BuildContext context, {ServicePrestataire? service, List<String>? unites}) async {
    final isEdit = service != null;
    final nomController = TextEditingController(text: service?.nom ?? '');
    final descriptionController = TextEditingController(text: service?.description ?? '');
    final prixMinController = TextEditingController(text: service?.prixMin?.toString() ?? '');
    final prixMaxController = TextEditingController(text: service?.prixMax?.toString() ?? '');
    final dureeController = TextEditingController(text: service?.dureeEstimee ?? '');
    String selectedUnite = service?.unite ?? 'forfait';
    List<String> existingImages = service?.images ?? [];
    List<File> newImages = [];
    bool isLoading = false;

    final unitesOptions = unites ?? ['forfait', 'par heure', 'par jour', 'par semaine', 'par mois', 'par m²'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.borderGray)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    Expanded(
                      child: Text(
                        isEdit ? 'Modifier le service' : 'Nouveau service',
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom du service
                      _buildLabel('Nom du service *'),
                      TextField(
                        controller: nomController,
                        decoration: _inputDecoration('Ex: Installation climatiseur'),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      _buildLabel('Description'),
                      TextField(
                        controller: descriptionController,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: _inputDecoration('Décrivez ce service en détail...'),
                      ),
                      const SizedBox(height: 16),

                      // Prix
                      _buildLabel('Tarification'),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: prixMinController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Prix min (F)'),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('—'),
                          ),
                          Expanded(
                            child: TextField(
                              controller: prixMaxController,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('Prix max (F)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Unité
                      DropdownButtonFormField<String>(
                        initialValue: selectedUnite,
                        decoration: _inputDecoration('Unité de tarification'),
                        items: unitesOptions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                        onChanged: (v) => setDialogState(() => selectedUnite = v!),
                      ),
                      const SizedBox(height: 16),

                      // Durée estimée
                      _buildLabel('Durée estimée'),
                      TextField(
                        controller: dureeController,
                        decoration: _inputDecoration('Ex: 2-3 heures, 1 journée...'),
                      ),
                      const SizedBox(height: 24),

                      // Images
                      _buildLabel('Photos du service (max 5)'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // Images existantes
                          ...existingImages.map((url) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => existingImages.remove(url)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          )),
                          // Nouvelles images
                          ...newImages.map((file) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(file, width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setDialogState(() => newImages.remove(file)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 12),
                                  ),
                                ),
                              ),
                            ],
                          )),
                          // Bouton ajouter
                          if (existingImages.length + newImages.length < 5)
                            GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickMultiImage(imageQuality: 80);
                                if (picked.isNotEmpty) {
                                  final remaining = 5 - existingImages.length - newImages.length;
                                  final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
                                  setDialogState(() => newImages.addAll(toAdd));
                                }
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.borderGray, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary, size: 32),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.borderGray)),
                ),
                child: SafeArea(
                  child: MiwodoButton(
                    label: isEdit ? 'Enregistrer les modifications' : 'Créer le service',
                    isLoading: isLoading,
                    onPressed: isLoading ? null : () async {
                      if (nomController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Le nom du service est requis')),
                        );
                        return;
                      }

                      setDialogState(() => isLoading = true);

                      try {
                        // Upload nouvelles images
                        List<String> uploadedUrls = [...existingImages];
                        int uploadFailCount = 0;
                        for (final file in newImages) {
                          try {
                            final fileName = 'services/${widget.prestataireId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            final url = await SupabaseService.uploadPhoto(
                              bucket: 'miwodo-photos',
                              path: fileName,
                              file: file,
                            );
                            uploadedUrls.add(url);
                          } catch (e) {
                            uploadFailCount++;
                            debugPrint('Upload image service échoué: $e');
                          }
                        }
                        if (uploadFailCount > 0 && ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$uploadFailCount image(s) n\'ont pas pu être uploadées. Vérifiez votre connexion.'),
                              backgroundColor: AppColors.errorRed,
                            ),
                          );
                        }

                        final data = {
                          'prestataireId': widget.prestataireId,
                          'nom': nomController.text,
                          'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                          'prixMin': int.tryParse(prixMinController.text),
                          'prixMax': int.tryParse(prixMaxController.text),
                          'unite': selectedUnite,
                          'dureeEstimee': dureeController.text.isEmpty ? null : dureeController.text,
                          'images': uploadedUrls,
                          'actif': true,
                          'modifieLe': FieldValue.serverTimestamp(),
                        };

                        if (isEdit) {
                          await FirebaseFirestore.instance.collection('services').doc(service.id).update(data);
                        } else {
                          data['creeLe'] = FieldValue.serverTimestamp();
                          data['ordre'] = 0;
                          await FirebaseFirestore.instance.collection('services').add(data);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEdit ? 'Service modifié ✓' : 'Service créé ✓'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isLoading = false);
                        if (mounted) {
                          String errorMsg = 'Erreur lors de la création du service';
                          if (e is FirebaseException) {
                            errorMsg = 'Erreur ${e.code}: ${e.message}';
                          } else {
                            errorMsg = 'Erreur: $e';
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMsg), backgroundColor: AppColors.errorRed),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.surfaceGray,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _deleteService(ServicePrestataire service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce service ?'),
        content: Text('Le service "${service.nom}" sera supprimé définitivement.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('services').doc(service.id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service supprimé'), backgroundColor: AppColors.successGreen),
        );
      }
    }
  }

  Future<void> _toggleServiceActive(ServicePrestataire service) async {
    await FirebaseFirestore.instance.collection('services').doc(service.id).update({
      'actif': !service.actif,
    });
  }
}

class _ServiceCard extends StatelessWidget {
  final ServicePrestataire service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _ServiceCard({
    super.key,
    required this.service,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: service.actif ? AppColors.borderGray : AppColors.errorRed.withAlpha(50)),
      ),
      child: Opacity(
        opacity: service.actif ? 1.0 : 0.6,
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Image ou placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: service.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: service.images.first,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 70,
                          height: 70,
                          color: AppColors.primaryOrangeLight,
                          child: const Icon(Icons.handyman, color: AppColors.primaryOrange, size: 28),
                        ),
                ),
                const SizedBox(width: 12),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.nom,
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!service.actif)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.errorRed.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Inactif', style: GoogleFonts.inter(fontSize: 10, color: AppColors.errorRed, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      if (service.description != null && service.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          service.description!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrangeLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              service.prixAffiche,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryOrange),
                            ),
                          ),
                          if (service.dureeEstimee != null) ...[
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(service.dureeEstimee!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Actions
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'edit': onEdit(); break;
                      case 'toggle': onToggleActive(); break;
                      case 'delete': onDelete(); break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('Modifier')])),
                    PopupMenuItem(value: 'toggle', child: Row(children: [Icon(service.actif ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18), SizedBox(width: 8), Text(service.actif ? 'Désactiver' : 'Activer')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed), SizedBox(width: 8), Text('Supprimer', style: TextStyle(color: AppColors.errorRed))])),
                  ],
                ),

                // Drag handle
                const Icon(Icons.drag_handle, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PersistentTextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final InputDecoration? decoration;

  const _PersistentTextField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.decoration,
  });

  @override
  State<_PersistentTextField> createState() => _PersistentTextFieldState();
}

class _PersistentTextFieldState extends State<_PersistentTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_PersistentTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && !_focusNode.hasFocus) {
      final selection = _controller.selection;
      _controller.text = widget.value;
      if (selection.start <= widget.value.length) {
        _controller.selection = selection;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      decoration: widget.decoration ?? InputDecoration(
        hintText: widget.hint ?? widget.label,
        filled: true,
        fillColor: AppColors.surfaceGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelText: widget.label,
      ),
      onChanged: widget.onChanged,
    );
  }
}
