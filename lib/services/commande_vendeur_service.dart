// services/commande_vendeur_service.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/commande.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// SERVICE DE COMMANDE VENDEUR
// ═══════════════════════════════════════════════════════════════════════════

class CommandeVendeurService {
  static final CommandeVendeurService instance = CommandeVendeurService._();
  CommandeVendeurService._();

  final _firestore = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────────────────────────────────
  // GÉNÉRATION NUMÉRO COMMANDE
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _generateNumeroCommande() async {
    final year = DateTime.now().year;
    final counterRef = _firestore.collection('config').doc('counters');

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentCount = 0;

      if (snapshot.exists) {
        final data = snapshot.data()!;
        final yearKey = 'commandes_$year';
        currentCount = (data[yearKey] as num?)?.toInt() ?? 0;
      }

      final newCount = currentCount + 1;
      transaction.set(
        counterRef,
        {'commandes_$year': newCount},
        SetOptions(merge: true),
      );

      return 'MW-$year-${newCount.toString().padLeft(4, '0')}';
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURATION TARIFS
  // ─────────────────────────────────────────────────────────────────────────

  Future<TarifsConfig> getTarifsConfig() async {
    try {
      final doc = await _firestore.collection('config').doc('tarifs').get();
      if (doc.exists) {
        return TarifsConfig.fromJson(doc.data()!);
      }
    } catch (e) {
      debugPrint('Erreur chargement tarifs: $e');
    }
    return TarifsConfig.defaults();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CRÉATION COMMANDE
  // ─────────────────────────────────────────────────────────────────────────

  Future<CommandeVendeur> creerCommande({
    // Client
    required bool estInscrit,
    String? clientUid,
    required String clientNom,
    required String clientTelephone,
    required String clientZone,
    required String clientAdresseTexte,
    GeoPoint? clientCoords,
    // Vendeur
    required String vendeurId,
    required String vendeurNom,
    String? vendeurTelephone,
    String? vendeurBoutiqueNom,
    // Livreur
    required String livreurId,
    required String livreurNom,
    required String livreurTelephone,
    required int livreurTarifZone,
    String? livreurTypeEngin,
    // Articles
    required List<ArticleCommande> articles,
    // Paiement
    required String monerooPaymentId,
  }) async {
    final tarifs = await getTarifsConfig();
    final numero = await _generateNumeroCommande();

    // Calcul des montants
    final sousTotalArticles = articles.fold<int>(0, (sum, a) => sum + a.sousTotal);
    final fraisLivraison = livreurTarifZone;
    final commissionMiwodo = tarifs.commissionFixeCommande;
    final totalClient = sousTotalArticles + fraisLivraison;
    final montantVendeur = sousTotalArticles - commissionMiwodo;

    final now = DateTime.now();
    final expiration = now.add(Duration(hours: tarifs.delaiConfirmationHeures));

    final commandeData = {
      'numero': numero,
      'created_at': Timestamp.fromDate(now),
      'client_type': estInscrit ? 'inscrit' : 'invite',
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
      'articles': articles.map((a) => a.toJson()).toList(),
      'sous_total_articles': sousTotalArticles,
      'frais_livraison': fraisLivraison,
      'commission_miwodo': commissionMiwodo,
      'total_client': totalClient,
      'montant_vendeur': montantVendeur,
      'escrow_statut': 'enAttente',
      'moneroo_payment_id': monerooPaymentId,
      'confirmation_client': false,
      'confirmation_livreur': false,
      'force_par_livreur': false,
      'statut': 'paye',
      'delai_confirmation_heures': tarifs.delaiConfirmationHeures,
      'expiration_confirmation_at': Timestamp.fromDate(expiration),
    };

    final docRef = await _firestore.collection('commandes').add(commandeData);

    // Mettre à jour le solde en attente du vendeur
    await _updateSoldeEnAttente(vendeurId, montantVendeur);

    // Notifier le vendeur et les admins
    try {
      await NotificationService.instance.notifyNewOrder(
        vendeurId: vendeurId,
        commandeId: docRef.id,
        clientName: clientNom,
        total: totalClient,
      );
    } catch (e) {
      if (kDebugMode) print('[CommandeService] Notification error: $e');
    }

    return CommandeVendeur.fromJson(commandeData, docRef.id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS LIVREUR
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> accepterCourse(String commandeId, String livreurId) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'statut': 'accepte',
      'livreur_accepte_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> refuserCourse(String commandeId, String livreurId) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'livreurs_refuses': FieldValue.arrayUnion([livreurId]),
    });
  }

  Future<void> marquerEnRoute(String commandeId) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'statut': 'enRoute',
      'en_route_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> marquerLivre(String commandeId) async {
    final tarifs = await getTarifsConfig();
    final expiration = DateTime.now().add(Duration(hours: tarifs.delaiConfirmationHeures));

    await _firestore.collection('commandes').doc(commandeId).update({
      'statut': 'livre',
      'livre_at': FieldValue.serverTimestamp(),
      'expiration_confirmation_at': Timestamp.fromDate(expiration),
    });
  }

  Future<void> confirmerLivreur(String commandeId) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'confirmation_livreur': true,
      'confirmation_livreur_at': FieldValue.serverTimestamp(),
    });

    // Vérifier si les deux ont confirmé
    await _checkDoubleConfirmation(commandeId);
  }

  Future<void> forcerConfirmation({
    required String commandeId,
    required File photoPreuve,
    required String raison,
  }) async {
    // Upload photo (non bloquant)
    final fileName = 'preuves_livraison/$commandeId.jpg';
    String? photoUrl;
    try {
      photoUrl = await SupabaseService.uploadPhoto(
        bucket: 'miwodo-photos',
        path: fileName,
        file: photoPreuve,
      );
    } catch (e) {
      if (kDebugMode) print('[CommandeVendeurService] Upload preuve échoué: $e');
    }

    await _firestore.collection('commandes').doc(commandeId).update({
      'confirmation_livreur': true,
      'confirmation_livreur_at': FieldValue.serverTimestamp(),
      if (photoUrl != null) 'photo_preuve_url': photoUrl,
      'force_par_livreur': true,
      'force_raison': raison,
      'statut': 'forceConfirme',
      'escrow_statut': 'force',
    });

    // Libérer l'escrow (forcé)
    await _libererEscrow(commandeId, force: true);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS CLIENT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> confirmerClient(String commandeId) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'confirmation_client': true,
      'confirmation_client_at': FieldValue.serverTimestamp(),
    });

    // Vérifier si les deux ont confirmé
    await _checkDoubleConfirmation(commandeId);
  }

  Future<void> signalerLitige({
    required String commandeId,
    required String description,
  }) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'statut': 'litige',
      'litige_description': description,
      'litige_created_at': FieldValue.serverTimestamp(),
    });

    // Notifier les admins du litige
    try {
      await NotificationService.instance.notifyAdmins(
        title: 'Litige signalé',
        body: 'Commande $commandeId: $description',
        type: 'commande',
        targetId: commandeId,
      );
    } catch (e) {
      if (kDebugMode) print('[CommandeService] Litige notification error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS ADMIN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> libererVersVendeur({
    required String commandeId,
    required String noteAdmin,
  }) async {
    await _firestore.collection('commandes').doc(commandeId).update({
      'litige_note_admin': noteAdmin,
    });
    await _libererEscrow(commandeId);
  }

  Future<void> rembourserClient({
    required String commandeId,
    required String noteAdmin,
  }) async {
    final doc = await _firestore.collection('commandes').doc(commandeId).get();
    final commande = CommandeVendeur.fromJson(doc.data()!, doc.id);

    await _firestore.collection('commandes').doc(commandeId).update({
      'statut': 'rembourse',
      'escrow_statut': 'rembourse',
      'litige_note_admin': noteAdmin,
      'rembourse_at': FieldValue.serverTimestamp(),
    });

    // Retirer du solde en attente du vendeur
    await _updateSoldeEnAttente(commande.vendeurId, -commande.montantVendeur);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GESTION ESCROW
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _checkDoubleConfirmation(String commandeId) async {
    final doc = await _firestore.collection('commandes').doc(commandeId).get();
    final data = doc.data()!;

    final confirmationClient = data['confirmation_client'] as bool? ?? false;
    final confirmationLivreur = data['confirmation_livreur'] as bool? ?? false;

    if (confirmationClient && confirmationLivreur) {
      await _libererEscrow(commandeId);
    }
  }

  Future<void> _libererEscrow(String commandeId, {bool force = false}) async {
    final doc = await _firestore.collection('commandes').doc(commandeId).get();
    final commande = CommandeVendeur.fromJson(doc.data()!, doc.id);

    // Transaction atomique pour créditer les soldes
    await _firestore.runTransaction((transaction) async {
      // 1. Créditer le vendeur
      final vendeurSoldeRef = _firestore.collection('soldes_vendeurs').doc(commande.vendeurId);
      final vendeurSoldeDoc = await transaction.get(vendeurSoldeRef);

      if (vendeurSoldeDoc.exists) {
        transaction.update(vendeurSoldeRef, {
          'solde_disponible': FieldValue.increment(commande.montantVendeur),
          'solde_en_attente': FieldValue.increment(-commande.montantVendeur),
          'total_encaisse': FieldValue.increment(commande.montantVendeur),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(vendeurSoldeRef, {
          'vendeur_id': commande.vendeurId,
          'solde_disponible': commande.montantVendeur,
          'solde_en_attente': 0,
          'total_encaisse': commande.montantVendeur,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // 2. Créditer le livreur
      final livreurSoldeRef = _firestore.collection('soldes_vendeurs').doc(commande.livreurId);
      final livreurSoldeDoc = await transaction.get(livreurSoldeRef);

      if (livreurSoldeDoc.exists) {
        transaction.update(livreurSoldeRef, {
          'solde_disponible': FieldValue.increment(commande.fraisLivraison),
          'total_encaisse': FieldValue.increment(commande.fraisLivraison),
          'updated_at': FieldValue.serverTimestamp(),
        });
      } else {
        transaction.set(livreurSoldeRef, {
          'vendeur_id': commande.livreurId,
          'solde_disponible': commande.fraisLivraison,
          'solde_en_attente': 0,
          'total_encaisse': commande.fraisLivraison,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      // 3. Mettre à jour la commande
      final commandeRef = _firestore.collection('commandes').doc(commandeId);
      transaction.update(commandeRef, {
        'statut': force ? 'forceConfirme' : 'confirme',
        'escrow_statut': force ? 'force' : 'libere',
        'escrow_libere_at': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _updateSoldeEnAttente(String vendeurId, int montant) async {
    final ref = _firestore.collection('soldes_vendeurs').doc(vendeurId);
    final doc = await ref.get();

    if (doc.exists) {
      await ref.update({
        'solde_en_attente': FieldValue.increment(montant),
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set({
        'vendeur_id': vendeurId,
        'solde_disponible': 0,
        'solde_en_attente': montant > 0 ? montant : 0,
        'total_encaisse': 0,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STREAMS
  // ─────────────────────────────────────────────────────────────────────────

  Stream<CommandeVendeur> streamCommande(String commandeId) {
    return _firestore
        .collection('commandes')
        .doc(commandeId)
        .snapshots()
        .map((doc) => CommandeVendeur.fromJson(doc.data()!, doc.id));
  }

  Stream<List<CommandeVendeur>> streamCommandesClient(String clientUid) {
    return _firestore
        .collection('commandes')
        .where('client_uid', isEqualTo: clientUid)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommandeVendeur.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CommandeVendeur>> streamCommandesVendeur(String vendeurId) {
    return _firestore
        .collection('commandes')
        .where('vendeur_id', isEqualTo: vendeurId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommandeVendeur.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CommandeVendeur>> streamCommandesLivreur(String livreurId) {
    return _firestore
        .collection('commandes')
        .where('livreur_id', isEqualTo: livreurId)
        .orderBy('created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommandeVendeur.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CommandeVendeur>> streamCoursesDisponibles(String zone) {
    return _firestore
        .collection('commandes')
        .where('statut', isEqualTo: 'paye')
        .where('client_zone', isEqualTo: zone)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommandeVendeur.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<CommandeVendeur>> streamLitiges() {
    return _firestore
        .collection('commandes')
        .where('statut', isEqualTo: 'litige')
        .orderBy('litige_created_at', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommandeVendeur.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<SoldeVendeur> streamSolde(String vendeurId) {
    return _firestore
        .collection('soldes_vendeurs')
        .doc(vendeurId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return SoldeVendeur.fromJson(doc.data()!, doc.id);
      }
      return SoldeVendeur(vendeurId: vendeurId, updatedAt: DateTime.now());
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURATION TARIFS
// ═══════════════════════════════════════════════════════════════════════════

class TarifsConfig {
  final int commissionFixeCommande;
  final int delaiConfirmationHeures;
  final int delaiForceLivraisonHeures;

  TarifsConfig({
    required this.commissionFixeCommande,
    required this.delaiConfirmationHeures,
    required this.delaiForceLivraisonHeures,
  });

  factory TarifsConfig.defaults() => TarifsConfig(
    commissionFixeCommande: 100,
    delaiConfirmationHeures: 24,
    delaiForceLivraisonHeures: 22,
  );

  factory TarifsConfig.fromJson(Map<String, dynamic> json) => TarifsConfig(
    commissionFixeCommande: (json['commission_fixe_commande'] as num?)?.toInt() ?? 100,
    delaiConfirmationHeures: (json['delai_confirmation_heures'] as num?)?.toInt() ?? 24,
    delaiForceLivraisonHeures: (json['delai_force_livraison_heures'] as num?)?.toInt() ?? 22,
  );
}
