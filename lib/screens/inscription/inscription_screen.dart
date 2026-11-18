// screens/inscription/inscription_screen.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/categories.dart';
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
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final notif = ref.read(inscriptionNotifierProvider.notifier);
      final st = ref.read(inscriptionNotifierProvider);
      if (st.paysId == null) {
        notif.updatePaysId('TG');
        notif.updateIndicatif('+228');
      }
      if (widget.initialReferralCode != null) {
        notif.updateCodeParrain(widget.initialReferralCode);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inscriptionNotifierProvider);
    final notifier = ref.read(inscriptionNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (state.etape > 1) {
              notifier.previousStep();
            } else {
              Navigator.of(context).maybePop();
            }
          },
        ),
        title: Text(
          'Rejoindre MIWODO',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgress(state.etape),
            const SizedBox(height: 24),
            if (state.etape == 1) _buildStep1(state, notifier),
            if (state.etape == 2) _buildStep2(state, notifier),
            if (state.etape == 3) _buildStep3(state, notifier),
            if (state.etape == 4) _buildStep4(state, notifier),
            const SizedBox(height: 32),
            if (state.etape < 4)
              Row(
                children: [
                  if (state.etape > 1)
                    Expanded(
                      flex: 1,
                      child: MiwodoButton(
                        label: 'Précédent',
                        variant: MiwodoButtonVariant.secondary,
                        onPressed: notifier.previousStep,
                      ),
                    ),
                  if (state.etape > 1) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildPrimaryAction(state, notifier),
                  ),
                ],
              ),
            if (_isProcessing) const SizedBox(height: 24),
            if (_isProcessing)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primaryOrange),
                    SizedBox(height: 12),
                    Text(
                      'Traitement sécurisé en cours...',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(int currentStep) {
    final steps = [
      {'num': 1, 'label': 'Rôle'},
      {'num': 2, 'label': 'Contact'},
      {'num': 3, 'label': 'Activité'},
      {'num': 4, 'label': 'Paiement'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = (index ~/ 2) + 1;
            final isCompleted = stepIndex < currentStep;
            return Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: isCompleted
                      ? const LinearGradient(
                          colors: [Color(0xFF22C55E), Color(0xFFFF7A00)],
                        )
                      : null,
                  color: isCompleted ? null : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }

          final stepIndex = (index ~/ 2) + 1;
          final isCompleted = stepIndex < currentStep;
          final isActive = stepIndex == currentStep;
          final step = steps[index ~/ 2];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isActive
                      ? const LinearGradient(
                          colors: [Color(0xFFFF7A00), Color(0xFFE11D48)],
                        )
                      : null,
                  color: isCompleted
                      ? const Color(0xFF22C55E)
                      : isActive
                          ? null
                          : const Color(0xFFF1F5F9),
                  border: Border.all(
                    color: isActive
                        ? Colors.transparent
                        : isCompleted
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: const Color(0xFFFF7A00).withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                      : Text(
                          '${step['num']}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step['label'] as String,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive
                      ? const Color(0xFFFF7A00)
                      : isCompleted
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉTAPE 1 : CHOIX DU RÔLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep1(InscriptionState state, InscriptionNotifier notifier) {
    final roles = [
      {
        'role': Categorie.artisan,
        'title': 'Artisan Qualifié',
        'subtitle': 'Menuiserie, plomberie, électricité, maçonnerie, mécanique, peinture...',
        'icon': Icons.handyman_rounded,
        'tag': 'Populaire',
      },
      {
        'role': Categorie.liberal,
        'title': 'Profession Libérale',
        'subtitle': 'Comptabilité, conseil, droit, architecture, graphisme, ingénierie...',
        'icon': Icons.business_center_rounded,
        'tag': 'Experts',
      },
      {
        'role': Categorie.vendeur,
        'title': 'Commerçant / Vendeur',
        'subtitle': 'Boutique de quincaillerie, matériaux, pièces détachées, outillage...',
        'icon': Icons.storefront_rounded,
        'tag': 'Boutique',
      },
      {
        'role': Categorie.livreur,
        'title': 'Livreur Partenaire',
        'subtitle': 'Courses express, livraisons de colis, matériels et chantiers...',
        'icon': Icons.two_wheeler_rounded,
        'tag': 'Mobilité',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quel est votre profil ?',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sélectionnez votre type d\'activité pour configurer votre espace',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),
        ...roles.map((r) {
          final cat = r['role'] as Categorie;
          final isSelected = state.categorie == cat;

          return GestureDetector(
            onTap: () => notifier.setCategorie(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF7ED) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFFFF7A00).withOpacity(0.12)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFFF7A00), Color(0xFFE11D48)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      r['icon'] as IconData,
                      color: isSelected ? Colors.white : const Color(0xFF475569),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              r['title'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFEDD5)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r['tag'] as String,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? const Color(0xFFEA580C)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                    color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFFCBD5E1),
                    size: 24,
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉTAPE 2 : INFORMATIONS PERSONNELLES & CONTACT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep2(InscriptionState state, InscriptionNotifier notifier) {
    final paysAsync = ref.watch(tousLesPaysProvider);
    final paysList = paysAsync.valueOrNull ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vos Coordonnées',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Renseignez vos identifiants pour sécuriser votre compte',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),
        // Pays
        _buildInputContainer(
          label: 'Pays de résidence *',
          child: DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            value: state.paysId ?? 'TG',
            items: paysList
                .where((p) => p.actif)
                .map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        Text(p.drapeauEmoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Text(
                          p.nom,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
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
        ),
        const SizedBox(height: 14),
        // Nom & Prénom
        Row(
          children: [
            Expanded(
              child: _buildInputContainer(
                label: 'Prénom *',
                child: TextFormField(
                  initialValue: state.prenom,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Jean',
                    border: InputBorder.none,
                  ),
                  onChanged: notifier.updatePrenom,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputContainer(
                label: 'Nom *',
                child: TextFormField(
                  initialValue: state.nom,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Koffi',
                    border: InputBorder.none,
                  ),
                  onChanged: notifier.updateNom,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Téléphone avec indicatif
        _buildInputContainer(
          label: 'Numéro de téléphone *',
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.indicatif ?? '+228',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  initialValue: state.telephone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '90 00 00 00',
                    border: InputBorder.none,
                  ),
                  onChanged: notifier.updateTelephone,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Email
        _buildInputContainer(
          label: 'Adresse email *',
          child: TextFormField(
            initialValue: state.email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'votre.email@exemple.com',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF94A3B8), size: 20),
            ),
            onChanged: notifier.updateEmail,
          ),
        ),
        const SizedBox(height: 14),
        // Mot de passe
        _buildInputContainer(
          label: 'Mot de passe (min 6 caractères) *',
          child: TextFormField(
            initialValue: state.password,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: '••••••••',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: notifier.updatePassword,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉTAPE 3 : ACTIVITÉ & LOCALISATION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep3(InscriptionState state, InscriptionNotifier notifier) {
    String metierHint = 'Ex: Électricien bâtiment';
    String metierLabel = 'Métier / Spécialité *';

    if (state.categorie == Categorie.vendeur) {
      metierLabel = 'Type de boutique / Matériaux *';
      metierHint = 'Ex: Quincaillerie générale, Pièces auto...';
    } else if (state.categorie == Categorie.livreur) {
      metierLabel = 'Type de livraison & Véhicule *';
      metierHint = 'Ex: Moto coursier, Camionnette...';
    } else if (state.categorie == Categorie.liberal) {
      metierLabel = 'Domaine d\'expertise *';
      metierHint = 'Ex: Architecte DPLG, Expert comptable...';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Votre Activité',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Indiquez ce que vous proposez et où vous intervenez',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),
        _buildInputContainer(
          label: metierLabel,
          child: TextFormField(
            initialValue: state.metier,
            decoration: InputDecoration(
              hintText: metierHint,
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.work_outline_rounded, color: Color(0xFF94A3B8), size: 20),
            ),
            onChanged: notifier.updateMetier,
          ),
        ),
        const SizedBox(height: 14),
        _buildInputContainer(
          label: 'Zone / Ville d\'intervention *',
          child: TextFormField(
            initialValue: state.zone,
            decoration: const InputDecoration(
              hintText: 'Ex: Lomé, Golfe, Agoè, Bè...',
              border: InputBorder.none,
              prefixIcon: Icon(Icons.location_on_outlined, color: Color(0xFF94A3B8), size: 20),
            ),
            onChanged: notifier.updateZone,
          ),
        ),
        const SizedBox(height: 14),
        _buildInputContainer(
          label: 'Description de vos services (optionnelle)',
          child: TextFormField(
            initialValue: state.description,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Décrivez brièvement vos compétences, années d\'expérience...',
              border: InputBorder.none,
            ),
            onChanged: notifier.updateDescription,
          ),
        ),
        const SizedBox(height: 18),
        // Code Parrain Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFEDD5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF7A00), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Code de parrainage (Optionnel)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Si un collègue ou ami vous a recommandé MIWODO, saisissez son code pour lui faire bénéficier du bonus parrain.',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: TextFormField(
                  initialValue: state.codeParrain,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Ex: MW849201',
                    border: InputBorder.none,
                  ),
                  onChanged: notifier.updateCodeParrain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ÉTAPE 4 : VALIDATION & ACTIVATION DU COMPTE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStep4(InscriptionState state, InscriptionNotifier notifier) {
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
          'Récapitulatif & Activation',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Vérifiez vos informations avant de finaliser votre inscription',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 20),
        // Profil Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFFFEDD5),
                    child: Text(
                      '${state.prenom.isNotEmpty ? state.prenom[0].toUpperCase() : ''}${state.nom.isNotEmpty ? state.nom[0].toUpperCase() : ''}',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF7A00),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${state.prenom} ${state.nom}',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.metier.isNotEmpty ? state.metier : state.categorie?.label ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFFD8A8)),
                    ),
                    child: Text(
                      state.categorie?.label ?? 'Artisan',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFF7A00),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryItem('Téléphone', '${state.indicatif ?? '+228'} ${state.telephone}'),
                  _buildSummaryItem('Zone', state.zone.isNotEmpty ? state.zone : 'Non précisée'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Tarif Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Frais d\'adhésion unique',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFFED7AA),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                formatPrix(montant, symbole),
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEuropeOrAmerique
                    ? 'Paiement sécurisé par carte bancaire'
                    : 'Paiement unique · Aucun abonnement mensuel · Accès permanent',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Méthodes
        if (!isEuropeOrAmerique) ..._buildMethodes(pays) else _buildCardInfo(),
        const SizedBox(height: 24),
        if (pays.monerooMethods.isEmpty && !isEuropeOrAmerique)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Le paiement en ligne n\'est pas encore configuré pour votre pays. Contactez le support.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.errorRed),
            ),
          ),
        Row(
          children: [
            Expanded(
              flex: 1,
              child: MiwodoButton(
                label: 'Précédent',
                variant: MiwodoButtonVariant.secondary,
                onPressed: notifier.previousStep,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: MiwodoButton(
                label: 'Payer ${formatPrix(montant, symbole)}',
                variant: MiwodoButtonVariant.primary,
                onPressed: (_isProcessing ||
                        (pays.monerooMethods.isEmpty && !isEuropeOrAmerique))
                    ? null
                    : () => _startPayment(state, notifier, pays),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildInputContainer({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          child,
        ],
      ),
    );
  }

  List<Widget> _buildMethodes(Pays pays) {
    final methodes = pays.monerooMethods;
    return [
      Text(
        'Modes de paiement disponibles',
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: methodes.map((m) {
          final label = monerooMethodLabels[m] ?? m;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD8A8)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFFFF7A00), size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
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
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                'Paiement sécurisé SSL · Visa · Mastercard',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Votre carte ne sera débitée qu\'une seule fois',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: const Color(0xFF64748B),
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
    bool isEnabled = false;

    if (state.etape == 1) {
      isEnabled = notifier.validateStep1();
    } else if (state.etape == 2) {
      isEnabled = notifier.validateStep2();
    } else if (state.etape == 3) {
      isEnabled = notifier.validateStep3();
    }

    return MiwodoButton(
      label: 'Continuer',
      variant: MiwodoButtonVariant.primary,
      onPressed: isEnabled ? notifier.nextStep : null,
    );
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
          // Si la vérification échoue, on continue
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Paiement annulé')),
          );
        }
        return;
      }

      // Vérifier le paiement avec retry
      MonerooVerifyResult? verify;
      for (int i = 0; i < 3; i++) {
        try {
          verify = await MonerooService.instance.verifierPaiement(paymentId);
          if (verify.status == 'success' || verify.status == 'successful') break;
          if (verify.status != 'pending') break;
          await Future.delayed(const Duration(seconds: 3));
        } catch (e) {
          if (i == 2) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      if (verify == null ||
          (verify.status != 'success' && verify.status != 'successful')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Paiement non confirmé (statut: ${verify?.status ?? 'inconnu'}). Si vous avez payé, contactez le support.',
              ),
            ),
          );
        }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: création du compte échouée')),
          );
        }
        return;
      }

      // Upload photos portfolio si disponibles
      final List<String> photoUrls = [];
      for (final f in state.photos) {
        try {
          final url = await StorageService.instance.uploadPhoto(uid, f);
          photoUrls.add(url);
        } catch (uploadErr) {
          if (kDebugMode) print('[Inscription] Upload photo échoué, ignoré: $uploadErr');
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
        metier: state.metier.isEmpty ? null : state.metier,
        zone: state.zone,
        paysId: pays.id,
        paysNom: pays.nom,
        devise: pays.devise,
        symbole: pays.symbole,
        description: state.description.isEmpty ? null : state.description,
        photoUrl: photoUrls.isNotEmpty ? photoUrls.first : null,
        photosPortfolio: photoUrls,
        codeParrain: codeParrain,
        parrainePar: (state.codeParrain != null && state.codeParrain!.isNotEmpty)
            ? state.codeParrain
            : null,
        profilComplet: false,
        creeLe: DateTime.now(),
      );

      await FirestoreService.instance.createPrestataire(prest);

      // Créditer automatiquement le parrain si un code a été renseigné
      if (state.codeParrain != null && state.codeParrain!.trim().isNotEmpty) {
        try {
          final gain = pays.parrainageGain > 0 ? pays.parrainageGain.toDouble() : 100.0;
          await FirestoreService.instance.crediterParrain(
            codeParrain: state.codeParrain!,
            filleulId: prest.id,
            filleulNom: '${prest.prenom} ${prest.nom}',
            filleulMetier: prest.metier,
            filleulCategorie: prest.categorie,
            montantGain: gain,
            devise: prest.symbole,
          );
        } catch (parrainErr) {
          if (kDebugMode) print('[Inscription] Erreur traitement parrainage: $parrainErr');
        }
      }

      // Synchroniser également avec l'API MySQL Hostinger (parrain_codes & parrainages)
      try {
        await http.post(
          Uri.parse('https://bot.odsysteme.tech/api/parrainage.php'),
          headers: {
            'Content-Type': 'application/json',
            'X-Api-Key': 'aadc42b40f152ad0133c93e5e154a843fc61952072b35e80',
          },
          body: jsonEncode({
            'action': 'register',
            'filleul_id': prest.id,
            'code': codeParrain,
            'parrain_code': state.codeParrain ?? '',
            'filleul_nom': '${prest.prenom} ${prest.nom}',
            'pays_id': pays.id,
          }),
        ).timeout(const Duration(seconds: 10));
      } catch (hostingerErr) {
        if (kDebugMode) print('[Inscription] Sync Hostinger parrainage non bloquant: $hostingerErr');
      }

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.userMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
