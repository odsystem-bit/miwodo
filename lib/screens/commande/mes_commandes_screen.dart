// screens/commande/mes_commandes_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/commande.dart';
import '../../services/firebase_service.dart';

final clientCommandesProvider = StreamProvider<List<CommandeVendeur>>((ref) {
  final user = FirebaseService.instance.auth.currentUser;
  if (user == null) return const Stream<List<CommandeVendeur>>.empty();

  return FirebaseService.instance.firestore
      .collection('commandes')
      .where('client_uid', isEqualTo: user.uid)
      .snapshots()
      .map((snapshot) {
    final list = snapshot.docs.map((doc) {
      final data = doc.data();
      return CommandeVendeur.fromJson(data, doc.id);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  });
});

class MesCommandesScreen extends ConsumerWidget {
  const MesCommandesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commandesAsync = ref.watch(clientCommandesProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: Text(
          'Mes commandes',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: SvgPicture.asset(
            'assets/icons/ic_arrow_back.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              AppColors.textPrimary,
              BlendMode.srcIn,
            ),
          ),
          onPressed: () => context.go('/accueil'),
        ),
      ),
      body: commandesAsync.when(
        data: (commandes) {
          if (commandes.isEmpty) {
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: commandes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final cmd = commandes[index];
              return _CommandeCard(commande: cmd);
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primaryOrange),
        ),
        error: (e, _) => Center(
          child: Text(
            'Erreur: $e',
            style: GoogleFonts.inter(color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryOrangeLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/ic_orders.svg',
                  width: 36,
                  height: 36,
                  colorFilter: const ColorFilter.mode(
                    AppColors.primaryOrange,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucune commande',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vos commandes apparaîtront ici',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandeCard extends StatelessWidget {
  final CommandeVendeur commande;

  const _CommandeCard({required this.commande});

  Color get _statutColor {
    switch (commande.statut) {
      case StatutCommande.paye:
        return AppColors.infoBlue;
      case StatutCommande.accepte:
      case StatutCommande.enRoute:
        return AppColors.warningYellow;
      case StatutCommande.livre:
      case StatutCommande.confirme:
      case StatutCommande.forceConfirme:
        return AppColors.successGreen;
      case StatutCommande.litige:
        return AppColors.errorRed;
      case StatutCommande.rembourse:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/suivi-commande/${commande.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Commande #${commande.numero}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statutColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    commande.statut.label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statutColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_user.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    commande.vendeurBoutiqueNom ?? commande.vendeurNom,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/ic_location.svg',
                  width: 14,
                  height: 14,
                  colorFilter: const ColorFilter.mode(
                    AppColors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    commande.clientZone,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${commande.articles.length} article(s)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${commande.totalClient} F',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryOrange,
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
