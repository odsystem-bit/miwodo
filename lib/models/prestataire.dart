// models/prestataire.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Prestataire {
  final String id;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final String categorie;
  final String? metier;
  final String zone;
  final String? description;
  final String? photoUrl;
  final List<String> photosPortfolio;
  final double noteMoyenne;
  final int nombreAvis;
  final bool estVerifie;
  final bool estDisponible;
  final bool actif;
  final DateTime creeLe;

  // Champs multi-pays
  final String paysId;
  final String paysNom;
  final String devise;
  final String symbole;
  final String ville;

  // Champs parrainage et publicité
  final bool sponsorise;
  final String? codeParrain; // Code propre du prestataire pour parrainer d'autres
  final String? parrainePar; // Code du parrain qui a parrainé ce prestataire
  final int filleuls;
  final double gainsParrainage;
  final String? planPub;
  final DateTime? pubExpireLe;

  // Champs communs services
  final List<String> joursDisponibles;
  
  // Champs ARTISAN
  final List<String> zonesIntervention;
  final int maxZonesIntervention; // Limite personnalisable par l'admin (défaut: 3)
  final String? anneesExperience;
  final String? specialites;

  // Champs LIBÉRAL
  final String? cabinetNom;
  final String? cabinetAdresse;
  final String? diplome;
  final bool consultationDomicile;
  final int? surcoutDeplacement;
  final List<String> langues;
  final Map<String, List<Map<String, String>>>? plagesHoraires;

  // Champs VENDEUR
  final String? boutiqueNom;
  final String? boutiqueDescription;
  final Map<String, Map<String, String>>? horairesOuverture;
  final String? delaiPreparation;
  final bool livraisonDisponible;
  final List<String> zonesLivraison;
  final bool retraitPlace;
  final String? politiqueRetour;
  final bool charteAcceptee;

  // Champs LIVREUR
  final String? typeEngin;
  final String? capaciteCharge;
  final Map<String, int>? tarifsZones;
  final bool livraisonExpress;
  final int? surcoutExpress;
  final bool disponibleWeekend;
  final bool disponibleNuit;

  Prestataire({
    required this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.email,
    required this.categorie,
    this.metier,
    required this.zone,
    this.paysId = 'TG',
    this.paysNom = 'Togo',
    this.devise = 'XOF',
    this.symbole = 'F CFA',
    this.ville = 'Lomé',
    this.description,
    this.photoUrl,
    this.photosPortfolio = const [],
    this.noteMoyenne = 0.0,
    this.nombreAvis = 0,
    this.estVerifie = false,
    this.estDisponible = true,
    this.actif = true,
    required this.creeLe,
    this.sponsorise = false,
    this.codeParrain,
    this.parrainePar,
    this.filleuls = 0,
    this.gainsParrainage = 0.0,
    this.planPub,
    this.pubExpireLe,
    this.joursDisponibles = const [],
    this.zonesIntervention = const [],
    this.maxZonesIntervention = 3,
    this.anneesExperience,
    this.specialites,
    this.cabinetNom,
    this.cabinetAdresse,
    this.diplome,
    this.consultationDomicile = false,
    this.surcoutDeplacement,
    this.langues = const [],
    this.plagesHoraires,
    this.boutiqueNom,
    this.boutiqueDescription,
    this.horairesOuverture,
    this.delaiPreparation,
    this.livraisonDisponible = false,
    this.zonesLivraison = const [],
    this.retraitPlace = false,
    this.politiqueRetour,
    this.charteAcceptee = false,
    this.typeEngin,
    this.capaciteCharge,
    this.tarifsZones,
    this.livraisonExpress = false,
    this.surcoutExpress,
    this.disponibleWeekend = false,
    this.disponibleNuit = false,
  });

  factory Prestataire.fromJson(Map<String, dynamic> json) {
    return Prestataire(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      telephone: json['telephone'] as String? ?? '',
      email: json['email'] as String?,
      categorie: json['categorie'] as String? ?? 'Artisan',
      paysId: json['pays_id'] as String? ?? 'TG',
      paysNom: json['pays_nom'] as String? ?? 'Togo',
      devise: json['devise'] as String? ?? 'XOF',
      symbole: json['symbole'] as String? ?? 'F CFA',
      ville: json['ville'] as String? ?? 'Lomé',
      metier: json['metier'] as String?,
      zone: json['zone'] as String? ?? '',
      description: json['description'] as String?,
      photoUrl: json['photoUrl'] as String? ?? json['photo_url'] as String?,
      photosPortfolio: List<String>.from(json['photosPortfolio'] ?? json['photos_portfolio'] ?? []),
      noteMoyenne: (json['noteMoyenne'] as num?)?.toDouble() ?? 0.0,
      nombreAvis: (json['nombreAvis'] as num?)?.toInt() ?? 0,
      estVerifie: json['estVerifie'] as bool? ?? false,
      estDisponible: json['estDisponible'] as bool? ?? true,
      actif: json['actif'] as bool? ?? true,
      creeLe: (json['creeLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sponsorise: json['sponsorise'] as bool? ?? false,
      codeParrain: json['codeParrain'] as String?,
      parrainePar: json['parrainePar'] as String?,
      filleuls: (json['filleuls'] as num?)?.toInt() ?? 0,
      gainsParrainage: (json['gainsParrainage'] as num?)?.toDouble() ?? 0.0,
      planPub: json['planPub'] as String?,
      pubExpireLe: json['pubExpireLe'] != null
          ? (json['pubExpireLe'] as Timestamp).toDate()
          : null,
      joursDisponibles: List<String>.from(json['jours_disponibles'] ?? json['joursDisponibles'] ?? []),
      zonesIntervention: List<String>.from(json['zones_intervention'] ?? json['zonesIntervention'] ?? []),
      maxZonesIntervention: (json['max_zones_intervention'] as num?)?.toInt() ?? (json['maxZonesIntervention'] as num?)?.toInt() ?? 3,
      anneesExperience: json['annees_experience'] as String? ?? json['anneesExperience'] as String?,
      specialites: json['specialites'] as String?,
      cabinetNom: json['cabinet_nom'] as String? ?? json['cabinetNom'] as String?,
      cabinetAdresse: json['cabinet_adresse'] as String? ?? json['cabinetAdresse'] as String?,
      diplome: json['diplome'] as String?,
      consultationDomicile: json['consultation_domicile'] as bool? ?? json['consultationDomicile'] as bool? ?? false,
      surcoutDeplacement: (json['surcout_deplacement'] as num?)?.toInt() ?? (json['surcoutDeplacement'] as num?)?.toInt(),
      langues: List<String>.from(json['langues'] ?? []),
      plagesHoraires: _parsePlagesHoraires(json['plages_horaires'] ?? json['plagesHoraires']),
      boutiqueNom: json['boutique_nom'] as String? ?? json['boutiqueNom'] as String?,
      boutiqueDescription: json['boutique_description'] as String? ?? json['boutiqueDescription'] as String?,
      horairesOuverture: _parseHorairesOuverture(json['horaires_ouverture'] ?? json['horairesOuverture']),
      delaiPreparation: json['delai_preparation'] as String? ?? json['delaiPreparation'] as String?,
      livraisonDisponible: json['livraison_disponible'] as bool? ?? json['livraisonDisponible'] as bool? ?? false,
      zonesLivraison: List<String>.from(json['zones_livraison'] ?? json['zonesLivraison'] ?? []),
      retraitPlace: json['retrait_place'] as bool? ?? json['retraitPlace'] as bool? ?? false,
      politiqueRetour: json['politique_retour'] as String? ?? json['politiqueRetour'] as String?,
      charteAcceptee: json['charte_acceptee'] as bool? ?? json['charteAcceptee'] as bool? ?? false,
      typeEngin: json['type_engin'] as String? ?? json['typeEngin'] as String?,
      capaciteCharge: json['capacite_charge'] as String? ?? json['capaciteCharge'] as String?,
      tarifsZones: _parseTarifsZones(json['tarifs_zones'] ?? json['tarifsZones']),
      livraisonExpress: json['livraison_express'] as bool? ?? json['livraisonExpress'] as bool? ?? false,
      surcoutExpress: (json['surcout_express'] as num?)?.toInt() ?? (json['surcoutExpress'] as num?)?.toInt(),
      disponibleWeekend: json['disponible_weekend'] as bool? ?? json['disponibleWeekend'] as bool? ?? false,
      disponibleNuit: json['disponible_nuit'] as bool? ?? json['disponibleNuit'] as bool? ?? false,
    );
  }

  static Map<String, List<Map<String, String>>>? _parsePlagesHoraires(dynamic data) {
    if (data == null) return null;
    final Map<String, List<Map<String, String>>> result = {};
    (data as Map<String, dynamic>).forEach((key, value) {
      result[key] = (value as List).map((e) => Map<String, String>.from(e as Map)).toList();
    });
    return result;
  }

  static Map<String, Map<String, String>>? _parseHorairesOuverture(dynamic data) {
    if (data == null) return null;
    final Map<String, Map<String, String>> result = {};
    (data as Map<String, dynamic>).forEach((key, value) {
      result[key] = Map<String, String>.from(value as Map);
    });
    return result;
  }

  static Map<String, int>? _parseTarifsZones(dynamic data) {
    if (data == null) return null;
    final Map<String, int> result = {};
    (data as Map<String, dynamic>).forEach((key, value) {
      result[key] = (value as num).toInt();
    });
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'categorie': categorie,
      'pays_id': paysId,
      'pays_nom': paysNom,
      'devise': devise,
      'symbole': symbole,
      'ville': ville,
      'metier': metier,
      'zone': zone,
      'description': description,
      'photoUrl': photoUrl,
      'photosPortfolio': photosPortfolio,
      'noteMoyenne': noteMoyenne,
      'nombreAvis': nombreAvis,
      'estVerifie': estVerifie,
      'estDisponible': estDisponible,
      'actif': actif,
      'creeLe': Timestamp.fromDate(creeLe),
      'sponsorise': sponsorise,
      'codeParrain': codeParrain,
      'parrainePar': parrainePar,
      'filleuls': filleuls,
      'gainsParrainage': gainsParrainage,
      'planPub': planPub,
      'pubExpireLe': pubExpireLe != null ? Timestamp.fromDate(pubExpireLe!) : null,
      'jours_disponibles': joursDisponibles,
      'zones_intervention': zonesIntervention,
      'max_zones_intervention': maxZonesIntervention,
      'annees_experience': anneesExperience,
      'specialites': specialites,
      'cabinet_nom': cabinetNom,
      'cabinet_adresse': cabinetAdresse,
      'diplome': diplome,
      'consultation_domicile': consultationDomicile,
      'surcout_deplacement': surcoutDeplacement,
      'langues': langues,
      'plages_horaires': plagesHoraires,
      'boutique_nom': boutiqueNom,
      'boutique_description': boutiqueDescription,
      'horaires_ouverture': horairesOuverture,
      'delai_preparation': delaiPreparation,
      'livraison_disponible': livraisonDisponible,
      'zones_livraison': zonesLivraison,
      'retrait_place': retraitPlace,
      'politique_retour': politiqueRetour,
      'charte_acceptee': charteAcceptee,
      'type_engin': typeEngin,
      'capacite_charge': capaciteCharge,
      'tarifs_zones': tarifsZones,
      'livraison_express': livraisonExpress,
      'surcout_express': surcoutExpress,
      'disponible_weekend': disponibleWeekend,
      'disponible_nuit': disponibleNuit,
    };
  }

  bool get isArtisan => categorie.toLowerCase() == 'artisan';
  bool get isLiberal => categorie.toLowerCase() == 'libéral' || categorie.toLowerCase() == 'liberal';
  bool get isVendeur => categorie.toLowerCase() == 'vendeur';
  bool get isLivreur => categorie.toLowerCase() == 'livreur';
}
