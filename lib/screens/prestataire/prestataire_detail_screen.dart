// screens/prestataire/prestataire_detail_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../models/avis.dart';
import '../../models/prestataire.dart';
import '../../models/service_prestataire.dart';
import '../../models/signalement.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/badge_verifie.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

final prestataireProvider = FutureProvider.family<Prestataire?, String>(
  (ref, id) => FirestoreService.instance.getPrestataire(id),
);

final avisProvider = StreamProvider.autoDispose.family<List<Avis>, String>(
  (ref, id) {
    try {
      final query = FirebaseFirestore.instance
          .collection('avis')
          .where('prestataireId', isEqualTo: id)
          .orderBy('creeLe', descending: true)
          .limit(5);
      return query.snapshots().map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Avis.fromJson(data);
        }).toList();
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[avisProvider] error: $error');
            sink.add(<Avis>[]);
          },
        ),
      );
    } catch (e) {
      return Stream.value([]);
    }
  },
);

final servicesProvider = StreamProvider.autoDispose.family<List<ServicePrestataire>, String>(
  (ref, id) {
    try {
      final query = FirebaseFirestore.instance
          .collection('services')
          .where('prestataireId', isEqualTo: id)
          .where('actif', isEqualTo: true)
          .orderBy('ordre')
          .limit(50);
      return query.snapshots().map((snap) {
        return snap.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ServicePrestataire.fromJson(data);
        }).toList();
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[servicesProvider] error: $error');
            sink.add(<ServicePrestataire>[]);
          },
        ),
      );
    } catch (e) {
      return Stream.value([]);
    }
  },
);

final descriptionExpandedProvider = StateProvider.family<bool, String>((ref, id) => false);
final reviewRatingProvider = StateProvider.family<int, String>((ref, id) => 0);
final reviewCommentProvider = StateProvider.family<String, String>((ref, id) => '');
final reviewSubmittingProvider = StateProvider.family<bool, String>((ref, id) => false);

class PrestataireDetailScreen extends ConsumerWidget {
  final String id;

  const PrestataireDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prestataireAsync = ref.watch(prestataireProvider(id));

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: prestataireAsync.when(
        loading: () => _buildLoading(),
        error: (e, st) => _buildError(context, ref, e),
        data: (prestataire) {
          if (prestataire == null) {
            return Center(child: Text('Prestataire introuvable'));
          }
          return _buildContent(context, ref, prestataire);
        },
      ),
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          flexibleSpace: Shimmer.fromColors(
            baseColor: Colors.grey.shade300,
            highlightColor: Colors.grey.shade100,
            child: Container(color: AppColors.primaryOrange, height: 220),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                6,
                (_) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(height: 56, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
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
              onPressed: () => ref.refresh(prestataireProvider(id)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, Prestataire prestataire) {
    final avisAsync = ref.watch(avisProvider(id));
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: AppColors.primaryOrange,
          actions: [
            IconButton(
              onPressed: () {
                Share.share('Découvrez ce prestataire sur Miwodo : https://miwodo.tg/prestataire/${prestataire.id}');
              },
              icon: const MiwodoSvgIcon('assets/icons/ic_share.svg', size: 20, color: AppColors.white),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              color: AppColors.primaryOrange,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeaderAvatar(prestataire),
                  const SizedBox(height: 8),
                  Text(
                    '${prestataire.nom} ${prestataire.prenom}',
                    style: GoogleFonts.inter(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _categoryLabel(prestataire),
                    style: GoogleFonts.inter(color: AppColors.white.withAlpha(204), fontSize: 14, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (prestataire.estDisponible)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.successGreen.withAlpha(30), borderRadius: BorderRadius.circular(999)),
                          child: Text('Disponible', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.successGreen)),
                        ),
                      if (prestataire.estVerifie) const BadgeVerifie(),
                      if (prestataire.estVerifie)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primaryOrange, borderRadius: BorderRadius.circular(999)),
                          child: Text('SPONSORISÉ', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.white)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Actions (Message In-App prioritaire / Call secondaire)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: MiwodoButton(
                    label: 'Envoyer un message',
                    icon: 'assets/icons/ic_chat.svg',
                    variant: MiwodoButtonVariant.primary,
                    onPressed: () {
                      final user = FirebaseService.instance.auth.currentUser;
                      if (user != null) {
                        // Utilisateur connecté : conversation normale in-app
                        final ids = [user.uid, prestataire.id]..sort();
                        context.push('/messages/${ids[0]}_${ids[1]}');
                      } else {
                        // Invité sans compte : formulaire de contact direct in-app
                        context.push('/contact/${prestataire.id}');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: MiwodoButton(
                    label: 'Appeler',
                    icon: 'assets/icons/ic_phone.svg',
                    variant: MiwodoButtonVariant.secondary,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final tel = prestataire.telephone;
                      if (tel.isEmpty) {
                        messenger.showSnackBar(const SnackBar(content: Text('Téléphone non disponible')));
                        return;
                      }
                      final normalized = tel.startsWith('+') ? tel : '+228$tel';
                      final uri = Uri(scheme: 'tel', path: normalized);
                      try {
                        await launchUrl(uri);
                      } catch (e) {
                        messenger.showSnackBar(const SnackBar(content: Text("Impossible de lancer l'appel")));
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        // Infos card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tarif', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text('Non renseigné', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [const MiwodoSvgIcon('assets/icons/ic_location.svg', size: 16, color: Color(0xFF9CA3AF)), const SizedBox(width: 8), Text(prestataire.zone, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500))]),
                        const SizedBox(height: 8),
                        Text(prestataire.estDisponible ? 'Disponible' : 'Occupé', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: prestataire.estDisponible ? AppColors.successGreen : AppColors.errorRed)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Description
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('À propos', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Builder(builder: (context) {
                  final expanded = ref.watch(descriptionExpandedProvider(id));
                  final description = prestataire.description ?? '';
                  final needsExpand = description.length > 180;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        description,
                        maxLines: expanded ? 999 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary),
                      ),
                      if (needsExpand)
                        TextButton(
                          onPressed: () => ref.read(descriptionExpandedProvider(id).notifier).state = !ref.read(descriptionExpandedProvider(id)),
                          child: Text(ref.read(descriptionExpandedProvider(id)) ? 'Voir moins' : 'Voir plus'),
                        ),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),

        // Carrousel des réalisations
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Réalisations', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (prestataire.photosPortfolio.isEmpty)
                  Container(
                    height: 180,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library, size: 40, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          Text('Aucune réalisation', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14)),
                        ],
                      ),
                    ),
                  )
                else
                  _PortfolioCarousel(images: prestataire.photosPortfolio),
              ],
            ),
          ),
        ),

        // Services
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Services proposés', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final servicesAsync = ref.watch(servicesProvider(id));
                    return servicesAsync.when(
                      data: (services) {
                        if (services.isEmpty) {
                          return Text('Aucun service proposé', style: GoogleFonts.inter(color: AppColors.textSecondary));
                        }
                        return Column(
                          children: services.map((service) {
                            final hasImage = service.images.isNotEmpty;
                            return GestureDetector(
                              onTap: () => context.push('/service/${service.id}'),
                              child: Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasImage)
                                    SizedBox(
                                      height: 140,
                                      width: double.infinity,
                                      child: CachedNetworkImage(
                                        imageUrl: service.images.first,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                          color: AppColors.surfaceGray,
                                          child: const Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                        ),
                                        errorWidget: (_, __, ___) => Container(
                                          color: AppColors.surfaceGray,
                                          child: const Center(
                                            child: Icon(Icons.broken_image, color: AppColors.textSecondary, size: 32),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                service.nom,
                                                style: GoogleFonts.inter(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (service.prixAffiche.isNotEmpty)
                                              Text(
                                                service.prixAffiche,
                                                style: GoogleFonts.inter(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.primaryOrange,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (service.description != null && service.description!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            service.description!,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                        if (service.dureeEstimee != null) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                service.dureeEstimee!,
                                                style: GoogleFonts.inter(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, st) => Text('Erreur chargement services', style: GoogleFonts.inter(color: AppColors.errorRed)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // Avis
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avis clients (${prestataire.nombreAvis})', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                avisAsync.when(
                  data: (avis) {
                    if (avis.isEmpty) return Text('Aucun avis', style: GoogleFonts.inter(color: AppColors.textSecondary));
                    return Column(
                      children: avis.map((a) {
                        final initials = a.clientId.isNotEmpty ? a.clientId[0].toUpperCase() : 'U';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 18, backgroundColor: AppColors.primaryOrangeLight, child: Text(initials, style: GoogleFonts.inter(color: AppColors.primaryOrange, fontWeight: FontWeight.w700))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text(a.clientId, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                    Text(DateFormat.yMMMd().format(a.creeLe), style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 12)),
                                  ]),
                                  const SizedBox(height: 6),
                                  Row(children: List.generate(5, (i) => Padding(padding: const EdgeInsets.only(right: 4), child: MiwodoSvgIcon(i < a.note.round() ? 'assets/icons/ic_star.svg' : 'assets/icons/ic_star_empty.svg', size: 12, color: i < a.note.round() ? AppColors.primaryOrange : AppColors.borderGray)))),
                                  const SizedBox(height: 6),
                                  if ((a.commentaire ?? '').isNotEmpty) Text(a.commentaire!, style: GoogleFonts.inter(color: AppColors.textSecondary)),
                                ]),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Text('Erreur chargement avis', style: GoogleFonts.inter(color: AppColors.errorRed)),
                ),
              ],
            ),
          ),
        ),

        // Formulaire avis
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Laisser un avis', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Consumer(builder: (context, ref, _) {
                final rating = ref.watch(reviewRatingProvider(id));
                return Row(children: List.generate(5, (i) {
                  final filled = i < rating;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => ref.read(reviewRatingProvider(id).notifier).state = i + 1,
                    icon: MiwodoSvgIcon(filled ? 'assets/icons/ic_star.svg' : 'assets/icons/ic_star_empty.svg', size: 28, color: filled ? AppColors.primaryOrange : AppColors.borderGray),
                  );
                }));
              }),
              const SizedBox(height: 8),
              TextField(
                maxLines: 4,
                onChanged: (v) => ref.read(reviewCommentProvider(id).notifier).state = v,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), hintText: 'Votre commentaire'),
              ),
              const SizedBox(height: 12),
              Consumer(builder: (context, ref, _) {
                final submitting = ref.watch(reviewSubmittingProvider(id));
                return MiwodoButton(
                  label: 'Envoyer mon avis',
                  variant: MiwodoButtonVariant.primary,
                  isLoading: submitting,
                  onPressed: submitting
                      ? null
                      : () async {
                          final note = ref.read(reviewRatingProvider(id));
                          final comment = ref.read(reviewCommentProvider(id));
                          if (note <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez choisir une note')));
                            return;
                          }
                          ref.read(reviewSubmittingProvider(id).notifier).state = true;
                          final clientId = FirebaseService.instance.auth.currentUser?.uid ?? 'anonymous';
                          final avis = Avis(id: '', clientId: clientId, prestataireId: id, note: note.toDouble(), commentaire: comment.isEmpty ? null : comment, creeLe: DateTime.now());
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            await FirestoreService.instance.addAvis(avis);
                            ref.invalidate(prestataireProvider(id));
                            ref.invalidate(avisProvider(id));
                            ref.read(reviewRatingProvider(id).notifier).state = 0;
                            ref.read(reviewCommentProvider(id).notifier).state = '';
                            messenger.showSnackBar(const SnackBar(content: Text('Merci pour votre avis')));
                          } catch (e) {
                            messenger.showSnackBar(SnackBar(content: Text('Erreur: $e')));
                          } finally {
                            ref.read(reviewSubmittingProvider(id).notifier).state = false;
                          }
                        },
                );
              }),
            ]),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Bouton Signaler
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: () => _showSignalementDialog(context, id),
              icon: Icon(Icons.flag_outlined, size: 18, color: AppColors.textSecondary),
              label: Text(
                'Signaler ce prestataire',
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHeaderAvatar(Prestataire p) {
    final avatar = p.photoUrl;
    if (avatar != null && avatar.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(imageUrl: avatar, width: 80, height: 80, fit: BoxFit.cover),
      );
    }
    final initials = p.nom.isNotEmpty ? p.nom[0].toUpperCase() : 'P';
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(color: AppColors.primaryOrangeLight, shape: BoxShape.circle),
      child: Center(child: Text(initials, style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primaryOrange))),
    );
  }

  String _categoryLabel(Prestataire p) {
    return p.categorie;
  }

  void _showSignalementDialog(BuildContext context, String prestataireId) {
    final motifs = [
      'Profil trompeur',
      'Arnaque / escroquerie',
      'Contenu inapproprié',
      'Spam / démarchage',
      'Autre',
    ];
    String selectedMotif = motifs.first;
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Signaler ce prestataire', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Motif du signalement', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              RadioGroup<String>(
                groupValue: selectedMotif,
                onChanged: (v) => setState(() => selectedMotif = v ?? motifs.first),
                child: Column(
                  children: motifs.map((m) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Radio<String>(
                      value: m,
                      activeColor: AppColors.primaryOrange,
                    ),
                    title: Text(m, style: GoogleFonts.inter(fontSize: 13)),
                    onTap: () => setState(() => selectedMotif = m),
                  )).toList(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Décrivez le problème...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
              onPressed: () async {
                final tel = FirebaseService.instance.auth.currentUser?.phoneNumber ?? 'inconnu';
                final signalement = Signalement(
                  id: '',
                  prestataireId: prestataireId,
                  signaleurTel: tel,
                  motif: selectedMotif,
                  details: detailsController.text.trim(),
                  statut: 'ouvert',
                  createdAt: DateTime.now(),
                );
                try {
                  await FirestoreService.instance.createSignalement(signalement);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Signalement envoyé. Merci.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
                    );
                  }
                }
              },
              child: Text('Envoyer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortfolioCarousel extends StatefulWidget {
  final List<String> images;

  const _PortfolioCarousel({required this.images});

  @override
  State<_PortfolioCarousel> createState() => _PortfolioCarouselState();
}

class _PortfolioCarouselState extends State<_PortfolioCarousel> {
  int _currentPage = 0;
  final PageController _controller = PageController(viewportFraction: 0.85);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ImageViewer(
                      images: widget.images,
                      initialIndex: index,
                    ),
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.images[index],
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: AppColors.surfaceGray,
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceGray,
                          child: const Center(
                            child: Icon(Icons.broken_image, color: AppColors.textSecondary, size: 32),
                          ),
                        ),
                      ),
                      if (widget.images.length > 1)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(120),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${index + 1}/${widget.images.length}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.images.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentPage == index ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentPage == index ? AppColors.primaryOrange : AppColors.borderGray,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final List<String> images;
  final int initialIndex;

  const _ImageViewer({required this.images, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: PageView.builder(
          controller: PageController(initialPage: initialIndex),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final url = images[index];
            return GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
