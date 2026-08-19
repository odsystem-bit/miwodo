// models/transaction_record.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionRecord {
  final String id;
  final String paymentId;
  final String type;
  final double montant;
  final DateTime createdAt;

  TransactionRecord({
    required this.id,
    required this.paymentId,
    required this.type,
    required this.montant,
    required this.createdAt,
  });

  factory TransactionRecord.fromJson(Map<String, dynamic> json) {
    return TransactionRecord(
      id: json['id'] as String,
      paymentId: json['paymentId'] as String? ?? '',
      type: json['type'] as String? ?? 'inconnu',
      montant: (json['montant'] as num?)?.toDouble() ?? 0.0,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentId': paymentId,
      'type': type,
      'montant': montant,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
