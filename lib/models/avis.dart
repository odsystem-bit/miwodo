import 'package:cloud_firestore/cloud_firestore.dart';

class Avis {
  final String id;
  final String clientId;
  final String prestataireId;
  final String? commandeId;
  final double note;
  final String? commentaire;
  final DateTime creeLe;

  Avis({
    required this.id,
    required this.clientId,
    required this.prestataireId,
    this.commandeId,
    required this.note,
    this.commentaire,
    required this.creeLe,
  });

  factory Avis.fromJson(Map<String, dynamic> json) {
    return Avis(
      id: json['id'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      prestataireId: json['prestataireId'] as String? ?? '',
      commandeId: json['commandeId'] as String?,
      note: (json['note'] as num?)?.toDouble() ?? 0.0,
      commentaire: json['commentaire'] as String?,
      creeLe: (json['creeLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'prestataireId': prestataireId,
      'commandeId': commandeId,
      'note': note,
      'commentaire': commentaire ?? '',
      'creeLe': Timestamp.fromDate(creeLe),
    };
  }
}
