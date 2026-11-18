import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUser {
  final String uid;
  final String email;
  final String nom;
  final String role;
  final String? zone;
  final DateTime createdAt;
  final bool actif;

  AdminUser({
    required this.uid,
    required this.email,
    required this.nom,
    required this.role,
    this.zone,
    required this.createdAt,
    this.actif = true,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      uid: json['uid'] as String,
      email: json['email'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      role: json['role'] as String? ?? 'moderateur',
      zone: json['zone'] as String?,
      actif: json['actif'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'nom': nom,
      'role': role,
      'zone': zone,
      'createdAt': Timestamp.fromDate(createdAt),
      'actif': actif,
    };
  }
}
