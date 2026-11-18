// screens/prestataire/mes_produits_screen.dart
// Écran de gestion des produits pour les vendeurs

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../models/produit.dart';
import '../../services/supabase_service.dart';
import '../../widgets/miwodo_svg_icon.dart';
import '../commander/produit_detail_modal.dart';

// Provider pour les produits d'un vendeur
final produitsProvider = StreamProvider.family<List<Produit>, String>((ref, prestataireId) {
  return FirebaseFirestore.instance
      .collection('produits')
      .where('prestataireId', isEqualTo: prestataireId)
      .limit(50)
      .snapshots()
      .map((snap) {
        final list = snap.docs.map((d) => Produit.fromJson({...d.data(), 'id': d.id})).toList();
        list.sort((a, b) => b.creeLe.compareTo(a.creeLe));
        return list;
      });
});

// Provider pour le prestataire connecté
final currentPrestataireProvider = StreamProvider.family<Prestataire?, String>((ref, uid) {
  return FirebaseFirestore.instance
      .collection('prestataires')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.exists ? Prestataire.fromJson({...snap.data()!, 'id': snap.id}) : null);
});

class MesProduitsScreen extends ConsumerStatefulWidget {
  final String prestataireId;

  const MesProduitsScreen({super.key, required this.prestataireId});

  @override
  ConsumerState<MesProduitsScreen> createState() => _MesProduitsScreenState();
}

class _MesProduitsScreenState extends ConsumerState<MesProduitsScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  Widget build(BuildContext context) {
    final produitsAsync = ref.watch(produitsProvider(widget.prestataireId));
    final prestataireAsync = ref.watch(currentPrestataireProvider(widget.prestataireId));

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        title: Text(
          'Mes Produits',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primaryOrange),
            onPressed: () => _showProduitDialog(context, null, prestataireAsync.value),
            tooltip: 'Ajouter un produit',
          ),
        ],
      ),
      body: produitsAsync.when(
        data: (produits) {
          if (produits.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MiwodoSvgIcon(
                    'assets/icons/ic_cart.svg',
                    size: 64,
                    color: AppColors.borderGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun produit',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ajoutez votre premier produit',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: produits.length,
            itemBuilder: (context, index) {
              final produit = produits[index];
              return _ProduitCard(
                produit: produit,
                onTap: () => showProduitDetailSheet(
                  context,
                  produit: produit,
                  vendeur: prestataireAsync.value,
                ),
                onEdit: () => _showProduitDialog(context, produit, prestataireAsync.value),
                onDelete: () => _deleteProduit(produit),
                onToggle: () => _toggleProduit(produit),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(
            'Erreur: $error',
            style: GoogleFonts.inter(color: AppColors.errorRed),
          ),
        ),
      ),
    );
  }

  void _showProduitDialog(BuildContext context, Produit? produit, Prestataire? prestataire) {
    final nomController = TextEditingController(text: produit?.nom ?? '');
    final descriptionController = TextEditingController(text: produit?.description ?? '');
    final prixController = TextEditingController(text: produit?.prix.toString() ?? '');
    final categorieController = TextEditingController(text: produit?.categorie ?? '');
    File? imageFile;
    String? imageUrl = produit?.imageUrl;
    bool dialogSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              produit == null ? 'Ajouter un produit' : 'Modifier le produit',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image picker
                  GestureDetector(
                    onTap: () async {
                      final pickedFile = await _picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      if (pickedFile != null) {
                        setState(() {
                          imageFile = File(pickedFile.path);
                        });
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGray,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(imageFile!, fit: BoxFit.cover),
                            )
                          : imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                    errorWidget: (context, url, error) => const Center(
                                      child: Icon(Icons.image, color: AppColors.borderGray),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate, color: AppColors.borderGray),
                                      SizedBox(height: 8),
                                      Text(
                                        'Ajouter une photo',
                                        style: TextStyle(color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du produit *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: prixController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Prix (${prestataire?.symbole ?? 'F CFA'}) *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categorieController,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie *',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: Alimentation, Électronique, Mode...',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nomController.text.isEmpty || prixController.text.isEmpty || categorieController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez remplir tous les champs obligatoires')),
                    );
                    return;
                  }

                  setState(() => dialogSaving = true);

                  try {
                    String? uploadedUrl = imageUrl;

                    // Upload nouvelle image
                    if (imageFile != null) {
                      try {
                        final fileName = 'produits/${widget.prestataireId}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                        uploadedUrl = await SupabaseService.uploadPhoto(
                          bucket: 'miwodo-photos',
                          path: fileName,
                          file: imageFile!,
                        );
                      } catch (e) {
                        debugPrint('Upload image produit échoué: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Erreur upload image: $e'),
                              backgroundColor: AppColors.errorRed,
                            ),
                          );
                        }
                      }
                    }

                    final data = <String, dynamic>{
                      'prestataireId': widget.prestataireId,
                      'nom': nomController.text.trim(),
                      'prix': double.parse(prixController.text.trim()),
                      'imageUrl': uploadedUrl,
                      'images': uploadedUrl != null ? [uploadedUrl] : [],
                      'categorie': categorieController.text.trim(),
                      'estDisponible': true,
                      'creeLe': produit?.creeLe ?? FieldValue.serverTimestamp(),
                    };
                    if (descriptionController.text.trim().isNotEmpty) {
                      data['description'] = descriptionController.text.trim();
                    }

                    if (produit == null) {
                      await FirebaseFirestore.instance.collection('produits').add(data);
                    } else {
                      await FirebaseFirestore.instance.collection('produits').doc(produit.id).update(data);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(produit == null ? 'Produit ajouté' : 'Produit modifié'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur: $e'),
                          backgroundColor: AppColors.errorRed,
                        ),
                      );
                    }
                  } finally {
                    setState(() => dialogSaving = false);
                  }
                },
                child: dialogSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteProduit(Produit produit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Voulez-vous vraiment supprimer "${produit.nom}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('produits').doc(produit.id).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produit supprimé'), backgroundColor: AppColors.successGreen),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  Future<void> _toggleProduit(Produit produit) async {
    try {
      await FirebaseFirestore.instance.collection('produits').doc(produit.id).update({
        'estDisponible': !produit.estDisponible,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    }
  }
}

class _ProduitCard extends StatelessWidget {
  final Produit produit;
  final VoidCallback? onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;

  const _ProduitCard({
    required this.produit,
    this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: produit.imageUrl != null && produit.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: produit.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surfaceGray,
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.surfaceGray,
                          child: const Icon(Icons.image, color: AppColors.borderGray),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.surfaceGray,
                        child: const Icon(Icons.image, color: AppColors.borderGray),
                      ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produit.nom,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      produit.categorie,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (produit.description?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        produit.description!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      '${produit.prix.toStringAsFixed(0)} F CFA',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: produit.estDisponible ? AppColors.successGreen : AppColors.errorRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            produit.estDisponible ? 'Disponible' : 'Indisponible',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              color: AppColors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    onEdit();
                    break;
                  case 'toggle':
                    onToggle();
                    break;
                  case 'delete':
                    onDelete();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 18),
                      SizedBox(width: 8),
                      Text('Activer/Désactiver'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: AppColors.errorRed),
                      SizedBox(width: 8),
                      Text('Supprimer', style: TextStyle(color: AppColors.errorRed)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
