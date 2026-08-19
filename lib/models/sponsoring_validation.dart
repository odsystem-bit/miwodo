// models/sponsoring_validation.dart
// Modèles pour la validation automatique intelligente des campagnes de sponsoring

import 'package:cloud_firestore/cloud_firestore.dart';

/// Résultat d'un contrôle individuel
class ValidationCheck {
  final String name;
  final bool passed;
  final String? reason;
  final double weight; // Pondération 0-1

  const ValidationCheck({
    required this.name,
    required this.passed,
    this.reason,
    this.weight = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'passed': passed,
        'reason': reason,
        'weight': weight,
      };

  factory ValidationCheck.fromJson(Map<String, dynamic> json) {
    return ValidationCheck(
      name: json['name'] as String? ?? '',
      passed: json['passed'] as bool? ?? false,
      reason: json['reason'] as String?,
      weight: (json['weight'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Mode de validation
enum ValidationMode {
  automatique, // Validé par l'algorithme
  manuelle, // Validé par un admin
  rejeteAuto, // Rejeté automatiquement
}

extension ValidationModeX on ValidationMode {
  String get label {
    switch (this) {
      case ValidationMode.automatique:
        return 'automatique';
      case ValidationMode.manuelle:
        return 'manuelle';
      case ValidationMode.rejeteAuto:
        return 'rejete_auto';
    }
  }

  String get displayLabel {
    switch (this) {
      case ValidationMode.automatique:
        return 'Automatique';
      case ValidationMode.manuelle:
        return 'Manuelle';
      case ValidationMode.rejeteAuto:
        return 'Rejeté auto';
    }
  }

  static ValidationMode fromString(String? value) {
    switch (value) {
      case 'automatique':
        return ValidationMode.automatique;
      case 'manuelle':
        return ValidationMode.manuelle;
      case 'rejete_auto':
        return ValidationMode.rejeteAuto;
      default:
        return ValidationMode.manuelle;
    }
  }
}

/// Résultat global de la validation
class SponsoringValidationResult {
  final double score; // 0-100
  final List<ValidationCheck> checks;
  final List<String> reasons; // Raisons des échecs
  final ValidationMode mode;
  final bool autoApproved; // true si validé automatiquement
  final DateTime analyseLe;

  const SponsoringValidationResult({
    required this.score,
    required this.checks,
    required this.reasons,
    required this.mode,
    required this.autoApproved,
    required this.analyseLe,
  });

  /// Niveau de confiance basé sur le score
  String get niveauConfiance {
    if (score >= 95) return 'Élevé';
    if (score >= 80) return 'Moyen';
    return 'Faible';
  }

  Map<String, dynamic> toJson() => {
        'score': score,
        'checks': checks.map((c) => c.toJson()).toList(),
        'reasons': reasons,
        'mode': mode.label,
        'autoApproved': autoApproved,
        'analyseLe': Timestamp.fromDate(analyseLe),
      };

  factory SponsoringValidationResult.fromJson(Map<String, dynamic> json) {
    return SponsoringValidationResult(
      score: (json['score'] as num?)?.toDouble() ?? 0,
      checks: (json['checks'] as List<dynamic>?)
              ?.map((c) => ValidationCheck.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      mode: ValidationModeX.fromString(json['mode'] as String?),
      autoApproved: json['autoApproved'] as bool? ?? false,
      analyseLe: (json['analyseLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Journal des décisions de validation
class SponsoringValidationLog {
  final String id;
  final String campaignId;
  final String serviceId;
  final String serviceName;
  final String prestataireId;
  final String prestataireNom;
  final double score;
  final ValidationMode mode;
  final List<ValidationCheck> checks;
  final List<String> reasons;
  final bool autoApproved;
  final DateTime analyseLe;
  final String? adminId; // Si validé manuellement
  final String? adminNote;

  const SponsoringValidationLog({
    required this.id,
    required this.campaignId,
    required this.serviceId,
    required this.serviceName,
    required this.prestataireId,
    required this.prestataireNom,
    required this.score,
    required this.mode,
    required this.checks,
    required this.reasons,
    required this.autoApproved,
    required this.analyseLe,
    this.adminId,
    this.adminNote,
  });

  factory SponsoringValidationLog.fromJson(Map<String, dynamic> json) {
    return SponsoringValidationLog(
      id: json['id'] as String? ?? '',
      campaignId: json['campaignId'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      prestataireId: json['prestataireId'] as String? ?? '',
      prestataireNom: json['prestataireNom'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      mode: ValidationModeX.fromString(json['mode'] as String?),
      checks: (json['checks'] as List<dynamic>?)
              ?.map((c) => ValidationCheck.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      reasons: (json['reasons'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      autoApproved: json['autoApproved'] as bool? ?? false,
      analyseLe: (json['analyseLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
      adminId: json['adminId'] as String?,
      adminNote: json['adminNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'campaignId': campaignId,
        'serviceId': serviceId,
        'serviceName': serviceName,
        'prestataireId': prestataireId,
        'prestataireNom': prestataireNom,
        'score': score,
        'mode': mode.label,
        'checks': checks.map((c) => c.toJson()).toList(),
        'reasons': reasons,
        'autoApproved': autoApproved,
        'analyseLe': Timestamp.fromDate(analyseLe),
        'adminId': adminId,
        'adminNote': adminNote,
      };
}

/// Paramètres de validation automatique (stockés dans config/sponsoring_settings)
class SponsoringSettings {
  final bool autoValidationActive;
  final double seuilConfianceAuto; // Ex: 95.0 — au-dessus = validation auto
  final double seuilJournalisation; // Ex: 80.0 — entre seuilJournalisation et seuilConfianceAuto = auto + log
  final List<String> motsInterdits;
  final List<String> motsSuspects;
  final int maxEmojisAutorises;
  final int maxCaracteresRepetition;
  final DateTime modifieLe;

  const SponsoringSettings({
    this.autoValidationActive = true,
    this.seuilConfianceAuto = 95.0,
    this.seuilJournalisation = 80.0,
    this.motsInterdits = defaultForbiddenWords,
    this.motsSuspects = defaultSuspiciousWords,
    this.maxEmojisAutorises = 5,
    this.maxCaracteresRepetition = 4,
    required this.modifieLe,
  });

  static const List<String> defaultForbiddenWords = [
    'arnaque', 'escroquerie', 'fraude', 'illégal', 'drogue', 'armes', 'munition',
    'porno', 'sexe', 'escort', 'prostitution', 'casino', 'pari', 'jeu d\'argent',
    'haine', 'raciste', 'discrimination', 'terrorisme', 'violence', 'tuer',
    'arme à feu', 'munition', 'explosif', 'blanchiment', 'contrebande',
    'trafic', 'corruption', 'extorsion', 'faux billets', 'faux documents',
    'faux passeport', 'faux diplôme', 'faux certificat', 'faux ordonnance',
  ];

  static const List<String> defaultSuspiciousWords = [
    'gratuit', 'gagnez', 'cliquez ici', 'offre limitée', 'urgent', '100%',
    'garanti', 'aucun risque', 'investissement', 'crypto', 'bitcoin',
    'prêt rapide', 'crédit facile', 'sans condition', 'richesse rapide',
    'argent facile', 'devenez riche', 'travail à domicile',
  ];

  factory SponsoringSettings.fromJson(Map<String, dynamic> json) {
    return SponsoringSettings(
      autoValidationActive: json['autoValidationActive'] as bool? ?? true,
      seuilConfianceAuto: (json['seuilConfianceAuto'] as num?)?.toDouble() ?? 95.0,
      seuilJournalisation: (json['seuilJournalisation'] as num?)?.toDouble() ?? 80.0,
      motsInterdits: (json['motsInterdits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaultForbiddenWords,
      motsSuspects: (json['motsSuspects'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          defaultSuspiciousWords,
      maxEmojisAutorises: (json['maxEmojisAutorises'] as num?)?.toInt() ?? 5,
      maxCaracteresRepetition: (json['maxCaracteresRepetition'] as num?)?.toInt() ?? 4,
      modifieLe: (json['modifieLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'autoValidationActive': autoValidationActive,
        'seuilConfianceAuto': seuilConfianceAuto,
        'seuilJournalisation': seuilJournalisation,
        'motsInterdits': motsInterdits,
        'motsSuspects': motsSuspects,
        'maxEmojisAutorises': maxEmojisAutorises,
        'maxCaracteresRepetition': maxCaracteresRepetition,
        'modifieLe': Timestamp.fromDate(modifieLe),
      };

  SponsoringSettings copyWith({
    bool? autoValidationActive,
    double? seuilConfianceAuto,
    double? seuilJournalisation,
    List<String>? motsInterdits,
    List<String>? motsSuspects,
    int? maxEmojisAutorises,
    int? maxCaracteresRepetition,
    DateTime? modifieLe,
  }) {
    return SponsoringSettings(
      autoValidationActive: autoValidationActive ?? this.autoValidationActive,
      seuilConfianceAuto: seuilConfianceAuto ?? this.seuilConfianceAuto,
      seuilJournalisation: seuilJournalisation ?? this.seuilJournalisation,
      motsInterdits: motsInterdits ?? this.motsInterdits,
      motsSuspects: motsSuspects ?? this.motsSuspects,
      maxEmojisAutorises: maxEmojisAutorises ?? this.maxEmojisAutorises,
      maxCaracteresRepetition: maxCaracteresRepetition ?? this.maxCaracteresRepetition,
      modifieLe: modifieLe ?? this.modifieLe,
    );
  }
}
