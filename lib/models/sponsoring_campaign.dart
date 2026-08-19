// models/sponsoring_campaign.dart
// Modèle pour les campagnes de sponsoring de services

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum CampaignStatut {
  enAttente, // En attente de validation admin
  active, // Validée et active
  suspendue, // Suspendue par admin
  refusee, // Refusée par admin
  expiree, // Expirée (date dépassée)
  annulee, // Annulée par le prestataire
}

extension CampaignStatutX on CampaignStatut {
  String get label {
    switch (this) {
      case CampaignStatut.enAttente:
        return 'en_attente';
      case CampaignStatut.active:
        return 'active';
      case CampaignStatut.suspendue:
        return 'suspendue';
      case CampaignStatut.refusee:
        return 'refusee';
      case CampaignStatut.expiree:
        return 'expiree';
      case CampaignStatut.annulee:
        return 'annulee';
    }
  }

  String get displayLabel {
    switch (this) {
      case CampaignStatut.enAttente:
        return 'En attente';
      case CampaignStatut.active:
        return 'Active';
      case CampaignStatut.suspendue:
        return 'Suspendue';
      case CampaignStatut.refusee:
        return 'Refusée';
      case CampaignStatut.expiree:
        return 'Expirée';
      case CampaignStatut.annulee:
        return 'Annulée';
    }
  }

  Color get color {
    switch (this) {
      case CampaignStatut.enAttente:
        return const Color(0xFFF59E0B); // amber
      case CampaignStatut.active:
        return const Color(0xFF22C55E); // green
      case CampaignStatut.suspendue:
        return const Color(0xFFEF4444); // red
      case CampaignStatut.refusee:
        return const Color(0xFFEF4444); // red
      case CampaignStatut.expiree:
        return const Color(0xFF9CA3AF); // gray
      case CampaignStatut.annulee:
        return const Color(0xFF9CA3AF); // gray
    }
  }

  static CampaignStatut fromString(String? value) {
    switch (value) {
      case 'en_attente':
        return CampaignStatut.enAttente;
      case 'active':
        return CampaignStatut.active;
      case 'suspendue':
        return CampaignStatut.suspendue;
      case 'refusee':
        return CampaignStatut.refusee;
      case 'expiree':
        return CampaignStatut.expiree;
      case 'annulee':
        return CampaignStatut.annulee;
      default:
        return CampaignStatut.enAttente;
    }
  }
}

enum SponsoringPlan {
  standard,
  premium,
}

extension SponsoringPlanX on SponsoringPlan {
  String get label {
    switch (this) {
      case SponsoringPlan.standard:
        return 'standard';
      case SponsoringPlan.premium:
        return 'premium';
    }
  }

  String get displayLabel {
    switch (this) {
      case SponsoringPlan.standard:
        return 'STANDARD';
      case SponsoringPlan.premium:
        return 'PREMIUM';
    }
  }

  static SponsoringPlan fromString(String? value) {
    switch (value) {
      case 'premium':
        return SponsoringPlan.premium;
      default:
        return SponsoringPlan.standard;
    }
  }
}

class SponsoringCampaign {
  final String id;
  final String serviceId;
  final String serviceName;
  final String prestataireId;
  final String prestataireNom;
  final SponsoringPlan plan;
  final int montant;
  final String devise;
  final String? paymentId;
  final CampaignStatut statut;
  final DateTime dateDebut;
  final DateTime dateFin;
  final DateTime creeLe;
  final DateTime? modifieLe;
  final String? adminNote;
  final int vues; // Nombre de vues de la campagne
  final int clics; // Nombre de clics

  const SponsoringCampaign({
    required this.id,
    required this.serviceId,
    required this.serviceName,
    required this.prestataireId,
    required this.prestataireNom,
    required this.plan,
    required this.montant,
    required this.devise,
    this.paymentId,
    required this.statut,
    required this.dateDebut,
    required this.dateFin,
    required this.creeLe,
    this.modifieLe,
    this.adminNote,
    this.vues = 0,
    this.clics = 0,
  });

  factory SponsoringCampaign.fromJson(Map<String, dynamic> json) {
    return SponsoringCampaign(
      id: json['id'] as String? ?? '',
      serviceId: json['serviceId'] as String? ?? '',
      serviceName: json['serviceName'] as String? ?? '',
      prestataireId: json['prestataireId'] as String? ?? '',
      prestataireNom: json['prestataireNom'] as String? ?? '',
      plan: SponsoringPlanX.fromString(json['plan'] as String?),
      montant: (json['montant'] as num?)?.toInt() ?? 0,
      devise: json['devise'] as String? ?? 'XOF',
      paymentId: json['paymentId'] as String?,
      statut: CampaignStatutX.fromString(json['statut'] as String?),
      dateDebut: (json['dateDebut'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateFin: (json['dateFin'] as Timestamp?)?.toDate() ?? DateTime.now(),
      creeLe: (json['creeLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modifieLe: (json['modifieLe'] as Timestamp?)?.toDate(),
      adminNote: json['adminNote'] as String?,
      vues: (json['vues'] as num?)?.toInt() ?? 0,
      clics: (json['clics'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'prestataireId': prestataireId,
      'prestataireNom': prestataireNom,
      'plan': plan.label,
      'montant': montant,
      'devise': devise,
      'paymentId': paymentId,
      'statut': statut.label,
      'dateDebut': Timestamp.fromDate(dateDebut),
      'dateFin': Timestamp.fromDate(dateFin),
      'creeLe': Timestamp.fromDate(creeLe),
      'modifieLe': modifieLe != null ? Timestamp.fromDate(modifieLe!) : null,
      'adminNote': adminNote,
      'vues': vues,
      'clics': clics,
    };
  }

  bool get isExpired => DateTime.now().isAfter(dateFin);
  bool get isActive => statut == CampaignStatut.active && !isExpired;
  int get joursRestants {
    final diff = dateFin.difference(DateTime.now());
    return diff.inDays > 0 ? diff.inDays : 0;
  }
}
