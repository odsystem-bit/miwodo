// models/service_prestataire.dart
// Modèle pour les services proposés par un prestataire

import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePrestataire {
  final String id;
  final String prestataireId;
  final String nom;
  final String? description;
  final int? prixMin;
  final int? prixMax;
  final String? unite; // "par jour", "par heure", "forfait", etc.
  final String? dureeEstimee; // "1-2 heures", "1 journée", etc.
  final List<String> images;
  final bool actif;
  final int ordre;
  final DateTime creeLe;
  final DateTime? modifieLe;

  // Sponsoring au niveau du service
  final bool sponsorise;
  final String? sponsoringPlan; // 'standard' | 'premium'
  final DateTime? sponsoringExpireLe;
  final String? sponsoringCampaignId;

  const ServicePrestataire({
    required this.id,
    required this.prestataireId,
    required this.nom,
    this.description,
    this.prixMin,
    this.prixMax,
    this.unite,
    this.dureeEstimee,
    this.images = const [],
    this.actif = true,
    this.ordre = 0,
    required this.creeLe,
    this.modifieLe,
    this.sponsorise = false,
    this.sponsoringPlan,
    this.sponsoringExpireLe,
    this.sponsoringCampaignId,
  });

  factory ServicePrestataire.fromJson(Map<String, dynamic> json) {
    return ServicePrestataire(
      id: json['id'] as String? ?? '',
      prestataireId: json['prestataireId'] as String? ?? json['prestataire_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      prixMin: (json['prixMin'] as num?)?.toInt(),
      prixMax: (json['prixMax'] as num?)?.toInt(),
      unite: json['unite'] as String?,
      dureeEstimee: json['dureeEstimee'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? (json['photos'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      actif: json['actif'] as bool? ?? true,
      ordre: (json['ordre'] as num?)?.toInt() ?? 0,
      creeLe: (json['creeLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifieLe: (json['modifieLe'] as Timestamp?)?.toDate(),
      sponsorise: json['sponsorise'] as bool? ?? false,
      sponsoringPlan: json['sponsoringPlan'] as String?,
      sponsoringExpireLe: (json['sponsoringExpireLe'] as Timestamp?)?.toDate(),
      sponsoringCampaignId: json['sponsoringCampaignId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'prestataireId': prestataireId,
    'nom': nom,
    'description': description,
    'prixMin': prixMin,
    'prixMax': prixMax,
    'unite': unite,
    'dureeEstimee': dureeEstimee,
    'images': images,
    'actif': actif,
    'ordre': ordre,
    'creeLe': Timestamp.fromDate(creeLe),
    'modifieLe': modifieLe != null ? Timestamp.fromDate(modifieLe!) : null,
    'sponsorise': sponsorise,
    'sponsoringPlan': sponsoringPlan,
    'sponsoringExpireLe': sponsoringExpireLe != null ? Timestamp.fromDate(sponsoringExpireLe!) : null,
    'sponsoringCampaignId': sponsoringCampaignId,
  };

  ServicePrestataire copyWith({
    String? id,
    String? prestataireId,
    String? nom,
    String? description,
    int? prixMin,
    int? prixMax,
    String? unite,
    String? dureeEstimee,
    List<String>? images,
    bool? actif,
    int? ordre,
    DateTime? creeLe,
    DateTime? modifieLe,
    bool? sponsorise,
    String? sponsoringPlan,
    DateTime? sponsoringExpireLe,
    String? sponsoringCampaignId,
  }) {
    return ServicePrestataire(
      id: id ?? this.id,
      prestataireId: prestataireId ?? this.prestataireId,
      nom: nom ?? this.nom,
      description: description ?? this.description,
      prixMin: prixMin ?? this.prixMin,
      prixMax: prixMax ?? this.prixMax,
      unite: unite ?? this.unite,
      dureeEstimee: dureeEstimee ?? this.dureeEstimee,
      images: images ?? this.images,
      actif: actif ?? this.actif,
      ordre: ordre ?? this.ordre,
      creeLe: creeLe ?? this.creeLe,
      modifieLe: modifieLe ?? this.modifieLe,
      sponsorise: sponsorise ?? this.sponsorise,
      sponsoringPlan: sponsoringPlan ?? this.sponsoringPlan,
      sponsoringExpireLe: sponsoringExpireLe ?? this.sponsoringExpireLe,
      sponsoringCampaignId: sponsoringCampaignId ?? this.sponsoringCampaignId,
    );
  }

  String get prixAffiche {
    if (prixMin == null && prixMax == null) return 'Sur devis';
    if (prixMin != null && prixMax != null && prixMin != prixMax) {
      return '${_formatPrix(prixMin!)} - ${_formatPrix(prixMax!)} F${unite != null ? ' $unite' : ''}';
    }
    final prix = prixMin ?? prixMax;
    return '${_formatPrix(prix!)} F${unite != null ? ' $unite' : ''}';
  }

  bool get isSponsoredActive {
    if (!sponsorise) return false;
    if (sponsoringExpireLe == null) return false;
    return DateTime.now().isBefore(sponsoringExpireLe!);
  }

  String _formatPrix(int prix) {
    return prix.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]} ',
    );
  }
}
