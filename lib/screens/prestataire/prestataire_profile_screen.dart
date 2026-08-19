// screens/prestataire/prestataire_profile_screen.dart
// Écran profil prestataire complet avec MODE VUE et MODE ÉDITION
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/zones.dart';
import '../../core/theme/app_colors.dart';
import '../../models/avis.dart';
import '../../models/prestataire.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

// ─── PROVIDERS ───────────────────────────────────────────────────────────────

final prestataireProfileProvider = FutureProvider.family<Prestataire?, String>(
  (ref, id) => FirestoreService.instance.getPrestataire(id),
);

final avisProfileProvider = StreamProvider.autoDispose.family<List<Avis>, String>(
  (ref, id) {
    return FirebaseFirestore.instance
        .collection('avis')
        .where('prestataireId', isEqualTo: id)
        .orderBy('creeLe', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Avis.fromJson(data);
            }).toList());
  },
);

final isEditModeProvider = StateProvider.family<bool, String>((ref, id) => false);
final descExpandedProvider = StateProvider.family<bool, String>((ref, id) => false);
final reviewRatingProvider = StateProvider.family<int, String>((ref, id) => 0);
final reviewCommentProvider = StateProvider.family<String, String>((ref, id) => '');
final reviewSubmittingProvider = StateProvider.family<bool, String>((ref, id) => false);
final profileSavingProvider = StateProvider.family<bool, String>((ref, id) => false);

// ─── MAIN WIDGET ─────────────────────────────────────────────────────────────

class PrestataireProfileScreen extends ConsumerStatefulWidget {
  final String id;

  const PrestataireProfileScreen({super.key, required this.id});

  @override
  ConsumerState<PrestataireProfileScreen> createState() => _PrestataireProfileScreenState();
}

class _PrestataireProfileScreenState extends ConsumerState<PrestataireProfileScreen> {
  // Form controllers pour mode édition
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _metierController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tarifController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();

  String _selectedPaysId = '';
  String _selectedVille = '';
  String _selectedZone = '';
  bool _estDisponible = true;

  File? _newProfileImage;
  List<File> _newPortfolioImages = [];
  List<String> _photosToDelete = [];

  bool _formInitialized = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _metierController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _descriptionController.dispose();
    _tarifController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _initFormWithPrestataire(Prestataire p) {
    if (_formInitialized) return;
    _nomController.text = p.nom;
    _prenomController.text = p.prenom;
    _metierController.text = p.categorie;
    _telephoneController.text = p.telephone;
    _emailController.text = p.email ?? '';
    _descriptionController.text = p.description ?? '';
    _tarifController.text = '';
    _selectedPaysId = p.paysId;
    _selectedVille = p.ville;
    final zonesForVille = Zones.zonesParVille(p.paysId, p.ville);
    _selectedZone = zonesForVille.contains(p.zone) ? p.zone : zonesForVille.first;
    _estDisponible = p.estDisponible;
    _formInitialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final prestataireAsync = ref.watch(prestataireProfileProvider(widget.id));
    final isEditMode = ref.watch(isEditModeProvider(widget.id));
    final currentUserId = FirebaseService.instance.auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: prestataireAsync.when(
        loading: () => _buildLoading(),
        error: (e, st) => _buildError(e),
        data: (prestataire) {
          if (prestataire == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MiwodoSvgIcon('assets/icons/ic_error.svg', size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text('Prestataire introuvable', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  MiwodoButton(label: 'Retour', onPressed: () => context.pop()),
                ],
              ),
            );
          }

          final isOwner = currentUserId == prestataire.id;
          _initFormWithPrestataire(prestataire);

          if (isEditMode && isOwner) {
            return _buildEditMode(prestataire);
          }
          return _buildViewMode(prestataire, isOwner);
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODE VUE PUBLIQUE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildViewMode(Prestataire p, bool isOwner) {
    final avisAsync = ref.watch(avisProfileProvider(widget.id));

    return CustomScrollView(
      slivers: [
        // ── BLOC 1 : HERO COVER ──
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
          ),
          actions: [
            IconButton(
              onPressed: () => _shareProfile(p),
              icon: const MiwodoSvgIcon('assets/icons/ic_share.svg', size: 20, color: Colors.white),
            ),
            if (isOwner)
              IconButton(
                onPressed: () => ref.read(isEditModeProvider(widget.id).notifier).state = true,
                icon: const MiwodoSvgIcon('assets/icons/ic_edit.svg', size: 20, color: Colors.white),
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                // Image de couverture
                if (p.photosPortfolio.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: p.photosPortfolio.first,
                    fit: BoxFit.cover,
                    color: Colors.black.withAlpha(166),
                    colorBlendMode: BlendMode.darken,
                  )
                else
                  Container(color: AppColors.primaryOrange),

                // Gradient overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.primaryOrange.withAlpha(230)],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),

                // Contenu centré
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      // Avatar avec badge sponsorisé
                      Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: _buildAvatar(p, 90),
                          ),
                          if (p.sponsorise)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange.withAlpha(230),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('⭐', style: GoogleFonts.inter(fontSize: 10)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${p.prenom} ${p.nom}',
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        p.categorie.toUpperCase(),
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white.withAlpha(217)),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MiwodoSvgIcon('assets/icons/ic_location.svg', size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text(p.zone, style: GoogleFonts.inter(fontSize: 13, color: Colors.white70)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── BLOC 2 : BADGES & STATUT ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (p.estVerifie) _buildBadge('✓ Vérifié', const Color(0xFFFFF4ED), AppColors.primaryOrange),
                const SizedBox(width: 8),
                _buildBadge(
                  p.estDisponible ? '● Disponible' : '● Occupé',
                  p.estDisponible ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  p.estDisponible ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
                if (p.sponsorise) ...[
                  const SizedBox(width: 8),
                  _buildBadge('⭐ Sponsorisé', AppColors.primaryOrange, Colors.white),
                ],
              ],
            ),
          ),
        ),

        // ── BLOC 3 : ACTIONS RAPIDES ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: isOwner ? _buildOwnerActions(p) : _buildVisitorActions(p),
          ),
        ),

        // ── BLOC 4 : STATS RAPIDES ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _buildStatItem('★', p.noteMoyenne.toStringAsFixed(1), 'Note', AppColors.primaryOrange),
                  _buildStatDivider(),
                  _buildStatItem('💬', p.nombreAvis.toString(), 'Avis', AppColors.textPrimary),
                  _buildStatDivider(),
                  _buildStatItem('📋', '0', 'Missions', AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ),

        // ── BLOC 5 : INFOS PRATIQUES ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Informations', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _buildInfoRow('assets/icons/ic_briefcase.svg', p.categorie),
                  _buildInfoRow('assets/icons/ic_location.svg', '${p.zone}, ${p.ville}, ${p.paysNom}'),
                  _buildInfoRow('assets/icons/ic_clock.svg', p.estDisponible ? 'Disponible' : 'Actuellement occupé'),
                ],
              ),
            ),
          ),
        ),

        // ── BLOC 6 : À PROPOS ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('À propos', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildExpandableDescription(p.description ?? 'Aucune description'),
                ],
              ),
            ),
          ),
        ),

        // ── BLOC 7 : GALERIE RÉALISATIONS ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Réalisations', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('(${p.photosPortfolio.length} photos)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                if (p.photosPortfolio.isEmpty && isOwner)
                  _buildEmptyGalleryPrompt()
                else if (p.photosPortfolio.isEmpty)
                  Text('Aucune réalisation', style: GoogleFonts.inter(color: AppColors.textSecondary))
                else
                  _buildGalleryGrid(p.photosPortfolio),
              ],
            ),
          ),
        ),

        // ── BLOC 8 : AVIS CLIENTS ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Avis clients', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text('(${p.nombreAvis} avis)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 12),
                // Résumé graphique
                Center(
                  child: Column(
                    children: [
                      Text(p.noteMoyenne.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final filled = i < p.noteMoyenne.round();
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: MiwodoSvgIcon(
                              filled ? 'assets/icons/ic_star.svg' : 'assets/icons/ic_star_empty.svg',
                              size: 20,
                              color: filled ? AppColors.primaryOrange : AppColors.borderGray,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text('(basé sur ${p.nombreAvis} avis)', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Liste des avis
                avisAsync.when(
                  data: (avis) {
                    if (avis.isEmpty) return Text('Aucun avis pour le moment', style: GoogleFonts.inter(color: AppColors.textSecondary));
                    return Column(children: avis.map((a) => _buildAvisCard(a)).toList());
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text('Erreur chargement avis', style: GoogleFonts.inter(color: AppColors.errorRed)),
                ),
              ],
            ),
          ),
        ),

        // ── BLOC 9 : FORMULAIRE AVIS (si non-owner) ──
        if (!isOwner) SliverToBoxAdapter(child: _buildReviewForm(p)),

        // ── BLOC 10 : PROFILS SIMILAIRES ──
        SliverToBoxAdapter(child: _buildSimilarProfiles(p)),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildSimilarProfiles(Prestataire p) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Autres prestataires · ${p.zone}', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: StreamBuilder<List<Prestataire>>(
              stream: FirestoreService.instance.getPrestataires(zone: p.zone),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final similar = snapshot.data!.where((pr) => pr.id != p.id && pr.categorie == p.categorie).take(5).toList();
                if (similar.isEmpty) {
                  return Center(child: Text('Aucun prestataire similaire', style: GoogleFonts.inter(color: AppColors.textSecondary)));
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: similar.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final pr = similar[index];
                    return GestureDetector(
                      onTap: () => context.push('/prestataire/${pr.id}'),
                      child: Container(
                        width: 140,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          children: [
                            _buildAvatar(pr, 50),
                            const SizedBox(height: 8),
                            Text('${pr.prenom} ${pr.nom}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                            const SizedBox(height: 4),
                            Text(pr.categorie, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                            const Spacer(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const MiwodoSvgIcon('assets/icons/ic_star.svg', size: 12, color: AppColors.primaryOrange),
                                const SizedBox(width: 4),
                                Text(pr.noteMoyenne.toStringAsFixed(1), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODE ÉDITION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEditMode(Prestataire p) {
    final isSaving = ref.watch(profileSavingProvider(widget.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () {
            ref.read(isEditModeProvider(widget.id).notifier).state = false;
            _formInitialized = false;
          },
          child: Text('Annuler', style: GoogleFonts.inter(color: AppColors.textSecondary)),
        ),
        leadingWidth: 80,
        title: Text('Modifier mon profil', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => _saveProfile(p),
            child: Text('Enregistrer', style: GoogleFonts.inter(color: isSaving ? AppColors.textSecondary : AppColors.primaryOrange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: isSaving
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // ▼ SECTION 1 — Photo de profil & couverture
                  _buildEditSection(
                    title: 'Photo de profil & couverture',
                    initiallyExpanded: true,
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: _pickProfileImage,
                          child: Stack(
                            children: [
                              _newProfileImage != null
                                  ? CircleAvatar(radius: 50, backgroundImage: FileImage(_newProfileImage!))
                                  : _buildAvatar(p, 100),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: AppColors.primaryOrange, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(child: Text('Changer la photo', style: GoogleFonts.inter(fontSize: 13, color: AppColors.primaryOrange))),
                    ],
                  ),

                  // ▼ SECTION 2 — Informations de base
                  _buildEditSection(
                    title: 'Informations de base',
                    initiallyExpanded: true,
                    children: [
                      _buildTextField(controller: _prenomController, label: 'Prénom', required: true),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _nomController, label: 'Nom', required: true),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _metierController, label: 'Métier / Activité', required: true, hint: 'Ex: Coiffeur, Électricien, Livreur...'),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: 'Pays',
                        value: _selectedPaysId,
                        items: Zones.paysVillesZones.keys.toList(),
                        onChanged: (v) => setState(() {
                          _selectedPaysId = v!;
                          _selectedVille = Zones.villesParPays(v).first;
                          _selectedZone = Zones.zonesParVille(v, _selectedVille).first;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: 'Ville',
                        value: _selectedVille,
                        items: Zones.villesParPays(_selectedPaysId),
                        onChanged: (v) => setState(() {
                          _selectedVille = v!;
                          _selectedZone = Zones.zonesParVille(_selectedPaysId, v).first;
                        }),
                      ),
                      const SizedBox(height: 12),
                      _buildDropdown(
                        label: 'Zone / Quartier',
                        value: _selectedZone,
                        items: Zones.zonesParVille(_selectedPaysId, _selectedVille),
                        onChanged: (v) => setState(() => _selectedZone = v!),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _telephoneController, label: 'Téléphone (+228)', required: true, keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _emailController, label: 'Email', keyboardType: TextInputType.emailAddress),
                    ],
                  ),

                  // ▼ SECTION 3 — Description & Tarif
                  _buildEditSection(
                    title: 'Description & Tarif',
                    children: [
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'À propos / Description',
                        hint: 'Décrivez votre activité, votre expérience, vos spécialités…',
                        maxLines: 6,
                        maxLength: 500,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _tarifController, label: 'Tarif indicatif', hint: 'Ex: 15 000 F/jour ou Sur devis'),
                    ],
                  ),

                  // ▼ SECTION 4 — Disponibilité
                  _buildEditSection(
                    title: 'Disponibilité',
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: _estDisponible,
                            onChanged: (v) => setState(() => _estDisponible = v),
                            activeTrackColor: AppColors.primaryOrange,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _estDisponible ? 'Je suis disponible en ce moment' : 'Je suis actuellement occupé',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Votre statut sera visible en temps réel sur votre profil',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  // ▼ SECTION 5 — Galerie de réalisations
                  _buildEditSection(
                    title: 'Galerie de réalisations',
                    children: [
                      if (p.photosPortfolio.isNotEmpty || _newPortfolioImages.isNotEmpty) ...[
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                          itemCount: p.photosPortfolio.length + _newPortfolioImages.length,
                          itemBuilder: (context, index) {
                            if (index < p.photosPortfolio.length) {
                              final url = p.photosPortfolio[index];
                              final isMarkedForDelete = _photosToDelete.contains(url);
                              return Stack(
                                children: [
                                  Opacity(
                                    opacity: isMarkedForDelete ? 0.4 : 1.0,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isMarkedForDelete) {
                                            _photosToDelete.remove(url);
                                          } else {
                                            _photosToDelete.add(url);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isMarkedForDelete ? AppColors.successGreen : AppColors.errorRed,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(isMarkedForDelete ? Icons.undo : Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              final file = _newPortfolioImages[index - p.photosPortfolio.length];
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _newPortfolioImages.removeAt(index - p.photosPortfolio.length)),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: AppColors.errorRed, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      MiwodoButton(
                        label: '+ Ajouter des photos',
                        variant: MiwodoButtonVariant.secondary,
                        onPressed: _pickPortfolioImages,
                      ),
                      const SizedBox(height: 8),
                      Text('Maximum 10 photos au total', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),

                  // ▼ SECTION 6 — Mes services
                  _buildEditSection(
                    title: 'Mes services',
                    children: [
                      Text(
                        'Gérez les services que vous proposez à vos clients',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      MiwodoButton(
                        label: 'Gérer mes services →',
                        variant: MiwodoButtonVariant.secondary,
                        icon: 'assets/icons/ic_briefcase.svg',
                        onPressed: () => context.push('/mes-services/${widget.id}'),
                      ),
                    ],
                  ),

                  // ▼ SECTION 7 — Réseaux sociaux
                  _buildEditSection(
                    title: 'Réseaux sociaux (optionnel)',
                    children: [
                      _buildTextField(controller: _whatsappController, label: 'WhatsApp', hint: '+228 90 00 00 00', keyboardType: TextInputType.phone),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _facebookController, label: 'Facebook', hint: 'https://facebook.com/...'),
                      const SizedBox(height: 12),
                      _buildTextField(controller: _instagramController, label: 'Instagram', hint: 'https://instagram.com/...'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  MiwodoButton(
                    label: 'Enregistrer les modifications',
                    onPressed: isSaving ? null : () => _saveProfile(p),
                    isLoading: isSaving,
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS WIDGETS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          flexibleSpace: Shimmer.fromColors(
            baseColor: AppColors.primaryOrange.withAlpha(200),
            highlightColor: AppColors.primaryOrange.withAlpha(100),
            child: Container(color: AppColors.primaryOrange),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(5, (_) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey.shade300,
                  highlightColor: Colors.grey.shade100,
                  child: Container(height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                ),
              )),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiwodoSvgIcon('assets/icons/ic_error.svg', size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Erreur de chargement', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(error.toString(), style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            MiwodoButton(
              label: 'Réessayer',
              variant: MiwodoButtonVariant.secondary,
              onPressed: () => ref.refresh(prestataireProfileProvider(widget.id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Prestataire p, double size) {
    final photoUrl = p.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: size,
            height: size,
            color: AppColors.primaryOrangeLight,
            child: Center(
              child: SizedBox(
                width: size * 0.2,
                height: size * 0.2,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => _buildInitialsAvatar(p, size),
        ),
      );
    }
    return _buildInitialsAvatar(p, size);
  }

  Widget _buildInitialsAvatar(Prestataire p, double size) {
    final initials = '${p.prenom.isNotEmpty ? p.prenom[0] : ''}${p.nom.isNotEmpty ? p.nom[0] : ''}'.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: AppColors.primaryOrangeLight, shape: BoxShape.circle),
      child: Center(child: Text(initials, style: GoogleFonts.inter(fontSize: size * 0.35, fontWeight: FontWeight.w700, color: AppColors.primaryOrange))),
    );
  }

  Widget _buildBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  Widget _buildOwnerActions(Prestataire p) {
    return Column(
      children: [
        MiwodoButton(
          label: 'Modifier mon profil',
          icon: 'assets/icons/ic_edit.svg',
          variant: MiwodoButtonVariant.secondary,
          onPressed: () => ref.read(isEditModeProvider(widget.id).notifier).state = true,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Switch(
                      value: p.estDisponible,
                      onChanged: (v) async {
                        await FirestoreService.instance.updatePrestataire(p.id, {'estDisponible': v});
                        ref.invalidate(prestataireProfileProvider(widget.id));
                      },
                      activeTrackColor: AppColors.primaryOrange,
                    ),
                    Text(p.estDisponible ? 'Disponible' : 'Occupé', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MiwodoButton(
                label: 'Partager',
                icon: 'assets/icons/ic_share.svg',
                variant: MiwodoButtonVariant.secondary,
                onPressed: () => _shareProfile(p),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVisitorActions(Prestataire p) {
    return Row(
      children: [
        Expanded(
          child: MiwodoButton(
            label: 'Appeler',
            icon: 'assets/icons/ic_phone.svg',
            onPressed: () async {
              final tel = p.telephone.startsWith('+') ? p.telephone : '+228${p.telephone}';
              final uri = Uri(scheme: 'tel', path: tel);
              try {
                await launchUrl(uri);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Impossible de lancer l'appel")));
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MiwodoButton(
            label: 'Message',
            icon: 'assets/icons/ic_message.svg',
            variant: MiwodoButtonVariant.secondary,
            onPressed: () {
              final currentUid = FirebaseService.instance.auth.currentUser?.uid ?? 'guest';
              context.push('/messages/${p.id}_$currentUid');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String icon, String value, String label, Color valueColor) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: valueColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 40, color: AppColors.borderGray);
  }

  Widget _buildInfoRow(String iconPath, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MiwodoSvgIcon(iconPath, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildExpandableDescription(String text) {
    final expanded = ref.watch(descExpandedProvider(widget.id));
    final needsExpand = text.length > 150;
    final displayText = expanded || !needsExpand ? text : '${text.substring(0, 150)}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(displayText, style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.6)),
        if (needsExpand)
          TextButton(
            onPressed: () => ref.read(descExpandedProvider(widget.id).notifier).state = !expanded,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(expanded ? 'Voir moins ↑' : 'Voir plus →', style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _buildEmptyGalleryPrompt() {
    return GestureDetector(
      onTap: () => ref.read(isEditModeProvider(widget.id).notifier).state = true,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderGray, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MiwodoSvgIcon('assets/icons/ic_camera.svg', size: 32, color: AppColors.textSecondary),
              const SizedBox(height: 8),
              Text('Ajoutez vos réalisations', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryGrid(List<String> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ImageViewer(images: photos, initialIndex: index))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(imageUrl: photos[index], fit: BoxFit.cover),
          ),
        );
      },
    );
  }

  Widget _buildAvisCard(Avis a) {
    final initials = a.clientId.isNotEmpty ? a.clientId[0].toUpperCase() : 'U';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 18, backgroundColor: AppColors.primaryOrangeLight, child: Text(initials, style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Client', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(DateFormat.yMMMd().format(a.creeLe), style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  final filled = i < a.note.round();
                  return MiwodoSvgIcon(
                    filled ? 'assets/icons/ic_star.svg' : 'assets/icons/ic_star_empty.svg',
                    size: 12,
                    color: filled ? AppColors.primaryOrange : AppColors.borderGray,
                  );
                }),
              ),
            ],
          ),
          if (a.commentaire != null && a.commentaire!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(a.commentaire!, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewForm(Prestataire p) {
    final rating = ref.watch(reviewRatingProvider(widget.id));
    final submitting = ref.watch(reviewSubmittingProvider(widget.id));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Laisser un avis', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final filled = i < rating;
                return GestureDetector(
                  onTap: () => ref.read(reviewRatingProvider(widget.id).notifier).state = i + 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: AnimatedScale(
                      scale: filled ? 1.2 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: MiwodoSvgIcon(
                        filled ? 'assets/icons/ic_star.svg' : 'assets/icons/ic_star_empty.svg',
                        size: 28,
                        color: filled ? AppColors.primaryOrange : const Color(0xFFEEEEEE),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            TextField(
              maxLines: 4,
              onChanged: (v) => ref.read(reviewCommentProvider(widget.id).notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Partagez votre expérience avec ce prestataire…',
                hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFEEEEEE))),
              ),
            ),
            const SizedBox(height: 16),
            MiwodoButton(
              label: 'Publier mon avis',
              isLoading: submitting,
              onPressed: submitting ? null : () => _submitReview(p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditSection({required String title, required List<Widget> children, bool initiallyExpanded = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        initiallyExpanded: initiallyExpanded,
        iconColor: AppColors.primaryOrange,
        collapsedIconColor: AppColors.textSecondary,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label + (required ? ' *' : ''), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          validator: required ? (v) => v == null || v.isEmpty ? 'Ce champ est requis' : null : null,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderGray)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderGray)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primaryOrange)),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label *', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderGray)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.borderGray)),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _shareProfile(Prestataire p) {
    Share.share('Découvrez ${p.prenom} ${p.nom} sur Miwodo : https://miwodo.tg/prestataire/${p.id}');
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
    if (image != null) {
      setState(() => _newProfileImage = File(image.path));
    }
  }

  Future<void> _pickPortfolioImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(maxWidth: 1200, imageQuality: 85);
    if (images.isNotEmpty) {
      setState(() {
        _newPortfolioImages.addAll(images.map((e) => File(e.path)));
        if (_newPortfolioImages.length > 10) {
          _newPortfolioImages = _newPortfolioImages.take(10).toList();
        }
      });
    }
  }

  Future<void> _submitReview(Prestataire p) async {
    final rating = ref.read(reviewRatingProvider(widget.id));
    final comment = ref.read(reviewCommentProvider(widget.id));

    if (rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir une note')));
      return;
    }

    ref.read(reviewSubmittingProvider(widget.id).notifier).state = true;

    try {
      final clientId = FirebaseService.instance.auth.currentUser?.uid ?? 'anonymous';
      final avis = Avis(
        id: '',
        clientId: clientId,
        prestataireId: widget.id,
        note: rating.toDouble(),
        commentaire: comment.isEmpty ? null : comment,
        creeLe: DateTime.now(),
      );
      await FirestoreService.instance.addAvis(avis);
      ref.invalidate(prestataireProfileProvider(widget.id));
      ref.invalidate(avisProfileProvider(widget.id));
      ref.read(reviewRatingProvider(widget.id).notifier).state = 0;
      ref.read(reviewCommentProvider(widget.id).notifier).state = '';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Avis publié ✓'), backgroundColor: AppColors.successGreen));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      ref.read(reviewSubmittingProvider(widget.id).notifier).state = false;
    }
  }

  Future<void> _saveProfile(Prestataire p) async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(profileSavingProvider(widget.id).notifier).state = true;

    try {
      String? newPhotoUrl = p.photoUrl;
      List<String> newPhotosPortfolio = List.from(p.photosPortfolio);

      // Upload nouvelle photo de profil
      if (_newProfileImage != null) {
        try {
          final fileName = 'prestataires/${p.id}/profil.jpg';
          newPhotoUrl = await SupabaseService.uploadPhoto(
            bucket: 'miwodo-photos',
            path: fileName,
            file: _newProfileImage!,
          );
          // Add cache-busting query param so CachedNetworkImage fetches the new image
          newPhotoUrl = '$newPhotoUrl?t=${DateTime.now().millisecondsSinceEpoch}';
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur upload photo: $e'), backgroundColor: AppColors.errorRed),
            );
          }
        }
      }

      // Supprimer les photos marquées
      for (final url in _photosToDelete) {
        try {
          // Extraire le chemin de l'URL (format: https://domain/uploads/path)
          final uri = Uri.parse(url);
          final path = uri.path.replaceFirst('/uploads/', '');
          await SupabaseService.deletePhoto(bucket: 'miwodo-photos', path: path);
          newPhotosPortfolio.remove(url);
        } catch (e) {
          debugPrint('Erreur suppression photo: $e');
        }
      }

      // Upload nouvelles photos portfolio
      int portfolioFailCount = 0;
      for (int i = 0; i < _newPortfolioImages.length; i++) {
        final file = _newPortfolioImages[i];
        try {
          final fileName = 'prestataires/${p.id}/portfolio_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          final url = await SupabaseService.uploadPhoto(
            bucket: 'miwodo-photos',
            path: fileName,
            file: file,
          );
          newPhotosPortfolio.add(url);
        } catch (e) {
          portfolioFailCount++;
          debugPrint('Upload portfolio échoué: $e');
        }
      }
      if (portfolioFailCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$portfolioFailCount photo(s) n\'ont pas pu être uploadées'), backgroundColor: AppColors.errorRed),
        );
      }

      // Mettre à jour Firestore
      await FirestoreService.instance.updatePrestataire(p.id, {
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        'zone': _selectedZone,
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'estDisponible': _estDisponible,
        'paysId': _selectedPaysId,
        'ville': _selectedVille,
        'photoUrl': newPhotoUrl,
        'photosPortfolio': newPhotosPortfolio,
      });

      // Reset state
      _newProfileImage = null;
      _newPortfolioImages.clear();
      _photosToDelete.clear();
      _formInitialized = false;

      ref.invalidate(prestataireProfileProvider(widget.id));
      ref.read(isEditModeProvider(widget.id).notifier).state = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour ✓'), backgroundColor: AppColors.successGreen));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
    } finally {
      ref.read(profileSavingProvider(widget.id).notifier).state = false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// IMAGE VIEWER
// ═══════════════════════════════════════════════════════════════════════════

class _ImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewer({required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: images[index], fit: BoxFit.contain),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
