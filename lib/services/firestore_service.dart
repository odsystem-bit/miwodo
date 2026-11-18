// services/firestore_service.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/categories.dart';
import '../models/admin_user.dart';
import '../models/avis.dart';
import '../models/commande.dart';
import '../models/message.dart';
import '../models/prestataire.dart';
import '../models/signalement.dart';
import '../models/transaction_record.dart';
import '../models/produit.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseService.instance.firestore;

  // ─── PRESTATAIRES ─────────────────────────────────────────────────────

  /// Pagination par curseur pour les prestataires
  /// [pageSize] = nombre de résultats par page (défaut 20)
  /// [lastDocument] = dernier document de la page précédente (null pour la 1ère page)
  Future<List<Prestataire>> getPrestatairesPaginated({
    Categorie? categorie,
    String? zone,
    String? paysId,
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('prestataires');

      query = query.where('actif', isEqualTo: true);

      if (categorie != null) {
        query = query.where('categorie', isEqualTo: categorie.name);
      }
      if (paysId != null) {
        query = query.where('paysId', isEqualTo: paysId);
      }

      query = query.limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Prestataire.fromJson(data);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getPrestatairesPaginated error: $e');
      return [];
    }
  }

  /// Récupérer le document snapshot du dernier prestataire d'une liste
  Future<DocumentSnapshot?> getPrestataireLastDoc(String id) async {
    try {
      return await _db.collection('prestataires').doc(id).get();
    } catch (e) {
      return null;
    }
  }

  Stream<List<Prestataire>> getPrestataires({
    Categorie? categorie,
    String? zone,
  }) {
    try {
      Query<Map<String, dynamic>> query = _db.collection('prestataires');

      // IMPORTANT: Filtrer uniquement les prestataires actifs
      query = query.where('actif', isEqualTo: true);

      if (categorie != null) {
        query = query.where('categorie', isEqualTo: categorie.name);
      }
      if (zone != null) {
        query = query.where('zone', isEqualTo: zone);
      }

      return query.limit(50).snapshots().map((snapshot) {
        final list = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Prestataire.fromJson(data);
        }).toList();

        // Trier: vérifiés en premier, puis par note
        list.sort((a, b) {
          // Sponsorisés en premier
          if (a.sponsorise && !b.sponsorise) return -1;
          if (!a.sponsorise && b.sponsorise) return 1;
          // Puis vérifiés
          if (a.estVerifie && !b.estVerifie) return -1;
          if (!a.estVerifie && b.estVerifie) return 1;
          // Puis par note
          return b.noteMoyenne.compareTo(a.noteMoyenne);
        });

        return list;
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[FirestoreService] getPrestataires stream error: $error');
            sink.add(<Prestataire>[]);
          },
        ),
      );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getPrestataires error: $e');
      return Stream.value([]);
    }
  }

  Future<Prestataire?> getPrestataire(String uid) async {
    try {
      final doc = await _db.collection('prestataires').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return Prestataire.fromJson(data);
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getPrestataire error: $e');
      return null;
    }
  }

  Future<void> createPrestataire(Prestataire data) async {
    try {
      await _db.collection('prestataires').doc(data.id).set(data.toJson());
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] createPrestataire error: $e');
      rethrow;
    }
  }

  /// Traite le parrainage lors d'une nouvelle inscription et crédite le parrain
  Future<bool> crediterParrain({
    required String codeParrain,
    required String filleulId,
    required String filleulNom,
    String? filleulMetier,
    String? filleulCategorie,
    required double montantGain,
    required String devise,
  }) async {
    try {
      final codeNettoye = codeParrain.trim().toUpperCase();
      final query = await _db
          .collection('prestataires')
          .where('codeParrain', isEqualTo: codeNettoye)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        if (kDebugMode) print('[FirestoreService] Aucun parrain trouvé pour le code: $codeNettoye');
        return false;
      }

      final parrainDoc = query.docs.first;
      final parrainId = parrainDoc.id;

      // Éviter l'auto-parrainage
      if (parrainId == filleulId) {
        if (kDebugMode) print('[FirestoreService] Auto-parrainage détecté et ignoré');
        return false;
      }

      // 1. Créditer le parrain (incrémenter le nombre de filleuls et les gains)
      await _db.collection('prestataires').doc(parrainId).update({
        'filleuls': FieldValue.increment(1),
        'gainsParrainage': FieldValue.increment(montantGain),
      });

      // 2. Enregistrer l'historique dans la collection 'parrainages'
      await _db.collection('parrainages').add({
        'parrainId': parrainId,
        'parrainNom': '${parrainDoc.data()['prenom'] ?? ''} ${parrainDoc.data()['nom'] ?? ''}'.trim(),
        'filleulId': filleulId,
        'filleulNom': filleulNom,
        'filleulMetier': filleulMetier,
        'filleulCategorie': filleulCategorie,
        'codeUtilise': codeNettoye,
        'montantGain': montantGain,
        'devise': devise,
        'created_at': FieldValue.serverTimestamp(),
      });

      // 3. Envoyer une notification directe au parrain
      try {
        await NotificationService.instance.createNotification(
          userId: parrainId,
          title: 'Nouveau filleul parrainé ! 🎉',
          body: '$filleulNom a rejoint Miwodo grâce à votre lien. Vous avez gagné +${montantGain.toInt()} $devise !',
          type: 'parrainage',
          targetId: filleulId,
        );
      } catch (notifErr) {
        if (kDebugMode) print('[FirestoreService] Erreur notification parrainage: $notifErr');
      }

      return true;
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] crediterParrain error: $e');
      return false;
    }
  }

  Future<void> updatePrestataire(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('prestataires').doc(uid).update(data);
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] updatePrestataire error: $e');
      rethrow;
    }
  }

  Stream<int> getPrestatairesCount() {
    return _db
        .collection('prestataires')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getCommandesCountToday() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return _db
        .collection('commandes')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> getSignalementsCount(String statut) {
    return _db
        .collection('signalements')
        .where('statut', isEqualTo: statut)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<List<Prestataire>> getLatestPrestataires({int limit = 5}) {
    try {
      return _db
          .collection('prestataires')
          .orderBy('creeLe', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Prestataire.fromJson(data);
            }).toList();
            return list;
          });
    } catch (e) {
      if (kDebugMode)
        print('[FirestoreService] getLatestPrestataires error: $e');
      return const Stream.empty();
    }
  }

  Stream<List<Prestataire>> getUnverifiedPrestataires() {
    try {
      return _db
          .collection('prestataires')
          .where('estVerifie', isEqualTo: false)
          .snapshots()
          .map((snapshot) {
            final list = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Prestataire.fromJson(data);
            }).toList();
            return list;
          });
    } catch (e) {
      if (kDebugMode)
        print('[FirestoreService] getUnverifiedPrestataires error: $e');
      return const Stream.empty();
    }
  }

  Stream<List<AdminUser>> getAdminUsers() {
    try {
      return _db
          .collection('admins')
          .orderBy('createdAt', descending: false)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['uid'] = doc.id;
              return AdminUser.fromJson(data);
            }).toList(),
          );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getAdminUsers error: $e');
      return const Stream.empty();
    }
  }

  Future<void> createAdminUser(AdminUser admin) async {
    try {
      await _db.collection('admins').doc(admin.uid).set(admin.toJson());
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] createAdminUser error: $e');
      rethrow;
    }
  }

  Future<void> toggleAdminActive(String uid, bool active) async {
    try {
      await _db.collection('admins').doc(uid).update({'actif': active});
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] toggleAdminActive error: $e');
      rethrow;
    }
  }

  Stream<List<Signalement>> getSignalements({String statut = 'ouvert'}) {
    try {
      Query<Map<String, dynamic>> query = _db.collection('signalements');
      if (statut.isNotEmpty) {
        query = query.where('statut', isEqualTo: statut);
      }
      return query.orderBy('createdAt', descending: true).snapshots().map((
        snapshot,
      ) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Signalement.fromJson(data);
        }).toList();
      });
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getSignalements error: $e');
      return const Stream.empty();
    }
  }

  Future<void> updateSignalementStatus(String id, String statut) async {
    try {
      await _db.collection('signalements').doc(id).update({'statut': statut});
    } catch (e) {
      if (kDebugMode)
        print('[FirestoreService] updateSignalementStatus error: $e');
      rethrow;
    }
  }

  Future<String> createSignalement(Signalement data) async {
    try {
      final docRef = await _db.collection('signalements').add(data.toJson());
      // Notifier les admins
      try {
        await NotificationService.instance.notifyNewSignalement(
          signalementId: docRef.id,
          motif: data.motif,
        );
      } catch (e) {
        if (kDebugMode) print('[FirestoreService] Signalement notification error: $e');
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] createSignalement error: $e');
      rethrow;
    }
  }

  Future<void> createTransaction({
    required String paymentId,
    required String type,
    required double montant,
  }) async {
    try {
      await _db.collection('transactions').add({
        'paymentId': paymentId,
        'type': type,
        'montant': montant,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
      if (kDebugMode) print('[FirestoreService] Transaction enregistrée: $type $montant');
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] createTransaction error: $e');
    }
  }

  Stream<List<TransactionRecord>> getTransactions({DateTime? from}) {
    try {
      Query<Map<String, dynamic>> query = _db.collection('transactions');
      if (from != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from),
        );
      }
      return query
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return TransactionRecord.fromJson(data);
            }).toList();
          });
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getTransactions error: $e');
      return const Stream.empty();
    }
  }

  Future<void> deletePrestataire(String uid) async {
    try {
      // Supprimer d'abord tous les services associés
      final servicesSnap = await _db
          .collection('services')
          .where('prestataireId', isEqualTo: uid)
          .get();
      
      final batch = _db.batch();
      for (final doc in servicesSnap.docs) {
        batch.delete(doc.reference);
      }
      
      // Supprimer aussi les produits associés
      final produitsSnap = await _db
          .collection('produits')
          .where('prestataireId', isEqualTo: uid)
          .get();
      
      for (final doc in produitsSnap.docs) {
        batch.delete(doc.reference);
      }
      
      // Supprimer le prestataire
      batch.delete(_db.collection('prestataires').doc(uid));
      
      await batch.commit();
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] deletePrestataire error: $e');
      rethrow;
    }
  }

  Future<void> suspendPrestataire(String uid) async {
    try {
      await _db.collection('prestataires').doc(uid).update({'actif': false});
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] suspendPrestataire error: $e');
      rethrow;
    }
  }

  Future<void> verifyPrestataire(String uid) async {
    try {
      await _db.collection('prestataires').doc(uid).update({
        'estVerifie': true,
      });
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] verifyPrestataire error: $e');
      rethrow;
    }
  }

  Future<void> sponsorisePrestataire(String uid) async {
    try {
      await _db.collection('prestataires').doc(uid).update({
        'sponsorise': true,
      });
    } catch (e) {
      if (kDebugMode)
        print('[FirestoreService] sponsorisePrestataire error: $e');
      rethrow;
    }
  }

  Future<void> unsponsorisePrestataire(String uid) async {
    try {
      await _db.collection('prestataires').doc(uid).update({
        'sponsorise': false,
      });
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] unsponsorisePrestataire error: $e');
      rethrow;
    }
  }

  Future<void> togglePrestataireActif(String uid, bool actif) async {
    try {
      await _db.collection('prestataires').doc(uid).update({
        'actif': actif,
      });
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] togglePrestataireActif error: $e');
      rethrow;
    }
  }

  // ─── AVIS (Admin) ────────────────────────────────────────────────────

  Stream<List<Avis>> getAllAvis({int limit = 50}) {
    try {
      return _db
          .collection('avis')
          .orderBy('creeLe', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return Avis.fromJson(data);
              }).toList());
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getAllAvis error: $e');
      return Stream.value([]);
    }
  }

  Future<void> deleteAvis(String avisId) async {
    try {
      await _db.collection('avis').doc(avisId).delete();
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] deleteAvis error: $e');
      rethrow;
    }
  }

  // ─── STATISTIQUES (Admin) ────────────────────────────────────────────

  Stream<int> getUsersCount() {
    return _db.collection('prestataires').snapshots().map((s) => s.docs.length);
  }

  Stream<int> getVerifiedCount() {
    return _db
        .collection('prestataires')
        .where('estVerifie', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<int> getSponsoredCount() {
    return _db
        .collection('prestataires')
        .where('sponsorise', isEqualTo: true)
        .snapshots()
        .map((s) => s.docs.length);
  }

  Stream<List<Map<String, dynamic>>> getRecentInscriptions({int days = 30}) {
    final from = DateTime.now().subtract(Duration(days: days));
    return _db
        .collection('prestataires')
        .where('creeLe', isGreaterThanOrEqualTo: from)
        .orderBy('creeLe', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) {
              final data = d.data();
              data['id'] = d.id;
              return data;
            }).toList());
  }

  // ─── PRODUITS ─────────────────────────────────────────────────────────

  /// Pagination par curseur pour les produits
  Future<List<Produit>> getProduitsPaginated({
    String? vendeurId,
    int pageSize = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('produits');

      if (vendeurId != null) {
        query = query.where('prestataireId', isEqualTo: vendeurId);
      }

      query = query.orderBy('creeLe', descending: true).limit(pageSize);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Produit.fromJson(data);
      }).toList();
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getProduitsPaginated error: $e');
      return [];
    }
  }

  Stream<List<Produit>> getProduits({String? vendeurId}) {
    try {
      Query<Map<String, dynamic>> query = _db.collection('produits');

      if (vendeurId != null) {
        query = query.where('prestataireId', isEqualTo: vendeurId);
      }

      return query
          .orderBy('creeLe', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Produit.fromJson(data);
            }).toList(),
          );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getProduits error: $e');
      return const Stream.empty();
    }
  }

  // ─── COMMANDES ────────────────────────────────────────────────────────

  Future<String> createCommande(CommandeVendeur data) async {
    try {
      final docRef = await _db.collection('commandes').add(data.toJson());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] createCommande error: $e');
      rethrow;
    }
  }

  Stream<List<CommandeVendeur>> getCommandes(String prestataireId) {
    try {
      return _db
          .collection('commandes')
          .where('vendeur_id', isEqualTo: prestataireId)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return CommandeVendeur.fromJson(data, doc.id);
            }).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getCommandes error: $e');
      return const Stream.empty();
    }
  }

  Stream<List<CommandeVendeur>> getAllCommandes() {
    try {
      return _db
          .collection('commandes')
          .limit(100)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return CommandeVendeur.fromJson(data, doc.id);
            }).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getAllCommandes error: $e');
      return const Stream.empty();
    }
  }

  Future<void> updateCommandeStatut(String commandeId, String statut) async {
    try {
      await _db.collection('commandes').doc(commandeId).update({'statut': statut});
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] updateCommandeStatut error: $e');
      rethrow;
    }
  }

  Future<void> updateCommandeLitigeNote(String commandeId, String note) async {
    try {
      await _db.collection('commandes').doc(commandeId).update({'litigeNoteAdmin': note});
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] updateCommandeLitigeNote error: $e');
      rethrow;
    }
  }

  // ─── AVIS ─────────────────────────────────────────────────────────────

  Future<void> addAvis(Avis data) async {
    try {
      await _db.runTransaction((transaction) async {
        final prestataireRef = _db
            .collection('prestataires')
            .doc(data.prestataireId);
        final prestataireSnap = await transaction.get(prestataireRef);

        if (!prestataireSnap.exists) {
          throw Exception('Prestataire introuvable');
        }

        final prestataireData = prestataireSnap.data()!;
        final currentNote =
            (prestataireData['noteMoyenne'] as num?)?.toDouble() ?? 0.0;
        final currentCount =
            (prestataireData['nombreAvis'] as num?)?.toInt() ?? 0;

        final newCount = currentCount + 1;
        final newNote = ((currentNote * currentCount) + data.note) / newCount;

        final avisRef = _db.collection('avis').doc();
        final avisData = data.toJson();
        avisData['id'] = avisRef.id;

        transaction.set(avisRef, avisData);
        transaction.update(prestataireRef, {
          'noteMoyenne': newNote,
          'nombreAvis': newCount,
        });
      });
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] addAvis error: $e');
      rethrow;
    }
  }

  Future<List<Avis>> getAvisForPrestataire(
    String prestataireId, {
    int limit = 5,
  }) async {
    try {
      final snap = await _db
          .collection('avis')
          .where('prestataireId', isEqualTo: prestataireId)
          .orderBy('creeLe', descending: true)
          .limit(limit)
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Avis.fromJson(data);
      }).toList();
    } catch (e) {
      if (kDebugMode)
        print('[FirestoreService] getAvisForPrestataire error: $e');
      return [];
    }
  }

  // ─── MESSAGES ─────────────────────────────────────────────────────────

  /// Récupère les messages pour l'utilisateur connecté (derniers messages par conversation)
  Stream<List<Message>> getMessagesForCurrentUser() {
    try {
      final userId = FirebaseService.instance.auth.currentUser?.uid;
      if (userId == null) {
        return Stream.value([]);
      }

      return _db
          .collection('messages')
          .where('participants', arrayContains: userId)
          .orderBy('envoyeLe', descending: true)
          .limit(50)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Message.fromJson(data);
            }).toList(),
          );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getMessagesForCurrentUser error: $e');
      return Stream.value([]);
    }
  }

  Stream<List<Message>> getMessages(String conversationId) {
    try {
      return _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .orderBy('creeLe', descending: false)
          .limit(100)
          .snapshots()
          .map(
            (snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Message.fromJson(data);
            }).toList(),
          );
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] getMessages error: $e');
      return const Stream.empty();
    }
  }

  Future<void> sendMessage(String conversationId, Message msg) async {
    try {
      await _db
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(msg.toJson());
    } catch (e) {
      if (kDebugMode) print('[FirestoreService] sendMessage error: $e');
      rethrow;
    }
  }
}
