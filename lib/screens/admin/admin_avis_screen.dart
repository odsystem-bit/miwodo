// screens/admin/admin_avis_screen.dart
// Modération des avis — voir et supprimer les avis inappropriés
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/avis.dart';
import '../../services/firestore_service.dart';
import 'admin_shell.dart';

class AdminAvisScreen extends ConsumerWidget {
  const AdminAvisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminShell(
      title: 'Modération avis',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Avis récents',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Supprimez les avis inappropriés ou frauduleux',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<Avis>>(
                stream: FirestoreService.instance.getAllAvis(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Text(
                      'Aucun avis à modérer.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    );
                  }
                  return ListView.separated(
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final avis = list[index];
                      return _AvisCard(avis: avis);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvisCard extends StatelessWidget {
  final Avis avis;

  const _AvisCard({required this.avis});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Étoiles
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < avis.note ? Icons.star : Icons.star_border,
                      size: 16,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(avis.creeLe),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              avis.commentaire ?? '(Aucun commentaire)',
              style: GoogleFonts.inter(fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Prestataire: ${avis.prestataireId.substring(0, 8)}...',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context, avis),
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                  label: Text(
                    'Supprimer',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.errorRed, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _confirmDelete(BuildContext context, Avis avis) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer cet avis ?', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Cette action est irréversible.',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: GoogleFonts.inter()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
            onPressed: () async {
              await FirestoreService.instance.deleteAvis(avis.id);
              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Avis supprimé ✓')),
                );
              }
            },
            child: Text('Supprimer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
