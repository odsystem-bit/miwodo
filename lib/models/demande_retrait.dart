import 'package:cloud_firestore/cloud_firestore.dart';

enum RetraitStatut {
  enAttente,
  approuve,
  refuse,
  paye;

  String get label {
    switch (this) {
      case RetraitStatut.enAttente:
        return 'En attente';
      case RetraitStatut.approuve:
        return 'Approuvé';
      case RetraitStatut.refuse:
        return 'Refusé';
      case RetraitStatut.paye:
        return 'Payé';
    }
  }

  int get colorValue {
    switch (this) {
      case RetraitStatut.enAttente:
        return 0xFFFFA000;
      case RetraitStatut.approuve:
        return 0xFF4CAF50;
      case RetraitStatut.refuse:
        return 0xFFE53935;
      case RetraitStatut.paye:
        return 0xFF2196F3;
    }
  }
}

enum RetraitSource {
  parrainage,
  soldeVendeur,
  soldeLivreur;

  String get label {
    switch (this) {
      case RetraitSource.parrainage:
        return 'Parrainage';
      case RetraitSource.soldeVendeur:
        return 'Solde vendeur';
      case RetraitSource.soldeLivreur:
        return 'Solde livreur';
    }
  }
}

enum MethodePaiement {
  mobileMoney,
  virementBancaire,
  cash;

  String get label {
    switch (this) {
      case MethodePaiement.mobileMoney:
        return 'Mobile Money';
      case MethodePaiement.virementBancaire:
        return 'Virement bancaire';
      case MethodePaiement.cash:
        return 'Cash (agence)';
    }
  }
}

class DemandeRetrait {
  final String id;
  final String prestataireId;
  final String prestataireNom;
  final RetraitSource source;
  final int montant;
  final String devise;
  final MethodePaiement methodePaiement;
  final String numeroDestinataire;
  final String? nomDestinataire;
  final RetraitStatut statut;
  final String? raisonRefus;
  final String? adminId;
  final String? adminNom;
  final DateTime creeLe;
  final DateTime? traiteLe;

  DemandeRetrait({
    required this.id,
    required this.prestataireId,
    required this.prestataireNom,
    required this.source,
    required this.montant,
    required this.devise,
    required this.methodePaiement,
    required this.numeroDestinataire,
    this.nomDestinataire,
    this.statut = RetraitStatut.enAttente,
    this.raisonRefus,
    this.adminId,
    this.adminNom,
    required this.creeLe,
    this.traiteLe,
  });

  factory DemandeRetrait.fromJson(Map<String, dynamic> json, String docId) {
    return DemandeRetrait(
      id: docId,
      prestataireId: json['prestataire_id'] as String? ?? '',
      prestataireNom: json['prestataire_nom'] as String? ?? '',
      source: RetraitSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => RetraitSource.parrainage,
      ),
      montant: (json['montant'] as num?)?.toInt() ?? 0,
      devise: json['devise'] as String? ?? 'XOF',
      methodePaiement: MethodePaiement.values.firstWhere(
        (e) => e.name == json['methode_paiement'],
        orElse: () => MethodePaiement.mobileMoney,
      ),
      numeroDestinataire: json['numero_destinataire'] as String? ?? '',
      nomDestinataire: json['nom_destinataire'] as String?,
      statut: RetraitStatut.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => RetraitStatut.enAttente,
      ),
      raisonRefus: json['raison_refus'] as String?,
      adminId: json['admin_id'] as String?,
      adminNom: json['admin_nom'] as String?,
      creeLe: (json['cree_le'] as Timestamp?)?.toDate() ?? DateTime.now(),
      traiteLe: (json['traite_le'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prestataire_id': prestataireId,
      'prestataire_nom': prestataireNom,
      'source': source.name,
      'montant': montant,
      'devise': devise,
      'methode_paiement': methodePaiement.name,
      'numero_destinataire': numeroDestinataire,
      'nom_destinataire': nomDestinataire,
      'statut': statut.name,
      'raison_refus': raisonRefus,
      'admin_id': adminId,
      'admin_nom': adminNom,
      'cree_le': Timestamp.fromDate(creeLe),
      'traite_le': traiteLe != null ? Timestamp.fromDate(traiteLe!) : null,
    };
  }
}
