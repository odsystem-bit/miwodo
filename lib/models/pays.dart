// models/pays.dart
// Modèle Pays pour la configuration multi-pays Miwodo

class Pays {
  final String id;           // ISO "TG", "CI", "FR"...
  final String nom;
  final String drapeauEmoji;
  final String region;       // "afrique_ouest", "europe", "amerique"...
  final bool actif;
  final String devise;       // "XOF", "XAF", "EUR", "CAD"
  final String symbole;      // "F CFA", "€", "CA$"
  final num inscriptionMontant;
  final num gainParrainage;
  final num commissionFixeCommande;
  final num pubStandardMontant;
  final num pubPremiumMontant;
  final num retraitMinimum;
  final List<String> monerooMethods;
  final List<String> villesActives;
  final int ordre;

  const Pays({
    required this.id,
    required this.nom,
    required this.drapeauEmoji,
    required this.region,
    required this.actif,
    required this.devise,
    required this.symbole,
    required this.inscriptionMontant,
    required this.gainParrainage,
    required this.commissionFixeCommande,
    required this.pubStandardMontant,
    required this.pubPremiumMontant,
    required this.retraitMinimum,
    required this.monerooMethods,
    required this.villesActives,
    required this.ordre,
  });

  factory Pays.fromJson(Map<String, dynamic> json) {
    return Pays(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      drapeauEmoji: json['drapeau_emoji'] as String? ?? '',
      region: json['region'] as String? ?? 'afrique_ouest',
      actif: json['actif'] as bool? ?? false,
      devise: json['devise'] as String? ?? 'XOF',
      symbole: json['symbole'] as String? ?? 'F CFA',
      inscriptionMontant: json['inscription_montant'] as num? ?? 500,
      gainParrainage: (json['gain_parrainage_devise'] as num?) ?? (json['gain_parrainage'] as num?) ?? 100,
      commissionFixeCommande: json['commission_fixe_commande'] as num? ?? 0,
      pubStandardMontant: json['pub_standard_montant'] as num? ?? 2000,
      pubPremiumMontant: json['pub_premium_montant'] as num? ?? 5000,
      retraitMinimum: json['retrait_minimum'] as num? ?? 500,
      monerooMethods: List<String>.from(json['moneroo_methods'] as List? ?? ['moov_tg']),
      villesActives: List<String>.from(json['villes_actives'] as List? ?? []),
      ordre: json['ordre'] as int? ?? 99,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'drapeau_emoji': drapeauEmoji,
    'region': region,
    'actif': actif,
    'devise': devise,
    'symbole': symbole,
    'inscription_montant': inscriptionMontant,
    'gain_parrainage': gainParrainage,
    'commission_fixe_commande': commissionFixeCommande,
    'pub_standard_montant': pubStandardMontant,
    'pub_premium_montant': pubPremiumMontant,
    'retrait_minimum': retraitMinimum,
    'moneroo_methods': monerooMethods,
    'villes_actives': villesActives,
    'ordre': ordre,
  };

  Pays copyWith({
    String? id, String? nom, String? drapeauEmoji, String? region,
    bool? actif, String? devise, String? symbole,
    num? inscriptionMontant, num? gainParrainage, num? commissionFixeCommande,
    num? pubStandardMontant, num? pubPremiumMontant, num? retraitMinimum,
    List<String>? monerooMethods, List<String>? villesActives, int? ordre,
  }) {
    return Pays(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      drapeauEmoji: drapeauEmoji ?? this.drapeauEmoji,
      region: region ?? this.region,
      actif: actif ?? this.actif,
      devise: devise ?? this.devise,
      symbole: symbole ?? this.symbole,
      inscriptionMontant: inscriptionMontant ?? this.inscriptionMontant,
      gainParrainage: gainParrainage ?? this.gainParrainage,
      commissionFixeCommande: commissionFixeCommande ?? this.commissionFixeCommande,
      pubStandardMontant: pubStandardMontant ?? this.pubStandardMontant,
      pubPremiumMontant: pubPremiumMontant ?? this.pubPremiumMontant,
      retraitMinimum: retraitMinimum ?? this.retraitMinimum,
      monerooMethods: monerooMethods ?? this.monerooMethods,
      villesActives: villesActives ?? this.villesActives,
      ordre: ordre ?? this.ordre,
    );
  }

  bool get isEurope => region == 'europe';
  bool get isAmerique => region == 'amerique';
  bool get isAfrique => region.startsWith('afrique');
  bool get usesCard => monerooMethods.contains('card');

  String get regionLabel {
    switch (region) {
      case 'afrique_ouest': return 'Afrique de l\'Ouest';
      case 'afrique_centrale': return 'Afrique Centrale';
      case 'afrique_est': return 'Afrique de l\'Est';
      case 'europe': return 'Europe';
      case 'amerique': return 'Amériques';
      default: return region;
    }
  }

  // Pays par défaut (Togo) utilisé comme fallback
  static const Pays togo = Pays(
    id: 'TG',
    nom: 'Togo',
    drapeauEmoji: '🇹🇬',
    region: 'afrique_ouest',
    actif: true,
    devise: 'XOF',
    symbole: 'F CFA',
    inscriptionMontant: 500,
    gainParrainage: 100,
    commissionFixeCommande: 100,
    pubStandardMontant: 2000,
    pubPremiumMontant: 5000,
    retraitMinimum: 500,
    monerooMethods: ['moov_tg', 'togocel'],
    villesActives: ['lome'],
    ordre: 1,
  );
}

// Libellés lisibles pour les méthodes de paiement Moneroo (shortcodes officiels API)
const Map<String, String> monerooMethodLabels = {
  // Togo
  'moov_tg': 'Moov Money (Togo)',
  'togocel': 'Togocel Money',
  // Côte d'Ivoire
  'orange_ci': 'Orange Money (Côte d\'Ivoire)',
  'mtn_ci': 'MTN MoMo (Côte d\'Ivoire)',
  'moov_ci': 'Moov Money (Côte d\'Ivoire)',
  'wave_ci': 'Wave (Côte d\'Ivoire)',
  // Sénégal
  'orange_sn': 'Orange Money (Sénégal)',
  'wave_sn': 'Wave (Sénégal)',
  'freemoney_sn': 'Free Money (Sénégal)',
  'e_money_sn': 'E-Money (Sénégal)',
  'wizall_sn': 'Wizall (Sénégal)',
  // Bénin
  'mtn_bj': 'MTN MoMo (Bénin)',
  'moov_bj': 'Moov Money (Bénin)',
  // Ghana
  'mtn_gh': 'MTN MoMo (Ghana)',
  'tigo_gh': 'Airtel/Tigo Money (Ghana)',
  'vodafone_gh': 'Vodafone Cash (Ghana)',
  // Nigeria
  'airtel_ng': 'Airtel Money (Nigeria)',
  'bank_transfer_ng': 'Virement bancaire (Nigeria)',
  'ussd_ngn': 'USSD (Nigeria)',
  // Mali
  'orange_ml': 'Orange Money (Mali)',
  'moov_ml': 'Moov Money (Mali)',
  'mobi_cash_ml': 'Mobi Cash (Mali)',
  // Burkina Faso
  'orange_bf': 'Orange Money (Burkina Faso)',
  'moov_bf': 'Moov Money (Burkina Faso)',
  // Niger
  'airtel_ne': 'Airtel Money (Niger)',
  // Guinée
  'orange_gn': 'Orange Money (Guinée)',
  'mtn_gn': 'MTN MoMo (Guinée)',
  // Cameroun
  'mtn_cm': 'MTN MoMo (Cameroun)',
  'orange_cm': 'Orange Money (Cameroun)',
  'eu_mobile_cm': 'EU Mobile Money (Cameroun)',
  // RDC
  'airtel_cd': 'Airtel Money (RDC)',
  'orange_cd': 'Orange Money (RDC)',
  'vodacom_cd': 'Vodacom (RDC)',
  // Kenya
  'mpesa_ke': 'M-Pesa (Kenya)',
  // Ouganda
  'mtn_ug': 'MTN MoMo (Ouganda)',
  'airtel_ug': 'Airtel Money (Ouganda)',
  // Tanzanie
  'mpesa_tz': 'Vodacom M-Pesa (Tanzanie)',
  'tigo_tz': 'Tigo (Tanzanie)',
  'halopesa_tz': 'Halopesa (Tanzanie)',

  // Cartes bancaires (Moneroo)
  'card_eur': 'Carte bancaire (EUR)',
  'card_usd': 'Carte bancaire (USD)',
  'card_cad': 'Carte bancaire (CAD)',

  // Crypto (Moneroo)
  'crypto_eur': 'Crypto (EUR)',
  'crypto_usd': 'Crypto (USD)',
  'crypto_xof': 'Crypto (XOF)',
  'crypto_xaf': 'Crypto (XAF)',
  'crypto_ghs': 'Crypto (GHS)',
  'crypto_ngn': 'Crypto (NGN)',
};

// Indicatifs téléphoniques par pays
const Map<String, String> paysIndicatifs = {
  'TG': '+228',
  'CI': '+225',
  'SN': '+221',
  'BJ': '+229',
  'GH': '+233',
  'NG': '+234',
  'ML': '+223',
  'BF': '+226',
  'NE': '+227',
  'GN': '+224',
  'CM': '+237',
  'GA': '+241',
  'CD': '+243',
  'KE': '+254',
  'UG': '+256',
  'TZ': '+255',
  'FR': '+33',
  'BE': '+32',
  'CA': '+1',
  'US': '+1',
};
