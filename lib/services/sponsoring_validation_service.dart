// services/sponsoring_validation_service.dart
// Service de validation automatique intelligente des campagnes de sponsoring

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sponsoring_campaign.dart';
import '../models/sponsoring_validation.dart';
import '../models/service_prestataire.dart';
import 'sponsoring_service.dart';

class SponsoringValidationService {
  static final SponsoringValidationService instance = SponsoringValidationService._();
  SponsoringValidationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Récupère les paramètres de validation depuis Firestore
  Future<SponsoringSettings> getSettings() async {
    try {
      final doc = await _db.collection('config').doc('sponsoring_settings').get();
      if (doc.exists) {
        return SponsoringSettings.fromJson(doc.data()!);
      }
      // Créer avec les valeurs par défaut si n'existe pas
      final defaults = SponsoringSettings(modifieLe: DateTime.now());
      await _db.collection('config').doc('sponsoring_settings').set(defaults.toJson());
      return defaults;
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] getSettings error: $e');
      return SponsoringSettings(modifieLe: DateTime.now());
    }
  }

  /// Met à jour les paramètres
  Future<void> updateSettings(SponsoringSettings settings) async {
    try {
      await _db.collection('config').doc('sponsoring_settings').set(settings.toJson());
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] updateSettings error: $e');
      rethrow;
    }
  }

  /// Stream des paramètres pour réactivité
  Stream<SponsoringSettings> watchSettings() {
    return _db.collection('config').doc('sponsoring_settings').snapshots().map((doc) {
      if (doc.exists) {
        return SponsoringSettings.fromJson(doc.data()!);
      }
      return SponsoringSettings(modifieLe: DateTime.now());
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VALIDATION PRINCIPALE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Analyse une campagne et retourne le résultat de validation
  Future<SponsoringValidationResult> validateCampaign(SponsoringCampaign campaign) async {
    final settings = await getSettings();
    final checks = <ValidationCheck>[];
    final reasons = <String>[];

    // 1. Le service existe réellement
    checks.add(await _checkServiceExists(campaign.serviceId, reasons));

    // 2. Le prestataire est propriétaire du service
    checks.add(await _checkServiceOwnership(campaign.serviceId, campaign.prestataireId, reasons));

    // 3. Le paiement a été confirmé
    checks.add(_checkPaymentConfirmed(campaign, reasons));

    // 4. Le service est complet (titre, description, prix, catégorie, au moins une image)
    checks.add(await _checkServiceCompleteness(campaign.serviceId, reasons));

    // 5. Les images sont valides et accessibles
    checks.add(await _checkImagesValid(campaign.serviceId, reasons));

    // 6. Aucun contenu vide ou incohérent
    checks.add(await _checkContentCoherent(campaign.serviceId, reasons));

    // 7. Aucun texte interdit ou offensant
    checks.add(await _checkForbiddenContent(campaign.serviceId, settings, reasons));

    // 8. Aucun spam (répétition excessive, caractères anormaux, emojis en masse)
    checks.add(await _checkSpamContent(campaign.serviceId, settings, reasons));

    // 9. Aucun doublon de campagne déjà active pour le même service
    checks.add(await _checkNoDuplicateActive(campaign.serviceId, campaign.id, reasons));

    // 10. Le compte du prestataire n'est pas suspendu
    checks.add(await _checkPrestataireActive(campaign.prestataireId, reasons));

    // 11. Les dates de la campagne sont cohérentes
    checks.add(_checkDatesCoherent(campaign, reasons));

    // 12. Le budget et le plan sont valides
    checks.add(_checkBudgetAndPlan(campaign, reasons));

    // Calcul du score
    final score = _calculateScore(checks);

    // Déterminer le mode de validation
    final bool autoApproved = settings.autoValidationActive && score >= settings.seuilConfianceAuto && reasons.isEmpty;
    final bool shouldLog = score >= settings.seuilJournalisation && score < settings.seuilConfianceAuto;

    ValidationMode mode;
    if (autoApproved) {
      mode = ValidationMode.automatique;
    } else if (shouldLog && reasons.isEmpty) {
      mode = ValidationMode.automatique; // Auto avec journalisation
    } else {
      mode = ValidationMode.manuelle; // Vérification humaine
    }

    final result = SponsoringValidationResult(
      score: score,
      checks: checks,
      reasons: reasons,
      mode: mode,
      autoApproved: autoApproved,
      analyseLe: DateTime.now(),
    );

    // Journaliser la décision
    await _logValidation(campaign, result);

    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTRÔLES INDIVIDUELS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<ValidationCheck> _checkServiceExists(String serviceId, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        reasons.add('Le service n\'existe pas');
        return ValidationCheck(name: 'service_exists', passed: false, reason: 'Service introuvable', weight: 2.0);
      }
      return ValidationCheck(name: 'service_exists', passed: true, weight: 2.0);
    } catch (e) {
      reasons.add('Erreur lors de la vérification du service');
      return ValidationCheck(name: 'service_exists', passed: false, reason: e.toString(), weight: 2.0);
    }
  }

  Future<ValidationCheck> _checkServiceOwnership(String serviceId, String prestataireId, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        reasons.add('Service introuvable pour vérification de propriété');
        return ValidationCheck(name: 'service_ownership', passed: false, reason: 'Service introuvable', weight: 2.0);
      }
      final data = doc.data()!;
      final owner = data['prestataireId'] as String? ?? data['prestataire_id'] as String? ?? '';
      if (owner != prestataireId) {
        reasons.add('Le prestataire n\'est pas propriétaire du service');
        return ValidationCheck(name: 'service_ownership', passed: false, reason: 'Propriétaire mismatch', weight: 2.0);
      }
      return ValidationCheck(name: 'service_ownership', passed: true, weight: 2.0);
    } catch (e) {
      reasons.add('Erreur lors de la vérification de propriété');
      return ValidationCheck(name: 'service_ownership', passed: false, reason: e.toString(), weight: 2.0);
    }
  }

  ValidationCheck _checkPaymentConfirmed(SponsoringCampaign campaign, List<String> reasons) {
    if (campaign.paymentId == null || campaign.paymentId!.isEmpty) {
      reasons.add('Aucun paiement associé à la campagne');
      return ValidationCheck(name: 'payment_confirmed', passed: false, reason: 'PaymentId manquant', weight: 2.0);
    }
    return ValidationCheck(name: 'payment_confirmed', passed: true, weight: 2.0);
  }

  Future<ValidationCheck> _checkServiceCompleteness(String serviceId, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        reasons.add('Service introuvable pour vérification de complétude');
        return ValidationCheck(name: 'service_completeness', passed: false, reason: 'Service introuvable', weight: 1.5);
      }
      final data = doc.data()!;
      final service = ServicePrestataire.fromJson({...data, 'id': doc.id});

      final issues = <String>[];
      if (service.nom.trim().isEmpty || service.nom.trim().length < 3) {
        issues.add('titre trop court');
      }
      if (service.description == null || service.description!.trim().isEmpty) {
        issues.add('description manquante');
      }
      if (service.prixMin == null && service.prixMax == null) {
        issues.add('prix manquant');
      }
      if (service.images.isEmpty) {
        issues.add('aucune image');
      }

      if (issues.isNotEmpty) {
        reasons.add('Service incomplet: ${issues.join(', ')}');
        return ValidationCheck(name: 'service_completeness', passed: false, reason: issues.join(', '), weight: 1.5);
      }
      return ValidationCheck(name: 'service_completeness', passed: true, weight: 1.5);
    } catch (e) {
      reasons.add('Erreur lors de la vérification de complétude');
      return ValidationCheck(name: 'service_completeness', passed: false, reason: e.toString(), weight: 1.5);
    }
  }

  Future<ValidationCheck> _checkImagesValid(String serviceId, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        return ValidationCheck(name: 'images_valid', passed: false, reason: 'Service introuvable', weight: 1.0);
      }
      final data = doc.data()!;
      final images = (data['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

      if (images.isEmpty) {
        reasons.add('Aucune image dans le service');
        return ValidationCheck(name: 'images_valid', passed: false, reason: 'Aucune image', weight: 1.0);
      }

      // Vérifier que les URLs sont valides (format basique)
      final invalidUrls = images.where((url) => !url.startsWith('http://') && !url.startsWith('https://')).toList();
      if (invalidUrls.isNotEmpty) {
        reasons.add('${invalidUrls.length} image(s) avec URL invalide');
        return ValidationCheck(name: 'images_valid', passed: false, reason: 'URLs invalides', weight: 1.0);
      }

      return ValidationCheck(name: 'images_valid', passed: true, weight: 1.0);
    } catch (e) {
      reasons.add('Erreur lors de la vérification des images');
      return ValidationCheck(name: 'images_valid', passed: false, reason: e.toString(), weight: 1.0);
    }
  }

  Future<ValidationCheck> _checkContentCoherent(String serviceId, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        return ValidationCheck(name: 'content_coherent', passed: false, reason: 'Service introuvable', weight: 1.0);
      }
      final data = doc.data()!;
      final nom = (data['nom'] as String?)?.trim() ?? '';
      final description = (data['description'] as String?)?.trim() ?? '';

      final issues = <String>[];
      // Vérifier que le nom n'est pas que des espaces ou caractères spéciaux
      if (nom.replaceAll(RegExp(r'[\s\W]'), '').isEmpty) {
        issues.add('nom incohérent');
      }
      // Vérifier que la description a un minimum de contenu
      if (description.isNotEmpty && description.length < 10) {
        issues.add('description trop courte');
      }
      // Vérifier qu'il n'y a pas de texte vide répétitif
      if (nom == description && nom.isNotEmpty) {
        issues.add('nom et description identiques');
      }

      if (issues.isNotEmpty) {
        reasons.add('Contenu incohérent: ${issues.join(', ')}');
        return ValidationCheck(name: 'content_coherent', passed: false, reason: issues.join(', '), weight: 1.0);
      }
      return ValidationCheck(name: 'content_coherent', passed: true, weight: 1.0);
    } catch (e) {
      reasons.add('Erreur lors de la vérification de cohérence');
      return ValidationCheck(name: 'content_coherent', passed: false, reason: e.toString(), weight: 1.0);
    }
  }

  Future<ValidationCheck> _checkForbiddenContent(String serviceId, SponsoringSettings settings, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        return ValidationCheck(name: 'forbidden_content', passed: false, reason: 'Service introuvable', weight: 2.5);
      }
      final data = doc.data()!;
      final nom = (data['nom'] as String?)?.toLowerCase() ?? '';
      final description = (data['description'] as String?)?.toLowerCase() ?? '';
      final fullText = '$nom $description';

      // Vérifier les mots interdits
      final foundForbidden = settings.motsInterdits.where((word) => fullText.contains(word.toLowerCase())).toList();
      if (foundForbidden.isNotEmpty) {
        reasons.add('Contenu interdit détecté: ${foundForbidden.join(', ')}');
        return ValidationCheck(name: 'forbidden_content', passed: false, reason: 'Mots interdits: ${foundForbidden.join(', ')}', weight: 2.5);
      }

      // Vérifier les mots suspects (pénalité mais pas bloquant)
      final foundSuspicious = settings.motsSuspects.where((word) => fullText.contains(word.toLowerCase())).toList();
      if (foundSuspicious.isNotEmpty) {
        // Les mots suspects ne bloquent pas mais réduisent le score
        return ValidationCheck(name: 'forbidden_content', passed: true, reason: 'Mots suspects: ${foundSuspicious.join(', ')}', weight: 0.7);
      }

      return ValidationCheck(name: 'forbidden_content', passed: true, weight: 2.5);
    } catch (e) {
      reasons.add('Erreur lors de la vérification de contenu interdit');
      return ValidationCheck(name: 'forbidden_content', passed: false, reason: e.toString(), weight: 2.5);
    }
  }

  Future<ValidationCheck> _checkSpamContent(String serviceId, SponsoringSettings settings, List<String> reasons) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (!doc.exists) {
        return ValidationCheck(name: 'spam_content', passed: false, reason: 'Service introuvable', weight: 1.5);
      }
      final data = doc.data()!;
      final nom = (data['nom'] as String?) ?? '';
      final description = (data['description'] as String?) ?? '';
      final fullText = '$nom $description';

      final issues = <String>[];

      // 1. Répétition excessive de caractères (ex: "aaaaaaa", "!!!!!!")
      final repetitionRegex = RegExp('(.)\\1{${settings.maxCaracteresRepetition},}');
      if (repetitionRegex.hasMatch(fullText)) {
        issues.add('répétition excessive de caractères');
      }

      // 2. Emojis en masse
      final emojiCount = _countEmojis(fullText);
      if (emojiCount > settings.maxEmojisAutorises) {
        issues.add('$emojiCount emojis détectés (max ${settings.maxEmojisAutorises})');
      }

      // 3. Majuscules excessives (criage)
      final upperCount = fullText.replaceAll(RegExp(r'[^A-Z]'), '').length;
      final letterCount = fullText.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      if (letterCount > 10 && upperCount / letterCount > 0.5) {
        issues.add('usage excessif de majuscules');
      }

      // 4. Caractères anormaux (non-imprimables, contrôle)
      final controlChars = RegExp(r'[\x00-\x1F\x7F]');
      if (controlChars.hasMatch(fullText)) {
        issues.add('caractères de contrôle détectés');
      }

      // 5. Répétition de mots
      final words = fullText.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toList();
      final wordFreq = <String, int>{};
      for (final word in words) {
        wordFreq[word] = (wordFreq[word] ?? 0) + 1;
      }
      final repeatedWords = wordFreq.entries.where((e) => e.value > 3).toList();
      if (repeatedWords.isNotEmpty) {
        issues.add('répétition de mots: ${repeatedWords.map((e) => e.key).take(3).join(', ')}');
      }

      if (issues.isNotEmpty) {
        reasons.add('Spam détecté: ${issues.join(', ')}');
        return ValidationCheck(name: 'spam_content', passed: false, reason: issues.join(', '), weight: 1.5);
      }
      return ValidationCheck(name: 'spam_content', passed: true, weight: 1.5);
    } catch (e) {
      reasons.add('Erreur lors de la vérification anti-spam');
      return ValidationCheck(name: 'spam_content', passed: false, reason: e.toString(), weight: 1.5);
    }
  }

  Future<ValidationCheck> _checkNoDuplicateActive(String serviceId, String campaignId, List<String> reasons) async {
    try {
      final snap = await _db
          .collection('sponsoring_campaigns')
          .where('serviceId', isEqualTo: serviceId)
          .where('statut', isEqualTo: CampaignStatut.active.label)
          .get();

      final duplicates = snap.docs.where((doc) => doc.id != campaignId).toList();
      if (duplicates.isNotEmpty) {
        reasons.add('Une campagne active existe déjà pour ce service');
        return ValidationCheck(name: 'no_duplicate_active', passed: false, reason: 'Doublon de campagne active', weight: 1.5);
      }
      return ValidationCheck(name: 'no_duplicate_active', passed: true, weight: 1.5);
    } catch (e) {
      reasons.add('Erreur lors de la vérification de doublon');
      return ValidationCheck(name: 'no_duplicate_active', passed: false, reason: e.toString(), weight: 1.5);
    }
  }

  Future<ValidationCheck> _checkPrestataireActive(String prestataireId, List<String> reasons) async {
    try {
      final doc = await _db.collection('prestataires').doc(prestataireId).get();
      if (!doc.exists) {
        reasons.add('Le compte prestataire n\'existe pas');
        return ValidationCheck(name: 'prestataire_active', passed: false, reason: 'Compte introuvable', weight: 2.0);
      }
      final data = doc.data()!;
      final actif = data['actif'] as bool? ?? true;
      if (!actif) {
        reasons.add('Le compte du prestataire est suspendu');
        return ValidationCheck(name: 'prestataire_active', passed: false, reason: 'Compte suspendu', weight: 2.0);
      }
      return ValidationCheck(name: 'prestataire_active', passed: true, weight: 2.0);
    } catch (e) {
      reasons.add('Erreur lors de la vérification du prestataire');
      return ValidationCheck(name: 'prestataire_active', passed: false, reason: e.toString(), weight: 2.0);
    }
  }

  ValidationCheck _checkDatesCoherent(SponsoringCampaign campaign, List<String> reasons) {
    final now = DateTime.now();
    final issues = <String>[];

    if (campaign.dateDebut.isAfter(campaign.dateFin)) {
      issues.add('date de début après date de fin');
    }
    if (campaign.dateFin.isBefore(now)) {
      issues.add('date de fin déjà passée');
    }
    // Durée maximale: 90 jours
    final duration = campaign.dateFin.difference(campaign.dateDebut).inDays;
    if (duration > 90) {
      issues.add('durée supérieure à 90 jours');
    }
    if (duration < 1) {
      issues.add('durée inférieure à 1 jour');
    }

    if (issues.isNotEmpty) {
      reasons.add('Dates incohérentes: ${issues.join(', ')}');
      return ValidationCheck(name: 'dates_coherent', passed: false, reason: issues.join(', '), weight: 1.0);
    }
    return ValidationCheck(name: 'dates_coherent', passed: true, weight: 1.0);
  }

  ValidationCheck _checkBudgetAndPlan(SponsoringCampaign campaign, List<String> reasons) {
    final issues = <String>[];

    if (campaign.montant <= 0) {
      issues.add('montant invalide');
    }
    if (campaign.plan != SponsoringPlan.standard && campaign.plan != SponsoringPlan.premium) {
      issues.add('plan invalide');
    }
    // Montants minimums attendus
    if (campaign.plan == SponsoringPlan.standard && campaign.montant < 500) {
      issues.add('montant trop bas pour plan standard');
    }
    if (campaign.plan == SponsoringPlan.premium && campaign.montant < 1000) {
      issues.add('montant trop bas pour plan premium');
    }

    if (issues.isNotEmpty) {
      reasons.add('Budget/plan invalide: ${issues.join(', ')}');
      return ValidationCheck(name: 'budget_plan', passed: false, reason: issues.join(', '), weight: 1.0);
    }
    return ValidationCheck(name: 'budget_plan', passed: true, weight: 1.0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALCUL DU SCORE
  // ═══════════════════════════════════════════════════════════════════════════

  double _calculateScore(List<ValidationCheck> checks) {
    if (checks.isEmpty) return 0;

    double totalWeight = 0;
    double earnedWeight = 0;

    for (final check in checks) {
      totalWeight += check.weight;
      if (check.passed) {
        earnedWeight += check.weight;
      } else {
        // Pénalité partielle pour les échecs (50% du poids au lieu de 0)
        earnedWeight += check.weight * 0.0;
      }
    }

    if (totalWeight == 0) return 0;
    return (earnedWeight / totalWeight) * 100;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // JOURNALISATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _logValidation(SponsoringCampaign campaign, SponsoringValidationResult result) async {
    try {
      final log = SponsoringValidationLog(
        id: '',
        campaignId: campaign.id,
        serviceId: campaign.serviceId,
        serviceName: campaign.serviceName,
        prestataireId: campaign.prestataireId,
        prestataireNom: campaign.prestataireNom,
        score: result.score,
        mode: result.mode,
        checks: result.checks,
        reasons: result.reasons,
        autoApproved: result.autoApproved,
        analyseLe: result.analyseLe,
      );
      await _db.collection('sponsoring_validation_logs').add(log.toJson());
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] _logValidation error: $e');
    }
  }

  /// Stream des logs de validation pour l'admin
  Stream<List<SponsoringValidationLog>> getValidationLogs({int limit = 50}) {
    try {
      return _db
          .collection('sponsoring_validation_logs')
          .orderBy('analyseLe', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return SponsoringValidationLog.fromJson(data);
              }).toList());
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] getValidationLogs error: $e');
      return Stream.value([]);
    }
  }

  /// Stream des logs pour une campagne spécifique
  Stream<List<SponsoringValidationLog>> getLogsForCampaign(String campaignId) {
    try {
      return _db
          .collection('sponsoring_validation_logs')
          .where('campaignId', isEqualTo: campaignId)
          .orderBy('analyseLe', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return SponsoringValidationLog.fromJson(data);
              }).toList());
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] getLogsForCampaign error: $e');
      return Stream.value([]);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS POST-VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Traite une campagne après création: valide automatiquement ou envoie en vérification
  Future<void> processCampaignAfterCreation(SponsoringCampaign campaign) async {
    try {
      final result = await validateCampaign(campaign);

      if (result.autoApproved) {
        // Validation automatique
        await SponsoringService.instance.updateCampaignStatut(
          campaign.id,
          CampaignStatut.active,
          adminNote: 'Validation automatique (score: ${result.score.toStringAsFixed(1)}%)',
        );

        // Notifier le prestataire
        await _notifyPrestataire(
          campaign.prestataireId,
          'Campagne approuvée automatiquement',
          'Votre campagne pour "${campaign.serviceName}" a été approuvée automatiquement (score: ${result.score.toStringAsFixed(1)}%).',
          'sponsoring_auto_approved',
        );
      } else {
        // Vérification humaine requise — notifier les admins
        await _notifyAdmins(
          'Campagne à vérifier',
          'La campagne "${campaign.serviceName}" (${campaign.prestataireNom}) nécessite une vérification. Score: ${result.score.toStringAsFixed(1)}%. Raisons: ${result.reasons.join(', ')}',
          'sponsoring_manual_review',
        );
      }
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] processCampaignAfterCreation error: $e');
    }
  }

  Future<void> _notifyPrestataire(String prestataireId, String title, String body, String type) async {
    try {
      await _db.collection('notifications').add({
        'userId': prestataireId,
        'title': title,
        'body': body,
        'type': type,
        'estLu': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] _notifyPrestataire error: $e');
    }
  }

  Future<void> _notifyAdmins(String title, String body, String type) async {
    try {
      final adminsSnap = await _db.collection('admins').where('actif', isEqualTo: true).get();
      for (final doc in adminsSnap.docs) {
        await _db.collection('notifications').add({
          'userId': doc.id,
          'title': title,
          'body': body,
          'type': type,
          'estLu': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      if (kDebugMode) print('[SponsoringValidation] _notifyAdmins error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  int _countEmojis(String text) {
    // Compter les emojis basiques (plages Unicode communes)
    int count = 0;
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      // Plages communes d'emojis
      if ((code >= 0x1F600 && code <= 0x1F64F) || // Emoticons
          (code >= 0x1F300 && code <= 0x1F5FF) || // Misc Symbols
          (code >= 0x1F680 && code <= 0x1F6FF) || // Transport
          (code >= 0x2600 && code <= 0x26FF) || // Misc symbols
          (code >= 0x2700 && code <= 0x27BF) || // Dingbats
          (code >= 0xFE00 && code <= 0xFE0F)) {
        count++;
      }
    }
    return count;
  }
}
