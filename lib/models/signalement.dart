// models/signalement.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Signalement {
  final String id;
  final String prestataireId;
  final String signaleurTel;
  final String motif;
  final String details;
  final String statut;
  final DateTime createdAt;

  Signalement({
    required this.id,
    required this.prestataireId,
    required this.signaleurTel,
    required this.motif,
    required this.details,
    this.statut = 'ouvert',
    required this.createdAt,
  });

  factory Signalement.fromJson(Map<String, dynamic> json) {
    return Signalement(
      id: json['id'] as String? ?? '',
      prestataireId: json['prestataire_id'] as String? ?? '',
      signaleurTel: json['signaleur_tel'] as String? ?? '',
      motif: json['motif'] as String? ?? '',
      details: json['details'] as String? ?? '',
      statut: json['statut'] as String? ?? 'ouvert',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prestataire_id': prestataireId,
      'signaleur_tel': signaleurTel,
      'motif': motif,
      'details': details,
      'statut': statut,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
