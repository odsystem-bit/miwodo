import 'package:cloud_firestore/cloud_firestore.dart';

class Produit {
  final String id;
  final String prestataireId;
  final String nom;
  final String? description;
  final double prix;
  final String? imageUrl;
  final List<String> images;
  final String categorie;
  final bool estDisponible;
  final DateTime creeLe;

  Produit({
    required this.id,
    required this.prestataireId,
    required this.nom,
    this.description,
    required this.prix,
    this.imageUrl,
    this.images = const [],
    required this.categorie,
    this.estDisponible = true,
    required this.creeLe,
  });

  factory Produit.fromJson(Map<String, dynamic> json) {
    return Produit(
      id: json['id'] as String? ?? '',
      prestataireId: json['prestataireId'] as String? ?? json['prestataire_id'] as String? ?? '',
      nom: json['nom'] as String? ?? '',
      description: json['description'] as String?,
      prix: (json['prix'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      categorie: json['categorie'] as String? ?? '',
      estDisponible: json['estDisponible'] as bool? ?? true,
      creeLe: (json['creeLe'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'prestataireId': prestataireId,
      'nom': nom,
      'description': description,
      'prix': prix,
      'imageUrl': imageUrl,
      'images': images,
      'categorie': categorie,
      'estDisponible': estDisponible,
      'creeLe': Timestamp.fromDate(creeLe),
    };
  }
}
