// screens/inscription/completion_profil_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/categories.dart';
import '../../core/constants/zones.dart';
import '../../core/theme/app_colors.dart';
import '../../services/firebase_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

class CompletionProfilScreen extends ConsumerStatefulWidget {
  final String prestataireId;

  const CompletionProfilScreen({super.key, required this.prestataireId});

  @override
  ConsumerState<CompletionProfilScreen> createState() =>
      _CompletionProfilScreenState();
}

class _CompletionProfilScreenState extends ConsumerState<CompletionProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _metierController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tarifZoneController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedVille;
  String? _selectedQuartier;
  String? _selectedTypeEngin;
  List<File> _photos = [];
  bool _isSaving = false;
  bool _isLoading = true;

  String _categorie = '';
  String _paysId = 'TG';
  String _existingMetier = '';

  @override
  void initState() {
    super.initState();
    _loadPrestataire();
  }

  @override
  void dispose() {
    _metierController.dispose();
    _descriptionController.dispose();
    _tarifZoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPrestataire() async {
    try {
      final doc = await FirebaseService.instance.firestore
          .collection('prestataires')
          .doc(widget.prestataireId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _categorie = data['categorie'] ?? 'artisan';
          _paysId = data['pays_id'] ?? 'TG';
          _existingMetier = data['metier'] ?? '';
          _metierController.text = _existingMetier;
          _descriptionController.text = data['description'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) print('[CompletionProfil] Error loading: $e');
      setState(() => _isLoading = false);
    }
  }

  Categorie get _categorieEnum {
    switch (_categorie.toLowerCase()) {
      case 'vendeur':
        return Categorie.vendeur;
      case 'livreur':
        return Categorie.livreur;
      case 'liberal':
      case 'libéral':
        return Categorie.liberal;
      default:
        return Categorie.artisan;
    }
  }

  Future<void> _pickPhotos() async {
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() {
          for (final x in picked) {
            _photos.add(File(x.path));
          }
        });
      }
    } catch (e) {
      try {
        final x = await _picker.pickImage(source: ImageSource.gallery);
        if (x != null) setState(() => _photos.add(File(x.path)));
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Erreur: $e2')));
        }
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    if (_selectedVille == null || _selectedVille!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner votre ville')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final zone = _selectedQuartier != null && _selectedQuartier!.isNotEmpty
          ? '$_selectedVille - $_selectedQuartier'
          : _selectedVille!;

      // Upload photos
      final List<String> photoUrls = [];
      for (final f in _photos) {
        try {
          final url =
              await StorageService.instance.uploadPhoto(widget.prestataireId, f);
          photoUrls.add(url);
        } catch (e) {
          if (kDebugMode) print('[CompletionProfil] Upload error: $e');
        }
      }

      // Mettre à jour le prestataire dans Firestore
      final updateData = <String, dynamic>{
        'metier': _metierController.text.trim(),
        'zone': zone,
        'ville': _selectedVille,
        'description': _descriptionController.text.trim(),
        'profilComplet': true,
      };

      if (_categorieEnum == Categorie.livreur) {
        updateData['type_engin'] = _selectedTypeEngin;
        updateData['tarif_zone'] = _tarifZoneController.text.trim();
      }

      if (photoUrls.isNotEmpty) {
        updateData['photos_portfolio'] = photoUrls;
        updateData['photoUrl'] = photoUrls.first;
      }

      await FirebaseService.instance.firestore
          .collection('prestataires')
          .doc(widget.prestataireId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil complété avec succès !'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        context.go('/accueil');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final villes = Zones.villesParPays(_paysId);
    final zonesPourVille = _selectedVille != null
        ? Zones.zonesParVille(_paysId, _selectedVille!)
        : <String>[];

    final photoTitle = _categorieEnum == Categorie.vendeur
        ? 'Photos de vos produits'
        : _categorieEnum == Categorie.livreur
            ? 'Photos de votre véhicule'
            : _categorieEnum == Categorie.liberal
                ? 'Photos de votre cabinet / bureau'
                : 'Photos de vos réalisations';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Compléter mon profil',
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const MiwodoSvgIcon('assets/icons/ic_arrow_back.svg', size: 24),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Bannière d'information
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrangeLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppColors.primaryOrange, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Complétez votre profil pour apparaître dans les recherches et attirer plus de clients.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Métier
              Text('Votre métier',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _metierController,
                decoration: InputDecoration(
                  labelText: _metierLabel(),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryOrange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Zone d'intervention
              Text('Zone d\'intervention',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Ville *'),
                value: _selectedVille,
                items: villes
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedVille = v;
                    _selectedQuartier = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              if (_selectedVille != null && zonesPourVille.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Quartier / Zone'),
                  value: _selectedQuartier,
                  items: zonesPourVille
                      .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedQuartier = v),
                ),
                const SizedBox(height: 12),
              ],

              // Champs spécifiques livreur
              if (_categorieEnum == Categorie.livreur) ...[
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Type d\'engin'),
                  value: _selectedTypeEngin,
                  items: ['Moto', 'Voiture', 'Vélo', 'Tricycle']
                      .map((e) => DropdownMenuItem(
                          value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedTypeEngin = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tarifZoneController,
                  decoration: const InputDecoration(labelText: 'Tarif / zone'),
                ),
                const SizedBox(height: 16),
              ],

              // Photos
              Text(photoTitle,
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Optionnel - Ajoutez des photos pour votre profil',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickPhotos,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryOrange.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          size: 40, color: AppColors.primaryOrange),
                      const SizedBox(height: 8),
                      Text('Ajouter des photos',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryOrange)),
                    ],
                  ),
                ),
              ),
              if (_photos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_photos.length, (i) {
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_photos[i],
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _removePhoto(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ],
              const SizedBox(height: 16),

              // Description
              Text('Description',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Décrivez votre activité, votre expérience...',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primaryOrange, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton sauvegarder
              MiwodoButton(
                label: 'Enregistrer mon profil',
                variant: MiwodoButtonVariant.primary,
                fullWidth: true,
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveProfile,
              ),
              const SizedBox(height: 12),
              // Skip optionnel
              Center(
                child: TextButton(
                  onPressed: () => context.go('/accueil'),
                  child: Text(
                    'Plus tard',
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metierLabel() {
    switch (_categorieEnum) {
      case Categorie.vendeur:
        return 'Type de commerce';
      case Categorie.livreur:
        return 'Type de livraison';
      case Categorie.liberal:
        return 'Spécialité';
      default:
        return 'Métier';
    }
  }
}
