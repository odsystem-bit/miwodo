// services/app_rating_service.dart
// ═══════════════════════════════════════════════════════════════════════════
// MIWODO — Système Intelligent de Notation 5 Étoiles Google Play
// - Filtre de satisfaction en 2 étapes :
//   * 4 ou 5 étoiles -> Redirection directe vers Google Play Store (com.miwodo.miwodo)
//   * 1 à 3 étoiles  -> Formulaire interne envoyé directement au Panel Admin (Signalements)
// - Règle anti-dérangement : délai de 7 jours si "Plus tard", arrêt après notation
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import 'firebase_service.dart';

class AppRatingService {
  AppRatingService._();
  static final AppRatingService instance = AppRatingService._();

  static const String kPlayStorePackage = 'com.miwodo.miwodo';
  static const String _kPrefHasRated = 'miwodo_has_rated_v1';
  static const String _kPrefLastPromptMs = 'miwodo_rating_last_prompt_ms_v1';
  static const String _kPrefPositiveActions = 'miwodo_positive_actions_count_v1';

  // Délai anti-dérangement : 7 jours
  static const int _kCooldownDays = 7;

  /// Enregistre une action positive (ex: appel artisan, 3e visite dashboard, commande reçue)
  /// et affiche automatiquement la boîte de notation si l'utilisateur est éligible.
  Future<void> recordPositiveActionAndPromptIfEligible(
    BuildContext context, {
    String source = 'auto',
    int threshold = 2,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRated = prefs.getBool(_kPrefHasRated) ?? false;
      if (hasRated) return;

      final count = (prefs.getInt(_kPrefPositiveActions) ?? 0) + 1;
      await prefs.setInt(_kPrefPositiveActions, count);

      if (count < threshold) return;

      final lastPromptMs = prefs.getInt(_kPrefLastPromptMs) ?? 0;
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final cooldownMs = _kCooldownDays * 24 * 3600 * 1000;

      if (lastPromptMs > 0 && (nowMs - lastPromptMs) < cooldownMs) {
        return;
      }

      await prefs.setInt(_kPrefLastPromptMs, nowMs);

      if (context.mounted) {
        await showRatingDialog(context, source: source);
      }
    } catch (_) {}
  }

  /// Ouvre directement la fiche Google Play Store de MIWODO
  Future<void> openGooglePlayStore() async {
    final marketUri = Uri.parse('market://details?id=$kPlayStorePackage');
    final webUri = Uri.parse(
      'https://play.google.com/store/apps/details?id=$kPlayStorePackage',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefHasRated, true);
    } catch (_) {}

    try {
      if (await canLaunchUrl(marketUri)) {
        await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  /// Envoie la note et l'avis éventuel au backend Hostinger (Panel Admin)
  Future<void> _sendFeedbackToBackend({
    required int stars,
    required String comment,
    required String phone,
    required String source,
  }) async {
    try {
      final user = FirebaseService.instance.auth.currentUser;
      await http
          .post(
            Uri.parse('https://bot.odsysteme.tech/api/app_feedback.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'stars': stars,
              'comment': comment,
              'phone': phone.isNotEmpty ? phone : (user?.phoneNumber ?? user?.email ?? 'Utilisateur App'),
              'user_id': user?.uid ?? 'INVITE',
              'source': source,
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
  }

  /// Affiche la modale interactive de notation en 2 étapes
  Future<void> showRatingDialog(
    BuildContext context, {
    String source = 'manuel',
  }) async {
    int selectedStars = 5;
    bool stepTwo = false;
    bool isSubmitting = false;

    final user = FirebaseService.instance.auth.currentUser;
    final commentController = TextEditingController();
    final phoneController = TextEditingController(
      text: user?.phoneNumber ?? user?.email ?? '',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefLastPromptMs, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isPositive = selectedStars >= 4;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // En-tête Navy avec Logo MIWODO
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF7A00).withAlpha(80),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.star_rounded,
                                  color: Color(0xFFFF7A00),
                                  size: 34,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              !stepTwo
                                  ? 'Votre avis compte pour MIWODO'
                                  : (isPositive
                                      ? 'Merci pour vos $selectedStars étoiles !'
                                      : 'Aidez-nous à améliorer MIWODO'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              !stepTwo
                                  ? 'Comment évaluez-vous votre expérience avec nos artisans et services ?'
                                  : (isPositive
                                      ? 'Votre note sur Google Play aide nos artisans locaux à se faire connaître.'
                                      : 'Dites-nous ce qui n\'a pas fonctionné. Notre équipe traitera votre retour en priorité.'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Corps de la modale
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Sélecteur des 5 étoiles
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (index) {
                                final starNumber = index + 1;
                                final isSelected = starNumber <= selectedStars;
                                return GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedStars = starNumber;
                                      stepTwo = true;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: AnimatedScale(
                                      scale: isSelected ? 1.12 : 1.0,
                                      duration: const Duration(milliseconds: 180),
                                      child: Icon(
                                        isSelected
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 42,
                                        color: isSelected
                                            ? const Color(0xFFFF7A00)
                                            : const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getStarLabel(selectedStars),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isPositive
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Si l'utilisateur a choisi 1, 2 ou 3 étoiles -> Formulaire interne privé
                            if (stepTwo && !isPositive) ...[
                              TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                style: GoogleFonts.inter(fontSize: 13),
                                decoration: InputDecoration(
                                  labelText: 'Votre numéro ou email (pour vous recontacter)',
                                  labelStyle: GoogleFonts.inter(fontSize: 12),
                                  prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: commentController,
                                maxLines: 3,
                                style: GoogleFonts.inter(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Expliquez-nous votre problème ou suggestion...',
                                  hintStyle: GoogleFonts.inter(fontSize: 12, color: Colors.black38),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAFC),
                                  contentPadding: const EdgeInsets.all(14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F172A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: isSubmitting
                                      ? null
                                      : () async {
                                          if (commentController.text.trim().isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Veuillez décrire brièvement votre remarque.'),
                                              ),
                                            );
                                            return;
                                          }
                                          setModalState(() => isSubmitting = true);
                                          await _sendFeedbackToBackend(
                                            stars: selectedStars,
                                            comment: commentController.text.trim(),
                                            phone: phoneController.text.trim(),
                                            source: source,
                                          );
                                          try {
                                            final prefs = await SharedPreferences.getInstance();
                                            await prefs.setBool(_kPrefHasRated, true);
                                          } catch (_) {}
                                          if (dialogCtx.mounted) {
                                            Navigator.pop(dialogCtx);
                                          }
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Merci ! Votre message a été transmis à la direction Miwodo.',
                                                ),
                                                backgroundColor: Color(0xFF15803D),
                                              ),
                                            );
                                          }
                                        },
                                  child: isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Envoyer à l\'équipe Miwodo',
                                          style: GoogleFonts.inter(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ] else ...[
                              // Si 4 ou 5 étoiles (ou étape 1 par défaut à 5 étoiles) -> Bouton Google Play Store
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryOrange,
                                    foregroundColor: Colors.white,
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                                  label: Text(
                                    'Noter $selectedStars étoiles sur Google Play',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(dialogCtx);
                                    _sendFeedbackToBackend(
                                      stars: selectedStars,
                                      comment: 'Redirection Google Play Store ($selectedStars étoiles)',
                                      phone: phoneController.text.trim(),
                                      source: source,
                                    );
                                    await openGooglePlayStore();
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.pop(dialogCtx),
                              child: Text(
                                'Plus tard',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getStarLabel(int stars) {
    switch (stars) {
      case 5:
        return 'Excellent (5/5) — Je recommande Miwodo !';
      case 4:
        return 'Très bien (4/5) — Application très utile';
      case 3:
        return 'Moyen (3/5) — Peut être amélioré';
      case 2:
        return 'Insuffisant (2/5) — J\'ai rencontré un souci';
      case 1:
        return 'Mécontent (1/5) — J\'ai besoin d\'aide';
      default:
        return '';
    }
  }
}
