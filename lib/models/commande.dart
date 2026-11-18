import 'package:cloud_firestore/cloud_firestore.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS
// ═══════════════════════════════════════════════════════════════════════════

enum StatutCommande {
  paye,           // Après paiement Moneroo OK
  accepte,        // Livreur a accepté la course
  enRoute,        // Livreur a pris la commande
  livre,          // Livreur arrivé chez client
  confirme,       // Les 2 ont confirmé → escrow libéré
  forceConfirme,  // Forcé par livreur + photo
  litige,         // Admin doit intervenir
  rembourse;      // Annulé/remboursé

  String get label {
    switch (this) {
      case StatutCommande.paye:
        return 'Payée';
      case StatutCommande.accepte:
        return 'Acceptée';
      case StatutCommande.enRoute:
        return 'En route';
      case StatutCommande.livre:
        return 'Livrée';
      case StatutCommande.confirme:
        return 'Confirmée';
      case StatutCommande.forceConfirme:
        return 'Confirmée (forcé)';
      case StatutCommande.litige:
        return 'En litige';
      case StatutCommande.rembourse:
        return 'Remboursée';
    }
  }

  String get icon {
    switch (this) {
      case StatutCommande.paye:
        return 'ic_credit_card.svg';
      case StatutCommande.accepte:
        return 'ic_check.svg';
      case StatutCommande.enRoute:
        return 'ic_truck.svg';
      case StatutCommande.livre:
        return 'ic_package.svg';
      case StatutCommande.confirme:
        return 'ic_check_circle.svg';
      case StatutCommande.forceConfirme:
        return 'ic_camera.svg';
      case StatutCommande.litige:
        return 'ic_alert_triangle.svg';
      case StatutCommande.rembourse:
        return 'ic_refresh.svg';
    }
  }
}

enum EscrowStatut {
  enAttente,  // Argent bloqué chez Miwodo
  libere,     // Confirmé → crédité au vendeur
  rembourse,  // Litige → remboursé au client
  force;      // Forcé par livreur avec photo preuve

  String get label {
    switch (this) {
      case EscrowStatut.enAttente:
        return 'En attente';
      case EscrowStatut.libere:
        return 'Libéré';
      case EscrowStatut.rembourse:
        return 'Remboursé';
      case EscrowStatut.force:
        return 'Forcé';
    }
  }
}

enum ClientType {
  inscrit,
  invite;
}

// ═══════════════════════════════════════════════════════════════════════════
// ARTICLE COMMANDE
// ═══════════════════════════════════════════════════════════════════════════

class ArticleCommande {
  final String produitId;
  final String nom;
  final int prixUnitaire;
  final int quantite;
  final int sousTotal;
  final String? imageUrl;

  ArticleCommande({
    required this.produitId,
    required this.nom,
    required this.prixUnitaire,
    required this.quantite,
    required this.sousTotal,
    this.imageUrl,
  });

  factory ArticleCommande.fromJson(Map<String, dynamic> json) {
    return ArticleCommande(
      produitId: json['produit_id'] as String? ?? json['produitId'] as String,
      nom: json['nom'] as String,
      prixUnitaire: (json['prix_unitaire'] as num?)?.toInt() ?? (json['prixUnitaire'] as num).toInt(),
      quantite: (json['quantite'] as num).toInt(),
      sousTotal: (json['sous_total'] as num?)?.toInt() ?? (json['sousTotal'] as num).toInt(),
      imageUrl: json['image_url'] as String? ?? json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'produit_id': produitId,
    'nom': nom,
    'prix_unitaire': prixUnitaire,
    'quantite': quantite,
    'sous_total': sousTotal,
    'image_url': imageUrl,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// COMMANDE VENDEUR COMPLÈTE
// ═══════════════════════════════════════════════════════════════════════════

class CommandeVendeur {
  // IDENTIFICATION
  final String id;
  final String numero;  // "MW-2024-0001"
  final DateTime createdAt;

  // CLIENT
  final ClientType clientType;
  final String? clientUid;
  final String clientNom;
  final String clientTelephone;
  final String clientZone;
  final String clientAdresseTexte;
  final GeoPoint? clientCoords;

  // VENDEUR
  final String vendeurId;
  final String vendeurNom;
  final String? vendeurTelephone;
  final String? vendeurBoutiqueNom;

  // LIVREUR
  final String livreurId;
  final String livreurNom;
  final String livreurTelephone;
  final int livreurTarifZone;
  final String? livreurTypeEngin;

  // ARTICLES
  final List<ArticleCommande> articles;

  // MONTANTS
  final int sousTotalArticles;
  final int fraisLivraison;
  final int commissionMiwodo;
  final int totalClient;
  final int montantVendeur;

  // ESCROW
  final EscrowStatut escrowStatut;
  final String? monerooPaymentId;
  final DateTime? escrowLibereAt;

  // CONFIRMATION DOUBLE
  final bool confirmationClient;
  final bool confirmationLivreur;
  final DateTime? confirmationClientAt;
  final DateTime? confirmationLivreurAt;
  final String? photoPreuveUrl;
  final bool forceParLivreur;
  final String? forceRaison;

  // STATUT GLOBAL
  final StatutCommande statut;

  // DÉLAIS
  final int delaiConfirmationHeures;
  final DateTime? expirationConfirmationAt;

  // LITIGE
  final String? litigeDescription;
  final String? litigeNoteAdmin;
  final DateTime? litigeCreatedAt;

  CommandeVendeur({
    required this.id,
    required this.numero,
    required this.createdAt,
    required this.clientType,
    this.clientUid,
    required this.clientNom,
    required this.clientTelephone,
    required this.clientZone,
    required this.clientAdresseTexte,
    this.clientCoords,
    required this.vendeurId,
    required this.vendeurNom,
    this.vendeurTelephone,
    this.vendeurBoutiqueNom,
    required this.livreurId,
    required this.livreurNom,
    required this.livreurTelephone,
    required this.livreurTarifZone,
    this.livreurTypeEngin,
    required this.articles,
    required this.sousTotalArticles,
    required this.fraisLivraison,
    required this.commissionMiwodo,
    required this.totalClient,
    required this.montantVendeur,
    this.escrowStatut = EscrowStatut.enAttente,
    this.monerooPaymentId,
    this.escrowLibereAt,
    this.confirmationClient = false,
    this.confirmationLivreur = false,
    this.confirmationClientAt,
    this.confirmationLivreurAt,
    this.photoPreuveUrl,
    this.forceParLivreur = false,
    this.forceRaison,
    this.statut = StatutCommande.paye,
    this.delaiConfirmationHeures = 24,
    this.expirationConfirmationAt,
    this.litigeDescription,
    this.litigeNoteAdmin,
    this.litigeCreatedAt,
  });

  // Helpers
  bool get estConfirme => confirmationClient && confirmationLivreur;
  bool get estEnLitige => statut == StatutCommande.litige;
  bool get peutEtreForce => statut == StatutCommande.livre && !confirmationClient;
  
  Duration get tempsRestantConfirmation {
    if (expirationConfirmationAt == null) return Duration.zero;
    final diff = expirationConfirmationAt!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get confirmationExpiree => tempsRestantConfirmation == Duration.zero && statut == StatutCommande.livre;

  factory CommandeVendeur.fromJson(Map<String, dynamic> json, String docId) {
    return CommandeVendeur(
      id: docId,
      numero: json['numero'] as String? ?? 'MW-????-????',
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      clientType: json['client_type'] == 'invite' ? ClientType.invite : ClientType.inscrit,
      clientUid: json['client_uid'] as String?,
      clientNom: json['client_nom'] as String? ?? '',
      clientTelephone: json['client_telephone'] as String? ?? '',
      clientZone: json['client_zone'] as String? ?? '',
      clientAdresseTexte: json['client_adresse_texte'] as String? ?? '',
      clientCoords: json['client_coords'] as GeoPoint?,
      vendeurId: json['vendeur_id'] as String? ?? '',
      vendeurNom: json['vendeur_nom'] as String? ?? '',
      vendeurTelephone: json['vendeur_telephone'] as String?,
      vendeurBoutiqueNom: json['vendeur_boutique_nom'] as String?,
      livreurId: json['livreur_id'] as String? ?? '',
      livreurNom: json['livreur_nom'] as String? ?? '',
      livreurTelephone: json['livreur_telephone'] as String? ?? '',
      livreurTarifZone: (json['livreur_tarif_zone'] as num?)?.toInt() ?? 0,
      livreurTypeEngin: json['livreur_type_engin'] as String?,
      articles: (json['articles'] as List<dynamic>?)
          ?.map((e) => ArticleCommande.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      sousTotalArticles: (json['sous_total_articles'] as num?)?.toInt() ?? 0,
      fraisLivraison: (json['frais_livraison'] as num?)?.toInt() ?? 0,
      commissionMiwodo: (json['commission_miwodo'] as num?)?.toInt() ?? 0,
      totalClient: (json['total_client'] as num?)?.toInt() ?? 0,
      montantVendeur: (json['montant_vendeur'] as num?)?.toInt() ?? 0,
      escrowStatut: EscrowStatut.values.firstWhere(
        (e) => e.name == json['escrow_statut'],
        orElse: () => EscrowStatut.enAttente,
      ),
      monerooPaymentId: json['moneroo_payment_id'] as String?,
      escrowLibereAt: (json['escrow_libere_at'] as Timestamp?)?.toDate(),
      confirmationClient: json['confirmation_client'] as bool? ?? false,
      confirmationLivreur: json['confirmation_livreur'] as bool? ?? false,
      confirmationClientAt: (json['confirmation_client_at'] as Timestamp?)?.toDate(),
      confirmationLivreurAt: (json['confirmation_livreur_at'] as Timestamp?)?.toDate(),
      photoPreuveUrl: json['photo_preuve_url'] as String?,
      forceParLivreur: json['force_par_livreur'] as bool? ?? false,
      forceRaison: json['force_raison'] as String?,
      statut: StatutCommande.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => StatutCommande.paye,
      ),
      delaiConfirmationHeures: (json['delai_confirmation_heures'] as num?)?.toInt() ?? 24,
      expirationConfirmationAt: (json['expiration_confirmation_at'] as Timestamp?)?.toDate(),
      litigeDescription: json['litige_description'] as String?,
      litigeNoteAdmin: json['litige_note_admin'] as String?,
      litigeCreatedAt: (json['litige_created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() => {
    'numero': numero,
    'created_at': Timestamp.fromDate(createdAt),
    'client_type': clientType.name,
    'client_uid': clientUid,
    'client_nom': clientNom,
    'client_telephone': clientTelephone,
    'client_zone': clientZone,
    'client_adresse_texte': clientAdresseTexte,
    'client_coords': clientCoords,
    'vendeur_id': vendeurId,
    'vendeur_nom': vendeurNom,
    'vendeur_telephone': vendeurTelephone,
    'vendeur_boutique_nom': vendeurBoutiqueNom,
    'livreur_id': livreurId,
    'livreur_nom': livreurNom,
    'livreur_telephone': livreurTelephone,
    'livreur_tarif_zone': livreurTarifZone,
    'livreur_type_engin': livreurTypeEngin,
    'articles': articles.map((e) => e.toJson()).toList(),
    'sous_total_articles': sousTotalArticles,
    'frais_livraison': fraisLivraison,
    'commission_miwodo': commissionMiwodo,
    'total_client': totalClient,
    'montant_vendeur': montantVendeur,
    'escrow_statut': escrowStatut.name,
    'moneroo_payment_id': monerooPaymentId,
    'escrow_libere_at': escrowLibereAt != null ? Timestamp.fromDate(escrowLibereAt!) : null,
    'confirmation_client': confirmationClient,
    'confirmation_livreur': confirmationLivreur,
    'confirmation_client_at': confirmationClientAt != null ? Timestamp.fromDate(confirmationClientAt!) : null,
    'confirmation_livreur_at': confirmationLivreurAt != null ? Timestamp.fromDate(confirmationLivreurAt!) : null,
    'photo_preuve_url': photoPreuveUrl,
    'force_par_livreur': forceParLivreur,
    'force_raison': forceRaison,
    'statut': statut.name,
    'delai_confirmation_heures': delaiConfirmationHeures,
    'expiration_confirmation_at': expirationConfirmationAt != null ? Timestamp.fromDate(expirationConfirmationAt!) : null,
    'litige_description': litigeDescription,
    'litige_note_admin': litigeNoteAdmin,
    'litige_created_at': litigeCreatedAt != null ? Timestamp.fromDate(litigeCreatedAt!) : null,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// SOLDE VENDEUR / LIVREUR
// ═══════════════════════════════════════════════════════════════════════════

class SoldeVendeur {
  final String vendeurId;
  final int soldeDisponible;
  final int soldeEnAttente;
  final int totalEncaisse;
  final DateTime updatedAt;

  SoldeVendeur({
    required this.vendeurId,
    this.soldeDisponible = 0,
    this.soldeEnAttente = 0,
    this.totalEncaisse = 0,
    required this.updatedAt,
  });

  int get soldeTotal => soldeDisponible + soldeEnAttente;

  factory SoldeVendeur.fromJson(Map<String, dynamic> json, String docId) {
    return SoldeVendeur(
      vendeurId: docId,
      soldeDisponible: (json['solde_disponible'] as num?)?.toInt() ?? 0,
      soldeEnAttente: (json['solde_en_attente'] as num?)?.toInt() ?? 0,
      totalEncaisse: (json['total_encaisse'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'vendeur_id': vendeurId,
    'solde_disponible': soldeDisponible,
    'solde_en_attente': soldeEnAttente,
    'total_encaisse': totalEncaisse,
    'updated_at': Timestamp.fromDate(updatedAt),
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// LIVREUR DISPONIBLE (pour sélection)
// ═══════════════════════════════════════════════════════════════════════════

class LivreurDisponible {
  final String id;
  final String nom;
  final String prenom;
  final String? photoUrl;
  final String typeEngin;
  final double noteMoyenne;
  final int nbAvis;
  final int tarifPourZone;
  final String zonePrincipale;
  final bool estZoneExacte;
  final double? distanceEstimee;

  LivreurDisponible({
    required this.id,
    required this.nom,
    required this.prenom,
    this.photoUrl,
    required this.typeEngin,
    this.noteMoyenne = 0,
    this.nbAvis = 0,
    required this.tarifPourZone,
    required this.zonePrincipale,
    this.estZoneExacte = true,
    this.distanceEstimee,
  });

  String get nomComplet => '$prenom $nom';
  String get initiales => '${prenom.isNotEmpty ? prenom[0] : ''}${nom.isNotEmpty ? nom[0] : ''}'.toUpperCase();

  factory LivreurDisponible.fromJson(Map<String, dynamic> json) {
    return LivreurDisponible(
      id: json['id'] as String,
      nom: json['nom'] as String? ?? '',
      prenom: json['prenom'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      typeEngin: json['type_engin'] as String? ?? 'moto',
      noteMoyenne: (json['note_moyenne'] as num?)?.toDouble() ?? 0,
      nbAvis: (json['nb_avis'] as num?)?.toInt() ?? 0,
      tarifPourZone: (json['tarif_pour_zone'] as num?)?.toInt() ?? 0,
      zonePrincipale: json['zone_principale'] as String? ?? '',
      estZoneExacte: json['est_zone_exacte'] as bool? ?? true,
      distanceEstimee: (json['distance_estimee'] as num?)?.toDouble(),
    );
  }
}
