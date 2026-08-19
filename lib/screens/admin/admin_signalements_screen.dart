// screens/admin/admin_signalements_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/signalement.dart';
import '../../services/firestore_service.dart';
import 'admin_shell.dart';

class AdminSignalementsScreen extends ConsumerStatefulWidget {
  const AdminSignalementsScreen({super.key});

  @override
  AdminSignalementsScreenState createState() => AdminSignalementsScreenState();
}

class AdminSignalementsScreenState
    extends ConsumerState<AdminSignalementsScreen> {
  String statut = 'ouvert';

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Signalements',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Ouverts'),
                  selected: statut == 'ouvert',
                  selectedColor: AppColors.primaryOrange.withAlpha(46),
                  onSelected: (_) => setState(() => statut = 'ouvert'),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Traités'),
                  selected: statut == 'traite',
                  selectedColor: AppColors.primaryOrange.withAlpha(46),
                  onSelected: (_) => setState(() => statut = 'traite'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(child: _buildSignalementList(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalementList(BuildContext context) {
    return StreamBuilder<List<Signalement>>(
      stream: FirestoreService.instance.getSignalements(statut: statut),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Text(
            'Aucun signalement pour ce statut.',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          );
        }
        return ListView.separated(
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final item = list[index];
            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item.motif,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.statut.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: AppColors.primaryOrange,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Prestataire: ${item.prestataireId}',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.details,
                      style: GoogleFonts.inter(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            if (context.mounted) {
                              context.go('/prestataire/${item.prestataireId}');
                            }
                          },
                          child: const Text('Voir profil'),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            await FirestoreService.instance.suspendPrestataire(
                              item.prestataireId,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Prestataire suspendu.'),
                                ),
                              );
                            }
                          },
                          child: const Text('Suspendre prestataire'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange,
                          ),
                          onPressed: () async {
                            await FirestoreService.instance
                                .updateSignalementStatus(item.id, 'traite');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Signalement clos.'),
                                ),
                              );
                            }
                          },
                          child: const Text(
                            'Clore sans suite',
                            style: TextStyle(color: AppColors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
