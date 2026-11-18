// services/sponsoring_service.dart
// Service pour gérer les campagnes de sponsoring de services

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sponsoring_campaign.dart';
import 'sponsoring_validation_service.dart';

class SponsoringService {
  static final SponsoringService instance = SponsoringService._();
  SponsoringService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Create ──────────────────────────────────────────────────────────────

  Future<String> createCampaign(SponsoringCampaign campaign) async {
    try {
      final docRef = await _db.collection('sponsoring_campaigns').add(campaign.toJson());
      final campaignWithId = SponsoringCampaign(
        id: docRef.id,
        serviceId: campaign.serviceId,
        serviceName: campaign.serviceName,
        prestataireId: campaign.prestataireId,
        prestataireNom: campaign.prestataireNom,
        plan: campaign.plan,
        montant: campaign.montant,
        devise: campaign.devise,
        paymentId: campaign.paymentId,
        statut: campaign.statut,
        dateDebut: campaign.dateDebut,
        dateFin: campaign.dateFin,
        creeLe: campaign.creeLe,
        modifieLe: campaign.modifieLe,
        adminNote: campaign.adminNote,
        vues: campaign.vues,
        clics: campaign.clics,
      );

      // Déclencher la validation automatique en arrière-plan
      SponsoringValidationService.instance
          .processCampaignAfterCreation(campaignWithId)
          .catchError((e) {
        if (kDebugMode) print('[SponsoringService] auto-validation error: $e');
      });

      return docRef.id;
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] createCampaign error: $e');
      rethrow;
    }
  }

  // ─── Read ────────────────────────────────────────────────────────────────

  Future<SponsoringCampaign?> getCampaign(String id) async {
    try {
      final doc = await _db.collection('sponsoring_campaigns').doc(id).get();
      if (!doc.exists) return null;
      return SponsoringCampaign.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getCampaign error: $e');
      return null;
    }
  }

  Stream<List<SponsoringCampaign>> getCampaignsByPrestataire(String prestataireId) {
    try {
      return _db
          .collection('sponsoring_campaigns')
          .where('prestataireId', isEqualTo: prestataireId)
          .orderBy('creeLe', descending: true)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return SponsoringCampaign.fromJson(data);
              }).toList());
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getCampaignsByPrestataire error: $e');
      return Stream.value([]);
    }
  }

  Stream<List<SponsoringCampaign>> getAllCampaigns() {
    try {
      return _db
          .collection('sponsoring_campaigns')
          .orderBy('creeLe', descending: true)
          .limit(100)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return SponsoringCampaign.fromJson(data);
              }).toList());
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getAllCampaigns error: $e');
      return Stream.value([]);
    }
  }

  Stream<List<SponsoringCampaign>> getCampaignsByStatut(CampaignStatut statut) {
    try {
      return _db
          .collection('sponsoring_campaigns')
          .where('statut', isEqualTo: statut.label)
          .orderBy('creeLe', descending: true)
          .limit(50)
          .snapshots()
          .map((snap) => snap.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                return SponsoringCampaign.fromJson(data);
              }).toList());
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getCampaignsByStatut error: $e');
      return Stream.value([]);
    }
  }

  /// Get active sponsored service IDs — used by home screen to sort/filter
  Stream<List<String>> getActiveSponsoredServiceIds() {
    try {
      return _db
          .collection('sponsoring_campaigns')
          .where('statut', isEqualTo: CampaignStatut.active.label)
          .snapshots()
          .map((snap) {
            final now = DateTime.now();
            return snap.docs
                .where((doc) {
                  final data = doc.data();
                  final dateFin = (data['dateFin'] as Timestamp?)?.toDate();
                  return dateFin != null && now.isBefore(dateFin);
                })
                .map((doc) => doc.data()['serviceId'] as String?)
                .where((id) => id != null && id.isNotEmpty)
                .cast<String>()
                .toSet()
                .toList();
          });
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getActiveSponsoredServiceIds error: $e');
      return Stream.value([]);
    }
  }

  // ─── Update ──────────────────────────────────────────────────────────────

  Future<void> updateCampaignStatut(String campaignId, CampaignStatut statut, {String? adminNote}) async {
    try {
      final updates = <String, dynamic>{
        'statut': statut.label,
        'modifieLe': FieldValue.serverTimestamp(),
      };
      if (adminNote != null) updates['adminNote'] = adminNote;
      await _db.collection('sponsoring_campaigns').doc(campaignId).update(updates);

      // If campaign becomes active, update the service document with sponsoring fields
      if (statut == CampaignStatut.active) {
        final doc = await _db.collection('sponsoring_campaigns').doc(campaignId).get();
        if (doc.exists) {
          final campaign = SponsoringCampaign.fromJson({...doc.data()!, 'id': doc.id});
          await _activateServiceSponsoring(campaign);
        }
      } else if (statut == CampaignStatut.suspendue ||
          statut == CampaignStatut.refusee ||
          statut == CampaignStatut.expiree ||
          statut == CampaignStatut.annulee) {
        // Remove sponsoring from the service
        final doc = await _db.collection('sponsoring_campaigns').doc(campaignId).get();
        if (doc.exists) {
          final campaign = SponsoringCampaign.fromJson({...doc.data()!, 'id': doc.id});
          await _deactivateServiceSponsoring(campaign.serviceId, campaignId);
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] updateCampaignStatut error: $e');
      rethrow;
    }
  }

  Future<void> _activateServiceSponsoring(SponsoringCampaign campaign) async {
    try {
      await _db.collection('services').doc(campaign.serviceId).update({
        'sponsorise': true,
        'sponsoringPlan': campaign.plan.label,
        'sponsoringExpireLe': Timestamp.fromDate(campaign.dateFin),
        'sponsoringCampaignId': campaign.id,
      });
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] _activateServiceSponsoring error: $e');
    }
  }

  Future<void> _deactivateServiceSponsoring(String serviceId, String campaignId) async {
    try {
      final doc = await _db.collection('services').doc(serviceId).get();
      if (doc.exists) {
        final data = doc.data()!;
        // Only deactivate if this campaign is the current one
        if (data['sponsoringCampaignId'] == campaignId) {
          await _db.collection('services').doc(serviceId).update({
            'sponsorise': false,
            'sponsoringPlan': FieldValue.delete(),
            'sponsoringExpireLe': FieldValue.delete(),
            'sponsoringCampaignId': FieldValue.delete(),
          });
        }
      }
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] _deactivateServiceSponsoring error: $e');
    }
  }

  Future<void> incrementViews(String campaignId) async {
    try {
      await _db.collection('sponsoring_campaigns').doc(campaignId).update({
        'vues': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] incrementViews error: $e');
    }
  }

  Future<void> incrementClicks(String campaignId) async {
    try {
      await _db.collection('sponsoring_campaigns').doc(campaignId).update({
        'clics': FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] incrementClicks error: $e');
    }
  }

  // ─── Stats ───────────────────────────────────────────────────────────────

  Stream<int> getActiveCampaignsCount() {
    try {
      return _db
          .collection('sponsoring_campaigns')
          .where('statut', isEqualTo: CampaignStatut.active.label)
          .snapshots()
          .map((s) => s.docs.length);
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getActiveCampaignsCount error: $e');
      return Stream.value(0);
    }
  }

  Stream<int> getPendingCampaignsCount() {
    try {
      return _db
          .collection('sponsoring_campaigns')
          .where('statut', isEqualTo: CampaignStatut.enAttente.label)
          .snapshots()
          .map((s) => s.docs.length);
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] getPendingCampaignsCount error: $e');
      return Stream.value(0);
    }
  }

  // ─── Auto-expire ─────────────────────────────────────────────────────────

  /// Check and expire campaigns that have passed their end date
  Future<void> expireOutdatedCampaigns() async {
    try {
      final now = DateTime.now();
      final snap = await _db
          .collection('sponsoring_campaigns')
          .where('statut', isEqualTo: CampaignStatut.active.label)
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        final dateFin = (data['dateFin'] as Timestamp?)?.toDate();
        if (dateFin != null && now.isAfter(dateFin)) {
        } else {
          continue;
        }
        await updateCampaignStatut(doc.id, CampaignStatut.expiree);
      }
    } catch (e) {
      if (kDebugMode) print('[SponsoringService] expireOutdatedCampaigns error: $e');
    }
  }
}
