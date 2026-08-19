// screens/inscription/inscription_screen.dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/categories.dart';
import '../../core/constants/zones.dart';
import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';
import '../../services/moneroo_service.dart';
import '../../widgets/moneroo_webview.dart';
import '../../core/utils/formatters.dart';
import '../../models/pays.dart';
import '../../providers/pays_provider.dart';
import 'inscription_notifier.dart';
import 'inscription_confirmation_screen.dart';

class InscriptionScreen extends ConsumerStatefulWidget {
  final String? initialReferralCode;

  const InscriptionScreen({super.key, this.initialReferralCode});

  @override
  ConsumerState<InscriptionScreen> createState() => _InscriptionScreenState();
}

class _InscriptionScreenState extends ConsumerState<InscriptionScreen> {
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Initialiser le code de parrainage si passé via deep link
    if (widget.initialReferralCode != null) {
      Future.microtask(() {
        ref
            .read(inscriptionNotifierProvider.notifier)
            .updateCodeParrain(widget.initialReferralCode);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inscriptionNotifierProvider);
    final notifier = ref.read(inscriptionNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Inscription')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgress(state.etape),
            const SizedBox(height: 16),
            if (state.etape == 1) _buildStep1(state, notifier),
            if (state.etape == 2) _buildStep2(state, notifier),
            if (state.etape == 3) _buildStep3(state, notifier),
            if (state.etape == 4) _buildStep4(state, notifier),
            if (state.etape == 5) _buildStep5(state, notifier),
            if (state.etape == 6) _buildStep6(state, notifier),
            const SizedBox(height: 24),
            Row(
              children: [
                if (state.etape > 1)
                  Expanded(
                    child: MiwodoButton(
                      label: 'Précédent',
                      variant: MiwodoButtonVariant.secondary,
                      onPressed: notifier.previousStep,
                    ),
                  ),
                if (state.etape > 1) const SizedBox(width: 12),
                Expanded(child: _buildPrimaryAction(state, notifier)),
              ],
            ),
            if (_isProcessing) const SizedBox(height: 24),
            if (_isProcessing) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  String _metierLabel(Categorie? c) {
    switch (c) {
      case Categorie.vendeur:
        return 'Type de commerce *';
      case Categorie.livreur:
        return 'Type de livraison *';
      case Categorie.liberal:
        return 'Spécialité *';
      default:
        return 'Métier *';
    }
  }

  Widget _buildProgress(int step) {
    Widget node(int i) {
      final completed = i < step;
      final active = i == step;
      if (completed) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.successGreen,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: MiwodoSvgIcon(
              'assets/icons/ic_verified.svg',
              size: 16,
              color: Colors.white,
            ),
          ),
        );
      }
      if (active) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primaryOrange,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$i',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        );
      }
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.borderGray,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$i',
            style: GoogleFonts.inter(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(7, (i) {
          final index = i + 1;
          return Row(
            children: [
              node(index),
              if (index < 7)
                SizedBox(
                  width: 30,
                  child: Container(
                    height: 2,
                    color: step > index
                        ? AppColors.primaryOrange
                        : AppColors.borderGray,
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStep1(InscriptionState state, InscriptionNotifier notifier) {
    final paysAsync = ref.watch(tousLesPaysProvider);
    final paysList = paysAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations personnelles',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(labelText: 'Prénom *'),
          onChanged: notifier.updatePrenom,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Nom *'),
          onChanged: notifier.updateNom,
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Email *'),
          keyboardType: TextInputType.emailAddress,
          onChanged: notifier.updateEmail,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Pays *'),
          value: state.paysId,
          items: paysList
              .where((p) => p.actif)
              .map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Row(
                    children: [
                      Text(p.drapeauEmoji),
                      const SizedBox(width: 8),
                      Text(p.nom),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) {
              notifier.updatePaysId(v);
              notifier.updateIndicatif(paysIndicatifs[v] ?? '+228');
            }
          },
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(labelText: 'Mot de passe *'),
          obscureText: true,
          onChanged: notifier.updatePassword,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.borderGray,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(state.indicatif ?? '+228'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(labelText: 'Téléphone *'),
                keyboardType: TextInputType.phone,
                onChanged: notifier.updateTelephone,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Code parrain (optionnel)',
          ),
          onChanged: notifier.updateCodeParrain,
        ),
      ],
    );
  }

  Widget _buildStep2(InscriptionState state, InscriptionNotifier notifier) {
    final options = Categorie.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catégorie et métier',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: options.map((c) {
            final selected = state.categorie == c;
            return GestureDetector(
              onTap: () => notifier.setCategorie(c),
              child: Container(
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryOrangeLight : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryOrange
                        : AppColors.borderGray,
                    width: selected ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    MiwodoSvgIcon(
                      c.svgIcon,
                      size: 40,
                      color: selected
                          ? AppColors.primaryOrange
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        c.label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(labelText: _metierLabel(state.categorie)),
          onChanged: notifier.updateMetier,
        ),
      ],
    );
  }

  Widget _buildStep3(InscriptionState state, InscriptionNotifier notifier) {
    final paysId = state.paysId ?? 'TG';
    final villes = Zones.villesParPays(paysId);
    // Extraire la ville depuis state.zone (qui peut être "Ville - Quartier" ou juste "Ville")
    final currentVille = state.zone.contains(' - ')
        ? state.zone.split(' - ').first
        : (villes.contains(state.zone) ? state.zone : '');
    final zonesPourVille = currentVille.isNotEmpty
        ? Zones.zonesParVille(paysId, currentVille)
        : <String>[];
    // Extraire le quartier actuel si présent
    final currentQuartier = state.zone.contains(' - ')
        ? state.zone.split(' - ').last
        : '';

    // Trouver le nom du pays pour l'affichage
    final paysList = ref.watch(tousLesPaysProvider);
    final paysData = paysList.asData?.value;
    String paysNom = paysId;
    if (paysData != null) {
      try {
        paysNom = paysData.firstWhere((p) => p.id == paysId).nom;
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zone d\'intervention',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '$paysNom · ${villes.length} ville(s) disponible(s)',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Sélection de la ville
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Ville *'),
          value: currentVille.isNotEmpty ? currentVille : null,
          items: villes
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) {
            notifier.updateZone(v ?? '');
          },
        ),
        const SizedBox(height: 12),

        // Sélection du quartier/zone dans la ville
        if (currentVille.isNotEmpty && zonesPourVille.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Quartier / Zone'),
            value: currentQuartier.isNotEmpty ? currentQuartier : null,
            items: zonesPourVille
                .map((z) => DropdownMenuItem(value: z, child: Text(z)))
                .toList(),
            onChanged: (v) {
              notifier.updateZone('$currentVille - ${v ?? ''}');
            },
          ),
          const SizedBox(height: 8),
        ],

        if (state.categorie == Categorie.livreur) ...[
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Type d\'engin'),
            value: state.typeEngin,
            items: [
              'Moto',
              'Voiture',
              'Vélo',
              'Tricycle',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
            onChanged: (v) => notifier.updateTypeEngin(v),
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: const InputDecoration(labelText: 'Tarif / zone'),
            onChanged: (v) => notifier.updateTarifZone(v),
          ),
        ],
      ],
    );
  }

  Widget _buildStep4(InscriptionState state, InscriptionNotifier notifier) {
    final cat = state.categorie;
    final photoTitle = cat == Categorie.vendeur
        ? 'Photos de vos produits'
        : cat == Categorie.livreur
        ? 'Photos de votre véhicule'
        : cat == Categorie.liberal
        ? 'Photos de votre cabinet / bureau'
        : 'Photos de vos réalisations';
    final photoHint = cat == Categorie.vendeur
        ? 'Ajoutez des photos de vos produits (optionnel)'
        : cat == Categorie.livreur
        ? 'Ajoutez des photos de votre véhicule (optionnel)'
        : cat == Categorie.liberal
        ? 'Ajoutez des photos de votre lieu de travail (optionnel)'
        : 'Ajoutez des photos de vos réalisations (optionnel)';
    final descHint = cat == Categorie.vendeur
        ? 'Décrivez votre boutique, vos produits...'
        : cat == Categorie.livreur
        ? 'Décrivez votre expérience, vos zones de livraison...'
        : cat == Categorie.liberal
        ? 'Décrivez votre expérience, vos diplômes, vos spécialités...'
        : 'Décrivez votre expérience, vos spécialités...';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          photoTitle,
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          photoHint,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Zone d'upload cliquable
        GestureDetector(
          onTap: () async {
            try {
              final picked = await _picker.pickMultiImage();
              if (picked.isNotEmpty) {
                for (final x in picked) {
                  notifier.addPhoto(File(x.path));
                }
              }
            } catch (e) {
              try {
                final x = await _picker.pickImage(source: ImageSource.gallery);
                if (x != null) notifier.addPhoto(File(x.path));
              } catch (e2) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Erreur: $e2')));
                }
              }
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.primaryOrangeLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryOrange.withAlpha(80),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 48,
                  color: AppColors.primaryOrange,
                ),
                const SizedBox(height: 12),
                Text(
                  'Ajouter des photos',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Touchez ici pour choisir depuis votre galerie',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Affichage des photos sélectionnées
        if (state.photos.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(state.photos.length, (i) {
              final f = state.photos[i];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      f,
                      width: 96,
                      height: 96,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => notifier.removePhotoAt(i),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(120),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            '${state.photos.length} photo(s) ajoutée(s)',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Description
        Text(
          'Description',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          maxLines: 5,
          decoration: InputDecoration(
            hintText: descHint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryOrange, width: 2),
            ),
          ),
          onChanged: notifier.updateDescription,
        ),
      ],
    );
  }

  Widget _buildStep5(InscriptionState state, InscriptionNotifier notifier) {
    final catLabel = state.categorie?.label ?? 'Non définie';
    final metierLabel = _metierLabel(state.categorie).replaceAll(' *', '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Récapitulatif',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.prenom} ${state.nom}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  state.email,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  state.telephone,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  'Catégorie: $catLabel',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  '$metierLabel: ${state.metier}',
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                Text(
                  state.zone,
                  style: GoogleFonts.inter(color: AppColors.textSecondary),
                ),
                if (state.categorie == Categorie.livreur) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${state.typeEngin} · ${state.tarifZone}',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep6(InscriptionState state, InscriptionNotifier notifier) {
    final paysAsync = ref.watch(tousLesPaysProvider);
    final paysList = paysAsync.valueOrNull ?? [];
    final paysId = state.paysId ?? 'TG';
    Pays pays;
    try {
      pays = paysList.firstWhere((p) => p.id == paysId);
    } catch (_) {
      pays = Pays.togo;
    }
    final symbole = pays.symbole;
    final montant = pays.inscriptionMontant;
    final isEuropeOrAmerique = pays.isEurope || pays.isAmerique;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paiement',
          style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryOrangeLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(
                'Accès complet à la plateforme',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                formatPrix(montant, symbole),
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEuropeOrAmerique
                    ? 'Paiement sécurisé par carte bancaire'
                    : 'Paiement unique · Pas d\'abonnement',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (!isEuropeOrAmerique) ..._buildMethodes(pays) else _buildCardInfo(),
        const SizedBox(height: 20),
        if (pays.monerooMethods.isEmpty && !isEuropeOrAmerique)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Le paiement en ligne n\'est pas encore disponible dans votre pays. Contactez le support.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.errorRed),
            ),
          ),
        MiwodoButton(
          label: 'Payer ${formatPrix(montant, symbole)} et s\'inscrire',
          variant: MiwodoButtonVariant.primary,
          fullWidth: true,
          onPressed:
              (_isProcessing ||
                  (pays.monerooMethods.isEmpty && !isEuropeOrAmerique))
              ? null
              : () => _startPayment(state, notifier, pays),
        ),
      ],
    );
  }

  List<Widget> _buildMethodes(Pays pays) {
    final methodes = pays.monerooMethods;
    return [
      Text(
        'Méthode de paiement',
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: methodes.map((m) {
          final label = monerooMethodLabels[m] ?? m;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryOrange),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryOrange,
              ),
            ),
          );
        }).toList(),
      ),
    ];
  }

  Widget _buildCardInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Paiement sécurisé SSL · Visa · Mastercard',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Votre carte ne sera débitée qu\'une seule fois',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryAction(
    InscriptionState state,
    InscriptionNotifier notifier,
  ) {
    if (state.etape < 6) {
      final enabled = switch (state.etape) {
        1 => notifier.validateStep1(),
        2 => notifier.validateStep2(),
        3 => notifier.validateStep3(),
        4 => notifier.validateStep4(),
        5 => notifier.validateStep5(),
        _ => true,
      };
      return MiwodoButton(
        label: 'Continuer',
        variant: MiwodoButtonVariant.primary,
        onPressed: enabled ? notifier.nextStep : null,
      );
    }
    // step 6 primary handled inside step view (payment)
    return const SizedBox.shrink();
  }

  Future<void> _startPayment(
    InscriptionState state,
    InscriptionNotifier notifier,
    Pays pays,
  ) async {
    setState(() => _isProcessing = true);
    try {
      // Vérifier si l'email est déjà utilisé AVANT le paiement
      if (state.email.isNotEmpty) {
        try {
          final methods = await FirebaseService.instance.auth
              .fetchSignInMethodsForEmail(state.email);
          if (methods.isNotEmpty) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Cet email est déjà utilisé par un compte existant. Connectez-vous ou utilisez un autre email.',
                  ),
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        } catch (_) {
          // Si la vérification échoue, on continue (ne bloque pas l'inscription)
        }
      }

      final res = await MonerooService.instance.initierInscription(
        prenom: state.prenom,
        nom: state.nom,
        email: state.email,
        telephone: state.telephone,
        paysId: pays.id,
        devise: pays.devise,
        montant: pays.inscriptionMontant,
        methods: pays.monerooMethods,
      );
      final checkoutUrl = res.checkoutUrl;
      if (!mounted) return;

      if (checkoutUrl.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Erreur: URL de paiement non reçue. Vérifiez votre connexion.',
              ),
            ),
          );
        }
        return;
      }

      final paymentId = await Navigator.of(context).push<String?>(
        MaterialPageRoute(
          builder: (_) => MonerooWebView(
            checkoutUrl: checkoutUrl,
            paymentId: res.id,
            onSuccess: (pid) {},
            onFailure: () {},
            onClose: () {},
          ),
        ),
      );

      if (paymentId == null) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Paiement annulé')));
        return;
      }

      // Vérifier le paiement avec retry (le paiement mobile money peut prendre du temps)
      MonerooVerifyResult? verify;
      for (int i = 0; i < 3; i++) {
        try {
          verify = await MonerooService.instance.verifierPaiement(paymentId);
          if (verify.status == 'success' || verify.status == 'successful')
            break;
          if (verify.status != 'pending') break;
          await Future.delayed(const Duration(seconds: 3));
        } catch (e) {
          if (i == 2) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      if (verify == null ||
          (verify.status != 'success' && verify.status != 'successful')) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Paiement non confirmé (statut: ${verify?.status ?? 'inconnu'}). Si vous avez payé, contactez le support.',
              ),
            ),
          );
        return;
      }

      // Créer l'utilisateur Firebase APRÈS paiement réussi
      String uid;
      try {
        final userCredential = await AuthService.instance.signUpWithEmail(
          state.email,
          state.password,
        );
        uid = userCredential.user?.uid ?? '';
      } on FirebaseAuthException catch (authErr) {
        if (authErr.code == 'email-already-in-use') {
          // L'email existe déjà — se connecter avec les identifiants
          final userCredential = await AuthService.instance.signInWithEmail(
            state.email,
            state.password,
          );
          uid = userCredential.user?.uid ?? '';
        } else {
          rethrow;
        }
      }
      if (uid.isEmpty) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: création du compte échouée')),
          );
        return;
      }

      // create prestataire: upload photos then create record
      final List<String> photoUrls = [];
      for (final f in state.photos) {
        try {
          final url = await StorageService.instance.uploadPhoto(uid, f);
          photoUrls.add(url);
        } catch (uploadErr) {
          if (kDebugMode)
            print('[Inscription] Upload photo échoué, ignoré: $uploadErr');
        }
      }

      // Générer un code parrain unique (MW + 6 caractères)
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final codeParrain =
          'MW${timestamp.substring(timestamp.length - 6).toUpperCase()}';

      final prest = Prestataire(
        id: uid,
        nom: state.nom,
        prenom: state.prenom,
        telephone: state.telephone,
        email: state.email.isEmpty ? null : state.email,
        categorie: state.categorie?.name ?? 'artisan',
        zone: state.zone,
        paysId: pays.id,
        paysNom: pays.nom,
        devise: pays.devise,
        symbole: pays.symbole,
        description: state.description.isEmpty ? null : state.description,
        photoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
        photosPortfolio: photoUrls,
        codeParrain: codeParrain,
        parrainePar:
            (state.codeParrain != null && state.codeParrain!.isNotEmpty)
            ? state.codeParrain
            : null,
        creeLe: DateTime.now(),
      );

      await FirestoreService.instance.createPrestataire(prest);

      // Enregistrer la transaction pour le dashboard admin
      try {
        await FirestoreService.instance.createTransaction(
          paymentId: paymentId,
          type: 'inscription',
          montant: pays.inscriptionMontant.toDouble(),
        );
      } catch (e) {
        if (kDebugMode) print('[Inscription] Transaction record error: $e');
      }

      // Notifier les admins de la nouvelle inscription
      try {
        await NotificationService.instance.notifyNewPrestataire(
          prestataireId: prest.id,
          prestataireName: '${state.prenom} ${state.nom}',
        );
      } catch (e) {
        if (kDebugMode) print('[Inscription] Notification error: $e');
      }

      final referral = 'https://miwodo.app/parrainage/$codeParrain';
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => InscriptionConfirmationScreen(
            prestataireId: prest.id,
            referralLink: referral,
          ),
        ),
      );
    } on MonerooException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.userMessage)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
