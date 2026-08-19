// screens/service/service_detail_screen.dart
// Page de détails d'un service — carrousel, infos, prestataire, avis, services similaires
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../models/avis.dart';
import '../../models/prestataire.dart';
import '../../models/service_prestataire.dart';
import '../../services/firebase_service.dart';
import '../../widgets/badge_verifie.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

// ─── Providers ──────────────────────────────────────────────────────────────

final serviceProvider = FutureProvider.family<ServicePrestataire?, String>((ref, id) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('services').doc(id).get();
    if (!doc.exists) return null;
    return ServicePrestataire.fromJson({...doc.data()!, 'id': doc.id});
  } catch (e, st) {
    if (kDebugMode) print('[serviceProvider] error: $e\n$st');
    rethrow;
  }
});

final servicePrestataireProvider = FutureProvider.family<Prestataire?, String>((ref, id) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('prestataires').doc(id).get();
    if (!doc.exists) return null;
    return Prestataire.fromJson({...doc.data()!, 'id': doc.id});
  } catch (e) {
    if (kDebugMode) print('[servicePrestataireProvider] error: $e');
    return null;
  }
});

final serviceAvisProvider = StreamProvider.autoDispose.family<List<Avis>, String>((ref, prestataireId) {
  try {
    return FirebaseFirestore.instance
        .collection('avis')
        .where('prestataireId', isEqualTo: prestataireId)
        .orderBy('creeLe', descending: true)
        .limit(5)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Avis.fromJson(data);
            }).toList())
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (kDebugMode) print('[serviceAvisProvider] error: $error');
              sink.add(<Avis>[]);
            },
          ),
        );
  } catch (e) {
    return Stream.value(<Avis>[]);
  }
});

final similarServicesProvider = StreamProvider.autoDispose.family<List<ServicePrestataire>, String>((ref, prestataireId) {
  try {
    return FirebaseFirestore.instance
        .collection('services')
        .where('prestataireId', isEqualTo: prestataireId)
        .where('actif', isEqualTo: true)
        .orderBy('ordre')
        .limit(6)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return ServicePrestataire.fromJson(data);
            }).toList())
        .transform(
          StreamTransformer.fromHandlers(
            handleError: (error, stack, sink) {
              if (kDebugMode) print('[similarServicesProvider] error: $error');
              sink.add(<ServicePrestataire>[]);
            },
          ),
        );
  } catch (e) {
    return Stream.value(<ServicePrestataire>[]);
  }
});

// ─── Screen ─────────────────────────────────────────────────────────────────

class ServiceDetailScreen extends ConsumerWidget {
  final String id;

  const ServiceDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceAsync = ref.watch(serviceProvider(id));

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: serviceAsync.when(
        loading: () => _buildLoading(),
        error: (e, st) => _buildError(context, ref, e),
        data: (service) {
          if (service == null) {
            return Center(child: Text('Service introuvable', style: GoogleFonts.inter(fontSize: 16)));
          }
          return _buildContent(context, ref, service);
        },
      ),
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          flexibleSpace: Container(color: AppColors.primaryOrange),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                6,
                (_) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Erreur lors du chargement', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(error.toString()),
            const SizedBox(height: 12),
            MiwodoButton(
              label: 'Réessayer',
              variant: MiwodoButtonVariant.secondary,
              onPressed: () => ref.refresh(serviceProvider(id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ServicePrestataire service) {
    final prestataireAsync = ref.watch(servicePrestataireProvider(service.prestataireId));

    return CustomScrollView(
      slivers: [
        // ─── Carrousel d'images ────────────────────────────────────────────
        _buildImageCarousel(context, service),

        // ─── Titre + prix + catégorie ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.nom,
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryOrangeLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        service.prixAffiche,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (service.dureeEstimee != null) ...[
                      const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          service.dureeEstimee!,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        // ─── Description ───────────────────────────────────────────────────
        if (service.description != null && service.description!.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.only(top: 8),
              color: AppColors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Description', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    service.description!,
                    style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ),

        // ─── Infos pratiques (localisation, délai) ─────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Informations', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (service.dureeEstimee != null)
                  _InfoRow(icon: Icons.schedule, label: 'Délai d\'exécution', value: service.dureeEstimee!),
                _InfoRow(
                  icon: Icons.category,
                  label: 'Unité',
                  value: service.unite ?? 'Forfait',
                ),
              ],
            ),
          ),
        ),

        // ─── Section prestataire ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prestataire', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                prestataireAsync.when(
                  data: (prestataire) {
                    if (prestataire == null) {
                      return Text('Informations non disponibles', style: GoogleFonts.inter(color: AppColors.textSecondary));
                    }
                    return _buildPrestataireCard(context, prestataire);
                  },
                  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  error: (e, st) => Text('Erreur', style: GoogleFonts.inter(color: AppColors.errorRed)),
                ),
              ],
            ),
          ),
        ),

        // ─── Réalisations du prestataire ───────────────────────────────────
        SliverToBoxAdapter(
          child: prestataireAsync.when(
            data: (prestataire) {
              if (prestataire == null || prestataire.photosPortfolio.isEmpty) {
                return const SizedBox.shrink();
              }
              return Container(
                margin: const EdgeInsets.only(top: 8),
                color: AppColors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Réalisations', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: prestataire.photosPortfolio.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: prestataire.photosPortfolio[index],
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(color: AppColors.surfaceGray),
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.surfaceGray,
                                child: const Icon(Icons.broken_image, color: AppColors.textSecondary),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
        ),

        // ─── Avis clients ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: prestataireAsync.when(
            data: (prestataire) {
              if (prestataire == null) return const SizedBox.shrink();
              return _buildAvisSection(context, ref, prestataire);
            },
            loading: () => const SizedBox.shrink(),
            error: (e, st) => const SizedBox.shrink(),
          ),
        ),

        // ─── Services similaires ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Services similaires', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Consumer(builder: (context, ref, _) {
                  final similarAsync = ref.watch(similarServicesProvider(service.prestataireId));
                  return similarAsync.when(
                    data: (similar) {
                      final others = similar.where((s) => s.id != service.id).take(4).toList();
                      if (others.isEmpty) {
                        return Text('Aucun autre service', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13));
                      }
                      return SizedBox(
                        height: 160,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: others.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final s = others[index];
                            return _SimilarServiceCard(
                              service: s,
                              onTap: () => context.pushReplacement('/service/${s.id}'),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (e, st) => Text('Erreur', style: GoogleFonts.inter(color: AppColors.errorRed, fontSize: 13)),
                  );
                }),
              ],
            ),
          ),
        ),

        // ─── Boutons d'action ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MiwodoButton(
                        label: 'Contacter',
                        icon: 'assets/icons/ic_message.svg',
                        variant: MiwodoButtonVariant.secondary,
                        onPressed: () => _contactPrestataire(context, service.prestataireId),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MiwodoButton(
                        label: 'Commander',
                        icon: 'assets/icons/ic_shopping_cart.svg',
                        variant: MiwodoButtonVariant.primary,
                        onPressed: () => _orderService(context, service),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _shareService(service),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text('Partager', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: BorderSide(color: AppColors.borderGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  // ─── Carrousel ──────────────────────────────────────────────────────────────

  Widget _buildImageCarousel(BuildContext context, ServicePrestataire service) {
    final images = service.images;

    if (images.isEmpty) {
      return SliverAppBar(
        expandedHeight: 220,
        pinned: true,
        backgroundColor: AppColors.primaryOrangeLight,
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            color: AppColors.primaryOrangeLight,
            child: const Center(
              child: Icon(Icons.handyman, size: 60, color: AppColors.primaryOrange),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => context.pop(),
        ),
      );
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppColors.primaryOrange,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            _ServiceImageCarousel(images: images),
            // Gradient overlay for back button visibility
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withAlpha(120), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.white),
        onPressed: () => context.pop(),
      ),
    );
  }

  // ─── Carte prestataire ──────────────────────────────────────────────────────

  Widget _buildPrestataireCard(BuildContext context, Prestataire prestataire) {
    return InkWell(
      onTap: () => context.push('/prestataire/${prestataire.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            _buildAvatar(prestataire),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${prestataire.prenom} ${prestataire.nom}',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (prestataire.estVerifie) ...[
                        const SizedBox(width: 6),
                        const BadgeVerifie(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const MiwodoSvgIcon('assets/icons/ic_star.svg', size: 14, color: AppColors.primaryOrange),
                      const SizedBox(width: 4),
                      Text(
                        '${prestataire.noteMoyenne.toStringAsFixed(1)} (${prestataire.nombreAvis} avis)',
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const MiwodoSvgIcon('assets/icons/ic_location.svg', size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          prestataire.zone,
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Prestataire p) {
    if (p.photoUrl != null && p.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(imageUrl: p.photoUrl!, width: 56, height: 56, fit: BoxFit.cover),
      );
    }
    final initials = p.nom.isNotEmpty ? p.nom[0].toUpperCase() : 'P';
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(color: AppColors.primaryOrangeLight, shape: BoxShape.circle),
      child: Center(
        child: Text(initials, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
      ),
    );
  }

  // ─── Section avis ───────────────────────────────────────────────────────────

  Widget _buildAvisSection(BuildContext context, WidgetRef ref, Prestataire prestataire) {
    final avisAsync = ref.watch(serviceAvisProvider(prestataire.id));

    return Container(
      margin: const EdgeInsets.only(top: 8),
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Avis clients', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(
                '(${prestataire.nombreAvis})',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const Spacer(),
              if (prestataire.noteMoyenne > 0)
                Row(
                  children: [
                    const MiwodoSvgIcon('assets/icons/ic_star.svg', size: 16, color: AppColors.primaryOrange),
                    const SizedBox(width: 4),
                    Text(
                      prestataire.noteMoyenne.toStringAsFixed(1),
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          avisAsync.when(
            data: (avis) {
              if (avis.isEmpty) {
                return Text('Aucun avis pour le moment', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13));
              }
              return Column(
                children: avis.map((a) {
                  final initials = a.clientId.isNotEmpty ? a.clientId[0].toUpperCase() : 'U';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryOrangeLight,
                          child: Text(initials, style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(a.clientId, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                                  Text(DateFormat.yMMMd().format(a.creeLe), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 11)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(
                                  5,
                                  (i) => Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: MiwodoSvgIcon(
                                      i < a.note.round() ? 'assets/icons/ic_star.svg' : 'assets/icons/ic_star_empty.svg',
                                      size: 12,
                                      color: i < a.note.round() ? AppColors.primaryOrange : AppColors.borderGray,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if ((a.commentaire ?? '').isNotEmpty)
                                Text(a.commentaire!, style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, st) => Text('Erreur chargement avis', style: GoogleFonts.inter(color: AppColors.errorRed, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Actions ────────────────────────────────────────────────────────────────

  void _contactPrestataire(BuildContext context, String prestataireId) {
    final user = FirebaseService.instance.auth.currentUser;
    if (user != null) {
      final ids = [user.uid, prestataireId]..sort();
      context.push('/messages/${ids[0]}_${ids[1]}');
    } else {
      context.push('/contact/$prestataireId');
    }
  }

  void _orderService(BuildContext context, ServicePrestataire service) {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Connectez-vous pour commander ce service'),
          action: SnackBarAction(label: 'Connexion', onPressed: () => context.push('/login')),
        ),
      );
      return;
    }
    // Rediriger vers la conversation avec un message pré-rempli
    final ids = [user.uid, service.prestataireId]..sort();
    context.push('/messages/${ids[0]}_${ids[1]}');
  }

  void _shareService(ServicePrestataire service) {
    final text = '${service.nom} — ${service.prixAffiche}\n\n${service.description ?? ''}\n\nDécouvrez ce service sur Miwodo!';
    Share.share(text, subject: 'Service Miwodo: ${service.nom}');
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text('$label : ', style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceImageCarousel extends StatefulWidget {
  final List<String> images;

  const _ServiceImageCarousel({required this.images});

  @override
  State<_ServiceImageCarousel> createState() => _ServiceImageCarouselState();
}

class _ServiceImageCarouselState extends State<_ServiceImageCarousel> {
  int _currentPage = 0;
  late PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controller,
          itemCount: widget.images.length,
          onPageChanged: (i) => setState(() => _currentPage = i),
          itemBuilder: (context, index) {
            return CachedNetworkImage(
              imageUrl: widget.images[index],
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.surfaceGray,
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.surfaceGray,
                child: const Center(child: Icon(Icons.broken_image, color: AppColors.textSecondary, size: 40)),
              ),
            );
          },
        ),
        // Page indicator dots
        if (widget.images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.images.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentPage ? AppColors.white : AppColors.white.withAlpha(100),
                  ),
                ),
              ),
            ),
          ),
        // Image counter
        if (widget.images.length > 1)
          Positioned(
            top: 90,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_currentPage + 1}/${widget.images.length}',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _SimilarServiceCard extends StatelessWidget {
  final ServicePrestataire service;
  final VoidCallback onTap;

  const _SimilarServiceCard({required this.service, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasImage = service.images.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderGray),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 90,
              width: double.infinity,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: service.images.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: AppColors.surfaceGray),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.surfaceGray,
                        child: const Center(child: Icon(Icons.broken_image, color: AppColors.textSecondary, size: 24)),
                      ),
                    )
                  : Container(
                      color: AppColors.primaryOrangeLight,
                      child: const Center(child: Icon(Icons.handyman, color: AppColors.primaryOrange, size: 24)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.nom,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.prixAffiche,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
