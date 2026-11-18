import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/demande_retrait.dart';
import 'notification_service.dart';

class RetraitService {
  static final RetraitService instance = RetraitService._();
  RetraitService._();

  final _firestore = FirebaseFirestore.instance;

  Stream<List<DemandeRetrait>> streamDemandesRetrait(String prestataireId) {
    return _firestore
        .collection('demandes_retrait')
        .where('prestataire_id', isEqualTo: prestataireId)
        .orderBy('cree_le', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => DemandeRetrait.fromJson(doc.data(), doc.id))
            .toList());
  }

  Stream<List<DemandeRetrait>> streamAllDemandesRetrait({RetraitStatut? filtreStatut}) {
    Query query = _firestore
        .collection('demandes_retrait');

    if (filtreStatut != null) {
      query = query.where('statut', isEqualTo: filtreStatut.name);
    }

    query = query.orderBy('cree_le', descending: true).limit(100);

    return query.snapshots().map((snap) => snap.docs
        .map((doc) => DemandeRetrait.fromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }

  Future<List<DemandeRetrait>> getDemandesRetrait(String prestataireId) async {
    final snap = await _firestore
        .collection('demandes_retrait')
        .where('prestataire_id', isEqualTo: prestataireId)
        .orderBy('cree_le', descending: true)
        .limit(50)
        .get();

    return snap.docs
        .map((doc) => DemandeRetrait.fromJson(doc.data(), doc.id))
        .toList();
  }

  Future<int> getSoldeParrainage(String prestataireId) async {
    final doc = await _firestore.collection('prestataires').doc(prestataireId).get();
    if (doc.exists) {
      return ((doc.data()?['gainsParrainage'] as num?)?.toDouble() ?? 0).toInt();
    }
    return 0;
  }

  Future<void> creerDemandeRetrait({
    required String prestataireId,
    required String prestataireNom,
    required RetraitSource source,
    required int montant,
    required String devise,
    required MethodePaiement methodePaiement,
    required String numeroDestinataire,
    String? nomDestinataire,
    required int retraitMinimum,
  }) async {
    if (montant < retraitMinimum) {
      throw Exception('Le montant minimum de retrait est de $retraitMinimum $devise');
    }

    if (source == RetraitSource.parrainage) {
      final solde = await getSoldeParrainage(prestataireId);
      if (montant > solde) {
        throw Exception('Montant supérieur à votre solde de parrainage ($solde $devise)');
      }
    } else {
      final soldeDoc = await _firestore.collection('soldes_vendeurs').doc(prestataireId).get();
      final soldeDisponible = (soldeDoc.data()?['solde_disponible'] as num?)?.toInt() ?? 0;
      if (montant > soldeDisponible) {
        throw Exception('Montant supérieur à votre solde disponible ($soldeDisponible $devise)');
      }
    }

    final demande = DemandeRetrait(
      id: '',
      prestataireId: prestataireId,
      prestataireNom: prestataireNom,
      source: source,
      montant: montant,
      devise: devise,
      methodePaiement: methodePaiement,
      numeroDestinataire: numeroDestinataire,
      nomDestinataire: nomDestinataire,
      creeLe: DateTime.now(),
    );

    final docRef = await _firestore.collection('demandes_retrait').add(demande.toJson());

    if (source == RetraitSource.parrainage) {
      await _firestore.collection('prestataires').doc(prestataireId).update({
        'gainsParrainage': FieldValue.increment(-montant),
      });
    } else {
      await _firestore.collection('soldes_vendeurs').doc(prestataireId).update({
        'solde_disponible': FieldValue.increment(-montant),
        'solde_en_attente_retrait': FieldValue.increment(montant),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    try {
      await NotificationService.instance.notifyAdmins(
        title: 'Nouvelle demande de retrait',
        body: '$prestataireNom demande $montant $devise (${source.label})',
        type: 'retrait',
        targetId: docRef.id,
      );
    } catch (e) {
      if (kDebugMode) print('[RetraitService] Notification error: $e');
    }
  }

  Future<void> approuverDemande({
    required String demandeId,
    required String adminId,
    required String adminNom,
  }) async {
    final doc = await _firestore.collection('demandes_retrait').doc(demandeId).get();
    if (!doc.exists) throw Exception('Demande introuvable');

    final demande = DemandeRetrait.fromJson(doc.data()!, doc.id);
    if (demande.statut != RetraitStatut.enAttente) {
      throw Exception('Cette demande a déjà été traitée');
    }

    await _firestore.collection('demandes_retrait').doc(demandeId).update({
      'statut': RetraitStatut.approuve.name,
      'admin_id': adminId,
      'admin_nom': adminNom,
      'traite_le': FieldValue.serverTimestamp(),
    });

    try {
      await NotificationService.instance.createNotification(
        userId: demande.prestataireId,
        title: 'Demande de retrait approuvée',
        body: 'Votre demande de ${demande.montant} ${demande.devise} a été approuvée. Le paiement sera effectué prochainement.',
        type: 'retrait',
        targetId: demandeId,
      );
    } catch (e) {
      if (kDebugMode) print('[RetraitService] Notification error: $e');
    }
  }

  Future<void> refuserDemande({
    required String demandeId,
    required String adminId,
    required String adminNom,
    required String raisonRefus,
  }) async {
    final doc = await _firestore.collection('demandes_retrait').doc(demandeId).get();
    if (!doc.exists) throw Exception('Demande introuvable');

    final demande = DemandeRetrait.fromJson(doc.data()!, doc.id);
    if (demande.statut != RetraitStatut.enAttente) {
      throw Exception('Cette demande a déjà été traitée');
    }

    await _firestore.runTransaction((transaction) async {
      transaction.update(_firestore.collection('demandes_retrait').doc(demandeId), {
        'statut': RetraitStatut.refuse.name,
        'raison_refus': raisonRefus,
        'admin_id': adminId,
        'admin_nom': adminNom,
        'traite_le': FieldValue.serverTimestamp(),
      });

      if (demande.source == RetraitSource.parrainage) {
        transaction.update(_firestore.collection('prestataires').doc(demande.prestataireId), {
          'gainsParrainage': FieldValue.increment(demande.montant),
        });
      } else {
        transaction.update(_firestore.collection('soldes_vendeurs').doc(demande.prestataireId), {
          'solde_disponible': FieldValue.increment(demande.montant),
          'solde_en_attente_retrait': FieldValue.increment(-demande.montant),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    });

    try {
      await NotificationService.instance.createNotification(
        userId: demande.prestataireId,
        title: 'Demande de retrait refusée',
        body: 'Votre demande de ${demande.montant} ${demande.devise} a été refusée. Raison: $raisonRefus',
        type: 'retrait',
        targetId: demandeId,
      );
    } catch (e) {
      if (kDebugMode) print('[RetraitService] Notification error: $e');
    }
  }

  Future<void> marquerCommePaye({
    required String demandeId,
  }) async {
    await _firestore.collection('demandes_retrait').doc(demandeId).update({
      'statut': RetraitStatut.paye.name,
      'paye_le': FieldValue.serverTimestamp(),
    });

    final doc = await _firestore.collection('demandes_retrait').doc(demandeId).get();
    if (!doc.exists) return;
    final demande = DemandeRetrait.fromJson(doc.data()!, doc.id);

    if (demande.source != RetraitSource.parrainage) {
      await _firestore.collection('soldes_vendeurs').doc(demande.prestataireId).update({
        'solde_en_attente_retrait': FieldValue.increment(-demande.montant),
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    try {
      await NotificationService.instance.createNotification(
        userId: demande.prestataireId,
        title: 'Retrait payé',
        body: 'Votre retrait de ${demande.montant} ${demande.devise} a été effectué avec succès.',
        type: 'retrait',
        targetId: demandeId,
      );
    } catch (e) {
      if (kDebugMode) print('[RetraitService] Notification error: $e');
    }
  }
}
