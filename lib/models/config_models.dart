// models/config_models.dart
// Modèles pour la configuration dynamique Firestore

class ConfigVille {
  final String id;
  final String nom;
  final String pays;
  final bool actif;
  final int ordre;

  const ConfigVille({
    required this.id,
    required this.nom,
    required this.pays,
    required this.actif,
    required this.ordre,
  });

  factory ConfigVille.fromJson(Map<String, dynamic> json) {
    return ConfigVille(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      pays: json['pays'] as String? ?? 'Togo',
      actif: json['actif'] as bool? ?? true,
      ordre: json['ordre'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'pays': pays,
    'actif': actif,
    'ordre': ordre,
  };

  ConfigVille copyWith({
    String? id,
    String? nom,
    String? pays,
    bool? actif,
    int? ordre,
  }) {
    return ConfigVille(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      pays: pays ?? this.pays,
      actif: actif ?? this.actif,
      ordre: ordre ?? this.ordre,
    );
  }
}

class ConfigZone {
  final String id;
  final String nom;
  final String villeId;
  final bool actif;
  final int ordre;

  const ConfigZone({
    required this.id,
    required this.nom,
    required this.villeId,
    required this.actif,
    required this.ordre,
  });

  factory ConfigZone.fromJson(Map<String, dynamic> json) {
    return ConfigZone(
      id: json['id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      villeId: json['ville_id'] as String? ?? 'lome',
      actif: json['actif'] as bool? ?? true,
      ordre: json['ordre'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nom': nom,
    'ville_id': villeId,
    'actif': actif,
    'ordre': ordre,
  };

  ConfigZone copyWith({
    String? id,
    String? nom,
    String? villeId,
    bool? actif,
    int? ordre,
  }) {
    return ConfigZone(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      villeId: villeId ?? this.villeId,
      actif: actif ?? this.actif,
      ordre: ordre ?? this.ordre,
    );
  }
}

class ConfigCategorie {
  final String id;
  final String label;
  final String labelPlural;
  final String iconeSvg;
  final bool actif;
  final int ordre;
  final List<String> sousCategories;

  const ConfigCategorie({
    required this.id,
    required this.label,
    required this.labelPlural,
    required this.iconeSvg,
    required this.actif,
    required this.ordre,
    required this.sousCategories,
  });

  factory ConfigCategorie.fromJson(Map<String, dynamic> json) {
    return ConfigCategorie(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      labelPlural: json['label_plural'] as String? ?? '',
      iconeSvg: json['icone_svg'] as String? ?? 'ic_work.svg',
      actif: json['actif'] as bool? ?? true,
      ordre: json['ordre'] as int? ?? 0,
      sousCategories: (json['sous_categories'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'label_plural': labelPlural,
    'icone_svg': iconeSvg,
    'actif': actif,
    'ordre': ordre,
    'sous_categories': sousCategories,
  };

  ConfigCategorie copyWith({
    String? id,
    String? label,
    String? labelPlural,
    String? iconeSvg,
    bool? actif,
    int? ordre,
    List<String>? sousCategories,
  }) {
    return ConfigCategorie(
      id: id ?? this.id,
      label: label ?? this.label,
      labelPlural: labelPlural ?? this.labelPlural,
      iconeSvg: iconeSvg ?? this.iconeSvg,
      actif: actif ?? this.actif,
      ordre: ordre ?? this.ordre,
      sousCategories: sousCategories ?? this.sousCategories,
    );
  }
}

class ConfigTarifs {
  final int inscriptionPrestataire;
  final int pubStandardMensuel;
  final int pubPremiumMensuel;
  final int gainParrainage;
  final double commissionCommandePct;

  const ConfigTarifs({
    required this.inscriptionPrestataire,
    required this.pubStandardMensuel,
    required this.pubPremiumMensuel,
    required this.gainParrainage,
    required this.commissionCommandePct,
  });

  factory ConfigTarifs.fromJson(Map<String, dynamic> json) {
    return ConfigTarifs(
      inscriptionPrestataire: json['inscription_prestataire'] as int? ?? 500,
      pubStandardMensuel: json['pub_standard_mensuel'] as int? ?? 2000,
      pubPremiumMensuel: json['pub_premium_mensuel'] as int? ?? 5000,
      gainParrainage: json['gain_parrainage'] as int? ?? 100,
      commissionCommandePct: (json['commission_commande_pct'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'inscription_prestataire': inscriptionPrestataire,
    'pub_standard_mensuel': pubStandardMensuel,
    'pub_premium_mensuel': pubPremiumMensuel,
    'gain_parrainage': gainParrainage,
    'commission_commande_pct': commissionCommandePct,
  };

  static const ConfigTarifs defaults = ConfigTarifs(
    inscriptionPrestataire: 500,
    pubStandardMensuel: 2000,
    pubPremiumMensuel: 5000,
    gainParrainage: 100,
    commissionCommandePct: 0.0,
  );
}

class ConfigApp {
  final String nomApp;
  final String slogan;
  final String emailSupport;
  final String telephoneSupport;
  final String whatsappSupport;
  final String urlSite;
  final String urlCgu;
  final String urlConfidentialite;
  final bool maintenanceMode;
  final String messageMaintenance;
  final String versionMinimaleRequise;
  final String messageAccueil;
  final bool banniereActive;
  final String texteBanniere;

  const ConfigApp({
    required this.nomApp,
    required this.slogan,
    required this.emailSupport,
    required this.telephoneSupport,
    required this.whatsappSupport,
    required this.urlSite,
    required this.urlCgu,
    required this.urlConfidentialite,
    required this.maintenanceMode,
    required this.messageMaintenance,
    required this.versionMinimaleRequise,
    required this.messageAccueil,
    required this.banniereActive,
    required this.texteBanniere,
  });

  factory ConfigApp.fromJson(Map<String, dynamic> json) {
    return ConfigApp(
      nomApp: json['nom_app'] as String? ?? 'Miwodo',
      slogan: json['slogan'] as String? ?? 'Trouvez le bon prestataire',
      emailSupport: json['email_support'] as String? ?? 'support@miwodo.tg',
      telephoneSupport: json['telephone_support'] as String? ?? '',
      whatsappSupport: json['whatsapp_support'] as String? ?? '',
      urlSite: json['url_site'] as String? ?? 'https://miwodo.tg',
      urlCgu: json['url_cgu'] as String? ?? 'https://miwodo.tg/cgu',
      urlConfidentialite: json['url_confidentialite'] as String? ?? 'https://miwodo.tg/confidentialite',
      maintenanceMode: json['maintenance_mode'] as bool? ?? false,
      messageMaintenance: json['message_maintenance'] as String? ?? 'Miwodo est en maintenance. Revenez bientôt !',
      versionMinimaleRequise: json['version_minimale_requise'] as String? ?? '1.0.0',
      messageAccueil: json['message_accueil'] as String? ?? 'Bienvenue sur Miwodo !',
      banniereActive: json['banniere_active'] as bool? ?? false,
      texteBanniere: json['texte_banniere'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'nom_app': nomApp,
    'slogan': slogan,
    'email_support': emailSupport,
    'telephone_support': telephoneSupport,
    'whatsapp_support': whatsappSupport,
    'url_site': urlSite,
    'url_cgu': urlCgu,
    'url_confidentialite': urlConfidentialite,
    'maintenance_mode': maintenanceMode,
    'message_maintenance': messageMaintenance,
    'version_minimale_requise': versionMinimaleRequise,
    'message_accueil': messageAccueil,
    'banniere_active': banniereActive,
    'texte_banniere': texteBanniere,
  };

  static const ConfigApp defaults = ConfigApp(
    nomApp: 'Miwodo',
    slogan: 'Trouvez le bon prestataire',
    emailSupport: 'support@miwodo.tg',
    telephoneSupport: '',
    whatsappSupport: '',
    urlSite: 'https://miwodo.tg',
    urlCgu: 'https://miwodo.tg/cgu',
    urlConfidentialite: 'https://miwodo.tg/confidentialite',
    maintenanceMode: false,
    messageMaintenance: 'Miwodo est en maintenance. Revenez bientôt !',
    versionMinimaleRequise: '1.0.0',
    messageAccueil: 'Bienvenue sur Miwodo !',
    banniereActive: false,
    texteBanniere: '',
  );
}

class ConfigNotifications {
  final bool notifNouvelleCommande;
  final bool notifNouveauMessage;
  final bool notifAvisRecu;
  final bool notifPubExpiree;
  final bool notifInscriptionFilleul;
  final String texteNotifInscription;
  final String texteNotifCommande;

  const ConfigNotifications({
    required this.notifNouvelleCommande,
    required this.notifNouveauMessage,
    required this.notifAvisRecu,
    required this.notifPubExpiree,
    required this.notifInscriptionFilleul,
    required this.texteNotifInscription,
    required this.texteNotifCommande,
  });

  factory ConfigNotifications.fromJson(Map<String, dynamic> json) {
    return ConfigNotifications(
      notifNouvelleCommande: json['notif_nouvelle_commande'] as bool? ?? true,
      notifNouveauMessage: json['notif_nouveau_message'] as bool? ?? true,
      notifAvisRecu: json['notif_avis_recu'] as bool? ?? true,
      notifPubExpiree: json['notif_pub_expiree'] as bool? ?? true,
      notifInscriptionFilleul: json['notif_inscription_filleul'] as bool? ?? true,
      texteNotifInscription: json['texte_notif_inscription'] as String? ?? 'Bienvenue sur Miwodo !',
      texteNotifCommande: json['texte_notif_commande'] as String? ?? 'Nouvelle commande reçue !',
    );
  }

  Map<String, dynamic> toJson() => {
    'notif_nouvelle_commande': notifNouvelleCommande,
    'notif_nouveau_message': notifNouveauMessage,
    'notif_avis_recu': notifAvisRecu,
    'notif_pub_expiree': notifPubExpiree,
    'notif_inscription_filleul': notifInscriptionFilleul,
    'texte_notif_inscription': texteNotifInscription,
    'texte_notif_commande': texteNotifCommande,
  };

  static const ConfigNotifications defaults = ConfigNotifications(
    notifNouvelleCommande: true,
    notifNouveauMessage: true,
    notifAvisRecu: true,
    notifPubExpiree: true,
    notifInscriptionFilleul: true,
    texteNotifInscription: 'Bienvenue sur Miwodo !',
    texteNotifCommande: 'Nouvelle commande reçue !',
  );
}

class ConfigSponsoring {
  final int dureeStandardJours;
  final int dureePremiumJours;
  final int nbMaxSponsorisesAccueil;
  final bool rotationSponsorises;
  final bool gratuitPremierMois;
  final String texteBadgeStandard;
  final String texteBadgePremium;
  final String couleurBadgePremium;

  const ConfigSponsoring({
    required this.dureeStandardJours,
    required this.dureePremiumJours,
    required this.nbMaxSponsorisesAccueil,
    required this.rotationSponsorises,
    required this.gratuitPremierMois,
    required this.texteBadgeStandard,
    required this.texteBadgePremium,
    required this.couleurBadgePremium,
  });

  factory ConfigSponsoring.fromJson(Map<String, dynamic> json) {
    return ConfigSponsoring(
      dureeStandardJours: json['duree_standard_jours'] as int? ?? 30,
      dureePremiumJours: json['duree_premium_jours'] as int? ?? 30,
      nbMaxSponsorisesAccueil: json['nb_max_sponsorises_accueil'] as int? ?? 10,
      rotationSponsorises: json['rotation_sponsorises'] as bool? ?? true,
      gratuitPremierMois: json['gratuit_premier_mois'] as bool? ?? false,
      texteBadgeStandard: json['texte_badge_standard'] as String? ?? 'SPONSORISÉ',
      texteBadgePremium: json['texte_badge_premium'] as String? ?? '⭐ PREMIUM',
      couleurBadgePremium: json['couleur_badge_premium'] as String? ?? '#F97316',
    );
  }

  Map<String, dynamic> toJson() => {
    'duree_standard_jours': dureeStandardJours,
    'duree_premium_jours': dureePremiumJours,
    'nb_max_sponsorises_accueil': nbMaxSponsorisesAccueil,
    'rotation_sponsorises': rotationSponsorises,
    'gratuit_premier_mois': gratuitPremierMois,
    'texte_badge_standard': texteBadgeStandard,
    'texte_badge_premium': texteBadgePremium,
    'couleur_badge_premium': couleurBadgePremium,
  };

  static const ConfigSponsoring defaults = ConfigSponsoring(
    dureeStandardJours: 30,
    dureePremiumJours: 30,
    nbMaxSponsorisesAccueil: 10,
    rotationSponsorises: true,
    gratuitPremierMois: false,
    texteBadgeStandard: 'SPONSORISÉ',
    texteBadgePremium: '⭐ PREMIUM',
    couleurBadgePremium: '#F97316',
  );
}
