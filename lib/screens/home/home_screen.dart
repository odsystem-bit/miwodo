// screens/home/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../models/produit.dart';
import '../../models/service_prestataire.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pays_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/firebase_service.dart';
import '../../services/sponsoring_service.dart';
import '../../services/app_rating_service.dart';
import '../../widgets/miwodo_rating_card.dart';
import '../../widgets/miwodo_svg_icon.dart';
import '../../widgets/star_rating.dart';
import '../commander/commande_providers.dart';
import '../commander/produit_detail_modal.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Provider pour l'état de connexion
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseService.instance.auth.authStateChanges();
});

enum HomeCategory { tous, artisans, liberal, vendeurs, livreurs }

extension HomeCategoryX on HomeCategory {
  String get label {
    switch (this) {
      case HomeCategory.tous:
        return 'Tous';
      case HomeCategory.artisans:
        return 'Artisans';
      case HomeCategory.liberal:
        return 'Libéraux';
      case HomeCategory.vendeurs:
        return 'Vendeurs';
      case HomeCategory.livreurs:
        return 'Livreurs';
    }
  }

  Categorie? get categorie {
    switch (this) {
      case HomeCategory.artisans:
        return Categorie.artisan;
      case HomeCategory.liberal:
        return Categorie.liberal;
      case HomeCategory.vendeurs:
        return Categorie.vendeur;
      case HomeCategory.livreurs:
        return Categorie.livreur;
      case HomeCategory.tous:
        return null;
    }
  }
}

final categorySelectedProvider = StateProvider<HomeCategory>(
  (ref) => HomeCategory.tous,
);
final searchQueryProvider = StateProvider<String>((ref) => '');
final prestatairesProvider = StreamProvider<List<Prestataire>>((
  ref,
) {
  final selectedCategory = ref.watch(categorySelectedProvider);
  return FirestoreService.instance.getPrestataires(
    categorie: selectedCategory.categorie,
  ).map((list) => list.take(30).toList());
});

final servicesProvider = StreamProvider<List<ServicePrestataire>>((ref) {
  return FirebaseFirestore.instance
      .collection('services')
      .where('actif', isEqualTo: true)
      .limit(20)
      .snapshots()
      .map((snap) {
        final services = snap.docs.map((d) => ServicePrestataire.fromJson({...d.data(), 'id': d.id})).toList();
        // Sort: sponsored services first (premium > standard), then by ordre
        services.sort((a, b) {
          final aSponsored = a.isSponsoredActive;
          final bSponsored = b.isSponsoredActive;
          if (aSponsored && !bSponsored) return -1;
          if (!aSponsored && bSponsored) return 1;
          if (aSponsored && bSponsored) {
            final aPremium = a.sponsoringPlan == 'premium';
            final bPremium = b.sponsoringPlan == 'premium';
            if (aPremium && !bPremium) return -1;
            if (!aPremium && bPremium) return 1;
          }
          return a.ordre.compareTo(b.ordre);
        });
        return services.take(10).toList();
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[servicesProvider] error: $error');
            sink.add(<ServicePrestataire>[]);
          },
        ),
      );
});

final sponsoredServicesProvider = StreamProvider<List<ServicePrestataire>>((ref) {
  return FirebaseFirestore.instance
      .collection('services')
      .where('actif', isEqualTo: true)
      .where('sponsorise', isEqualTo: true)
      .limit(10)
      .snapshots()
      .map((snap) {
        final now = DateTime.now();
        final services = snap.docs
            .map((d) => ServicePrestataire.fromJson({...d.data(), 'id': d.id}))
            .where((s) {
              if (s.sponsoringExpireLe == null) return false;
              return now.isBefore(s.sponsoringExpireLe!);
            })
            .toList();
        // Sort: premium first, then standard
        services.sort((a, b) {
          final aPremium = a.sponsoringPlan == 'premium';
          final bPremium = b.sponsoringPlan == 'premium';
          if (aPremium && !bPremium) return -1;
          if (!aPremium && bPremium) return 1;
          return a.ordre.compareTo(b.ordre);
        });
        return services;
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[sponsoredServicesProvider] error: $error');
            sink.add(<ServicePrestataire>[]);
          },
        ),
      );
});

// Provider to fetch prestataire name/photo for a given prestataireId
final prestataireInfoProvider = FutureProvider.family<({String name, String? photoUrl, String categorie, String zone}), String>((ref, id) async {
  try {
    final doc = await FirebaseFirestore.instance.collection('prestataires').doc(id).get();
    if (!doc.exists) return (name: 'Prestataire', photoUrl: null, categorie: '', zone: '');
    final data = doc.data()!;
    final name = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
    return (
      name: name.isEmpty ? 'Prestataire' : name,
      photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String?,
      categorie: data['categorie'] as String? ?? '',
      zone: data['zone'] as String? ?? '',
    );
  } catch (e) {
    return (name: 'Prestataire', photoUrl: null, categorie: '', zone: '');
  }
});

// Provider for popular products
final produitsPopulairesProvider = StreamProvider<List<Produit>>((ref) {
  return FirebaseFirestore.instance
      .collection('produits')
      .where('estDisponible', isEqualTo: true)
      .limit(10)
      .snapshots()
      .map((snap) {
        return snap.docs.map((d) => Produit.fromJson({...d.data(), 'id': d.id})).toList();
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[produitsPopulairesProvider] error: $error');
            sink.add(<Produit>[]);
          },
        ),
      );
});

// Provider for boutiques (vendeurs with boutique name)
final boutiquesProvider = StreamProvider<List<Prestataire>>((ref) {
  return FirebaseFirestore.instance
      .collection('prestataires')
      .where('categorie', isEqualTo: 'vendeur')
      .where('actif', isEqualTo: true)
      .limit(10)
      .snapshots()
      .map((snap) {
        return snap.docs.map((d) => Prestataire.fromJson({...d.data(), 'id': d.id})).toList();
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[boutiquesProvider] error: $error');
            sink.add(<Prestataire>[]);
          },
        ),
      );
});

// Provider for featured prestataires (artisans + liberal)
final prestatairesVedetteProvider = StreamProvider<List<Prestataire>>((ref) {
  return FirebaseFirestore.instance
      .collection('prestataires')
      .where('actif', isEqualTo: true)
      .limit(20)
      .snapshots()
      .map((snap) {
        final all = snap.docs.map((d) => Prestataire.fromJson({...d.data(), 'id': d.id})).toList();
        // Sort: sponsored first, then by rating
        all.sort((a, b) {
          if (a.sponsorise && !b.sponsorise) return -1;
          if (!a.sponsorise && b.sponsorise) return 1;
          return b.noteMoyenne.compareTo(a.noteMoyenne);
        });
        return all.where((p) => p.categorie == 'artisan' || p.categorie == 'liberal').take(10).toList();
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[prestatairesVedetteProvider] error: $error');
            sink.add(<Prestataire>[]);
          },
        ),
      );
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchQuery = ref.watch(searchQueryProvider);
    final categorySelected = ref.watch(categorySelectedProvider);
    final prestatairesAsync = ref.watch(prestatairesProvider);
    final currentPrestataire = ref.watch(currentUserPrestataireProvider).valueOrNull;
    final showDevenirPrestataire = currentPrestataire == null;

    // Garder les données précédentes pendant le rechargement pour éviter le flickering
    final List<Prestataire> prestataires = prestatairesAsync.valueOrNull ?? const [];

    final filteredPrestataires = _filterPrestataires(prestataires, searchQuery);
    final livreurs = _filterPrestataires(
      prestataires.where((p) => p.categorie == 'livreur').toList(),
      searchQuery,
    );

    // Si une catégorie spécifique est sélectionnée, on n'affiche que les sections pertinentes
    final showAllSections = categorySelected == HomeCategory.tous && searchQuery.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: CustomScrollView(
        slivers: [
          _buildHeroBanner(context, ref),
          _buildSearchBar(context, ref),
          _buildCategoryGrid(ref, categorySelected),
          if (showAllSections) ...[
            _buildSponsoredServicesSection(ref),
            _buildPrestatairesVedetteSection(context, ref),
            _buildServicesSection(ref),
            _buildProduitsSection(ref),
            _buildBoutiquesSection(ref),
            _buildLivreursSection(livreurs),
          ] else if (searchQuery.isNotEmpty) ...[
            // Mode recherche: afficher tous les prestataires filtrés
            _buildSearchResultsSection(context, filteredPrestataires),
          ] else ...[
            // Mode catégorie: afficher les sections pertinentes
            if (categorySelected == HomeCategory.livreurs)
              _buildLivreursSection(livreurs)
            else if (categorySelected == HomeCategory.vendeurs)
              _buildBoutiquesSection(ref)
            else ...[
              _buildPrestatairesVedetteSection(context, ref),
              _buildServicesSection(ref),
            ],
          ],
          _buildNewPrestatairesSection(context, filteredPrestataires),
          if (showDevenirPrestataire) _buildDevenirPrestataireCard(context),
          _buildReferralBanner(context),
          const SliverToBoxAdapter(
            child: MiwodoRatingCard(
              source: 'accueil_banniere',
              margin: EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, WidgetRef ref) {
    final pays = ref.watch(paysSelectionneProvider);
    final locationLabel = pays?.nom ?? '';

    return SliverToBoxAdapter(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar : Logo + Ville / Pays + Action
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/logo.jpeg',
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MIWODO',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: AppColors.brandDarkNavy,
                              ),
                            ),
                            Text(
                              'Artisans & Pros certifiés',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (locationLabel.isNotEmpty)
                      GestureDetector(
                        onTap: () => context.push('/pays'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGray,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 14, color: AppColors.brandOrange),
                              const SizedBox(width: 4),
                              Text(
                                locationLabel,
                                style: GoogleFonts.inter(
                                  color: AppColors.brandDarkNavy,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down, size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Hero Banners Carousel (Animé automatiquement avec les 3 affiches)
              const _HomeHeroCarousel(),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, WidgetRef ref) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderGray),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).state = value;
            },
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              hintText: 'Rechercher un artisan, un métier, un service...',
              hintStyle: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
              border: InputBorder.none,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(Icons.search, size: 20, color: AppColors.primaryOrange),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: Consumer(
                builder: (context, ref, _) {
                  final query = ref.watch(searchQueryProvider);
                  if (query.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(WidgetRef ref, HomeCategory selectedCategory) {
    final categories = HomeCategory.values;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final bool isActive = category == selectedCategory;
              final iconPath = category.categorie?.svgIcon;

              return GestureDetector(
                onTap: () {
                  ref.read(categorySelectedProvider.notifier).state = category;
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 78,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.brandDarkNavy : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? AppColors.brandDarkNavy : AppColors.borderGray,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? AppColors.brandDarkNavy.withAlpha(40)
                            : Colors.black.withAlpha(6),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.brandOrange
                              : AppColors.primaryOrangeLight,
                          shape: BoxShape.circle,
                        ),
                        child: iconPath != null
                            ? SvgPicture.asset(
                                iconPath,
                                width: 20,
                                height: 20,
                                colorFilter: ColorFilter.mode(
                                  isActive ? Colors.white : AppColors.primaryOrange,
                                  BlendMode.srcIn,
                                ),
                              )
                            : Icon(
                                Icons.grid_view_rounded,
                                size: 20,
                                color: isActive ? Colors.white : AppColors.primaryOrange,
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        category == HomeCategory.tous ? 'Tous' : category.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive ? Colors.white : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSponsoredServicesSection(WidgetRef ref) {
    final sponsoredAsync = ref.watch(sponsoredServicesProvider);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            _buildSectionHeader('Services sponsorisés', 'assets/icons/ic_star.svg'),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: sponsoredAsync.when(
                data: (services) {
                  if (services.isEmpty) {
                    return _buildEmptyState('Aucun service sponsorisé disponible');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final prestataireInfo = ref.watch(prestataireInfoProvider(service.prestataireId));
                      final isPremium = service.sponsoringPlan == 'premium';

                      return GestureDetector(
                        onTap: () {
                          context.push('/service/${service.id}');
                          if (service.sponsoringCampaignId != null) {
                            SponsoringService.instance.incrementClicks(service.sponsoringCampaignId!);
                          }
                        },
                        child: Container(
                          width: 200,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isPremium ? AppColors.primaryOrange : AppColors.borderGray,
                              width: isPremium ? 1.5 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildServiceImage(service.images, height: 120),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              service.nom,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (service.prixAffiche.isNotEmpty)
                                        Text(
                                          service.prixAffiche,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryOrange,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const Spacer(),
                                      _buildPrestataireRow(prestataireInfo),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => _buildEmptyState('Aucun service sponsorisé disponible'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDevenirPrestataireCard(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: GestureDetector(
          onTap: () => context.push('/inscription'),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFD55700)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Icon(Icons.work_outline, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vous proposez un service ?',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Inscrivez-vous gratuitement et trouvez des clients',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReferralBanner(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryOrange.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_giftcard,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programme de parrainage Miwodo',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brandDarkNavy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gagnez des primes directes pour chaque artisan ou professionnel parrainé.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => context.push('/compte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandDarkNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Participer',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsSection(BuildContext context, List<Prestataire> prestataires) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${prestataires.length} résultat(s)',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (prestataires.isEmpty)
              _buildEmptyState('Aucun résultat trouvé. Essayez un autre terme.')
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: prestataires.length,
                itemBuilder: (context, index) {
                  return _buildPrestataireHomeCard(context, prestataires[index]);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewPrestatairesSection(BuildContext context, List<Prestataire> prestataires) {
    final newPrestataires = prestataires.take(6).toList();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeaderWithAction('Nouveaux prestataires', () => context.push('/prestataires')),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: newPrestataires.isEmpty
                  ? _buildEmptyState('Aucun nouveau prestataire')
                  : ListView.separated(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: newPrestataires.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final prestataire = newPrestataires[index];
                        return _buildPrestataireHomeCard(context, prestataire);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSection(WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Services populaires', 'assets/icons/ic_chart.svg'),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: servicesAsync.when(
                data: (services) {
                  if (services.isEmpty) {
                    return _buildEmptyState('Aucun service disponible pour le moment.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: services.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final prestataireInfo = ref.watch(prestataireInfoProvider(service.prestataireId));

                      return GestureDetector(
                        onTap: () => context.push('/service/${service.id}'),
                        child: Container(
                          width: 200,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGray),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  _buildServiceImage(service.images, height: 120),
                                  if (service.isSponsoredActive)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: _buildSponsoredBadge(service.sponsoringPlan == 'premium'),
                                    ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service.nom,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (service.prixAffiche.isNotEmpty)
                                        Text(
                                          service.prixAffiche,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryOrange,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      const Spacer(),
                                      _buildPrestataireRow(prestataireInfo),
                                      if (service.dureeEstimee != null) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 10, color: AppColors.textSecondary),
                                            const SizedBox(width: 4),
                                            Text(
                                              service.dureeEstimee!,
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Text(
                    'Erreur chargement services',
                    style: GoogleFonts.inter(color: AppColors.errorRed),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivreursSection(List<Prestataire> livreurs) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Livreurs disponibles', 'assets/icons/ic_two_wheeler.svg'),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: livreurs.isEmpty
                  ? _buildEmptyState('Aucun livreur disponible pour le moment.')
                  : ListView.separated(
                      padding: const EdgeInsets.only(left: 16, right: 8),
                      scrollDirection: Axis.horizontal,
                      itemCount: livreurs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final prestataire = livreurs[index];
                        return _buildPrestataireHomeCard(context, prestataire);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrestatairesVedetteSection(BuildContext context, WidgetRef ref) {
    final vedetteAsync = ref.watch(prestatairesVedetteProvider);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeaderWithAction('Prestataires en vedette', () => context.push('/prestataires')),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: vedetteAsync.when(
                data: (prestataires) {
                  if (prestataires.isEmpty) {
                    return _buildEmptyState('Aucun prestataire en vedette');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: prestataires.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return _buildPrestataireHomeCard(context, prestataires[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => _buildEmptyState('Aucun prestataire en vedette'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProduitsSection(WidgetRef ref) {
    final produitsAsync = ref.watch(produitsPopulairesProvider);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Produits populaires', 'assets/icons/ic_cart.svg'),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: produitsAsync.when(
                data: (produits) {
                  if (produits.isEmpty) {
                    return _buildEmptyState('Aucun produit disponible pour le moment.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: produits.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final produit = produits[index];
                      final prestataireInfo = ref.watch(prestataireInfoProvider(produit.prestataireId));
                      final imageUrl = produit.imageUrl ?? (produit.images.isNotEmpty ? produit.images.first : null);

                      return GestureDetector(
                        onTap: () => showProduitDetailSheet(
                          context,
                          produit: produit,
                        ),
                        child: Container(
                          width: 160,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGray),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 110,
                                width: double.infinity,
                                child: _buildNetworkImage(imageUrl),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        produit.nom,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${produit.prix.toStringAsFixed(0)} F',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryOrange,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        prestataireInfo.asData?.value.name ?? '...',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            ref.read(cartProvider.notifier).add(produit);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('${produit.nom} ajouté au panier'),
                                                duration: const Duration(seconds: 2),
                                                backgroundColor: AppColors.successGreen,
                                                action: SnackBarAction(
                                                  label: 'Voir panier',
                                                  textColor: Colors.white,
                                                  onPressed: () => context.push('/panier'),
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.add_shopping_cart, size: 12),
                                          label: Text('Ajouter', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryOrange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: const Size(0, 28),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => _buildEmptyState('Aucun produit disponible pour le moment.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoutiquesSection(WidgetRef ref) {
    final boutiquesAsync = ref.watch(boutiquesProvider);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Boutiques recommandées', 'assets/icons/ic_vendeur.svg'),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: boutiquesAsync.when(
                data: (boutiques) {
                  if (boutiques.isEmpty) {
                    return _buildEmptyState('Aucune boutique disponible pour le moment.');
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    scrollDirection: Axis.horizontal,
                    itemCount: boutiques.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final boutique = boutiques[index];
                      final photoUrl = boutique.photoUrl ?? (boutique.photosPortfolio.isNotEmpty ? boutique.photosPortfolio.first : null);
                      final boutiqueNom = boutique.boutiqueNom ?? '${boutique.prenom} ${boutique.nom}';

                      return GestureDetector(
                        onTap: () => context.push('/prestataire/${boutique.id}'),
                        child: Container(
                          width: 180,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.borderGray),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(8),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  SizedBox(
                                    height: 100,
                                    width: double.infinity,
                                    child: _buildNetworkImage(photoUrl),
                                  ),
                                  if (boutique.sponsorise)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: _buildSponsoredBadge(boutique.planPub == 'premium'),
                                    ),
                                ],
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        boutiqueNom,
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 10, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              boutique.ville.isNotEmpty ? boutique.ville : boutique.zone,
                                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      StarRating(noteMoyenne: boutique.noteMoyenne, nbAvis: boutique.nombreAvis, compact: true),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (_, __) => _buildEmptyState('Aucune boutique disponible pour le moment.'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSectionHeader(String title, String iconPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          SvgPicture.asset(
            iconPath,
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              AppColors.primaryOrange,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderWithAction(String title, VoidCallback onSeeAll) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'Voir tout',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSponsoredBadge(bool isPremium) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPremium ? AppColors.primaryOrange : AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPremium ? 'PREMIUM' : 'SPONSORISÉ',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isPremium ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildServiceImage(List<String> images, {required double height}) {
    final hasImage = images.isNotEmpty;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: images.first,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: AppColors.primaryOrangeLight,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.primaryOrangeLight,
                child: const Center(
                  child: Icon(Icons.image, color: AppColors.primaryOrange, size: 32),
                ),
              ),
            )
          : Container(
              color: AppColors.primaryOrangeLight,
              child: const Center(
                child: Icon(Icons.image, color: AppColors.primaryOrange, size: 32),
              ),
            ),
    );
  }

  Widget _buildNetworkImage(String? url) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: AppColors.primaryOrangeLight,
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.primaryOrangeLight,
          child: const Center(
            child: Icon(Icons.image, color: AppColors.primaryOrange, size: 32),
          ),
        ),
      );
    }
    return Container(
      color: AppColors.primaryOrangeLight,
      child: const Center(
        child: Icon(Icons.image, color: AppColors.primaryOrange, size: 32),
      ),
    );
  }

  Widget _buildPrestataireRow(AsyncValue<({String name, String? photoUrl, String categorie, String zone})> prestataireInfo) {
    return Row(
      children: [
        if (prestataireInfo.asData?.value.photoUrl != null)
          ClipOval(
            child: CachedNetworkImage(
              imageUrl: prestataireInfo.asData!.value.photoUrl!,
              width: 16,
              height: 16,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 16,
                height: 16,
                color: AppColors.primaryOrangeLight,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 16,
                height: 16,
                color: AppColors.primaryOrangeLight,
                child: const Icon(Icons.person, size: 10, color: AppColors.primaryOrange),
              ),
            ),
          )
        else
          const Icon(Icons.person, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            prestataireInfo.asData?.value.name ?? '...',
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildPrestataireHomeCard(BuildContext context, Prestataire prestataire) {
    final hasPortfolio = prestataire.photosPortfolio.isNotEmpty;
    final coverImage = hasPortfolio
        ? prestataire.photosPortfolio.first
        : prestataire.photoUrl;
    final categoryLabel = Categorie.values.firstWhere(
      (c) => c.name == prestataire.categorie,
      orElse: () => Categorie.artisan,
    ).label;

    return GestureDetector(
      onTap: () => context.push('/prestataire/${prestataire.id}'),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: _buildNetworkImage(coverImage),
                ),
                if (prestataire.sponsorise)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildSponsoredBadge(prestataire.planPub == 'premium'),
                  ),
                if (prestataire.estDisponible)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Disponible',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${prestataire.prenom} ${prestataire.nom}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (prestataire.estVerifie) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, size: 14, color: AppColors.primaryOrange),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prestataire.metier ?? categoryLabel,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppColors.primaryOrange,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 10, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            prestataire.ville.isNotEmpty ? prestataire.ville : prestataire.zone,
                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    StarRating(noteMoyenne: prestataire.noteMoyenne, nbAvis: prestataire.nombreAvis, compact: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Prestataire> _filterPrestataires(
    List<Prestataire> prestataires,
    String query,
  ) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return prestataires;

    return prestataires.where((prestataire) {
      return prestataire.nom.toLowerCase().contains(normalized) ||
          prestataire.prenom.toLowerCase().contains(normalized) ||
          prestataire.categorie.toLowerCase().contains(normalized) ||
          prestataire.zone.toLowerCase().contains(normalized) ||
          prestataire.ville.toLowerCase().contains(normalized) ||
          (prestataire.metier?.toLowerCase().contains(normalized) ?? false) ||
          (prestataire.description?.toLowerCase().contains(normalized) ?? false) ||
          (prestataire.boutiqueNom?.toLowerCase().contains(normalized) ?? false) ||
          (prestataire.specialites?.toLowerCase().contains(normalized) ?? false);
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CARROUSEL HERO ANIMÉ & TABLEAU D'ANNONCES DYNAMIQUE (Géré depuis le Web Admin)
// ═══════════════════════════════════════════════════════════════════════════

class _HeroBannerItem {
  final String imageUrl;
  final String? actionUrl;
  final String? title;
  final bool isLocal;

  const _HeroBannerItem({
    required this.imageUrl,
    this.actionUrl,
    this.title,
    this.isLocal = false,
  });
}

class _HomeHeroCarousel extends StatefulWidget {
  const _HomeHeroCarousel();

  @override
  State<_HomeHeroCarousel> createState() => _HomeHeroCarouselState();
}

class _HomeHeroCarouselState extends State<_HomeHeroCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  Timer? _timer;

  // Bannières par défaut locales (affichage immédiat)
  List<_HeroBannerItem> _banners = const [
    _HeroBannerItem(imageUrl: 'assets/images/hero_banner_1.jpg', actionUrl: '/prestataires', isLocal: true),
    _HeroBannerItem(imageUrl: 'assets/images/hero_banner_2.jpg', actionUrl: '/commander', isLocal: true),
    _HeroBannerItem(imageUrl: 'assets/images/hero_banner_3.jpg', actionUrl: '/accueil', isLocal: true),
  ];

  String? _alertMessage;
  String? _alertLink;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _fetchDynamicAnnonces();
  }

  Future<void> _fetchDynamicAnnonces() async {
    try {
      final res = await http.get(
        Uri.parse('https://bot.odsysteme.tech/api/annonces.php'),
      ).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['success'] == true && data['annonces'] is List) {
          final list = data['annonces'] as List;
          final List<_HeroBannerItem> dynamicBanners = [];
          String? foundAlert;
          String? foundAlertLink;

          for (final item in list) {
            final type = item['type'] as String? ?? 'hero_banner';
            if (type == 'alert_ribbon') {
              foundAlert = item['titre'] as String?;
              foundAlertLink = item['lien_action'] as String?;
            } else if (type == 'hero_banner') {
              final img = item['image_url'] as String? ?? '';
              if (img.isNotEmpty) {
                dynamicBanners.add(_HeroBannerItem(
                  imageUrl: img,
                  actionUrl: item['lien_action'] as String?,
                  title: item['titre'] as String?,
                  isLocal: false,
                ));
              }
            }
          }

          if (mounted) {
            setState(() {
              if (dynamicBanners.isNotEmpty) {
                _banners = dynamicBanners;
              }
              _alertMessage = foundAlert;
              _alertLink = foundAlertLink;
            });
          }
        }
      }
    } catch (e) {
      // Fallback silencieux sur les affiches locales déjà chargées
      if (kDebugMode) print('[HeroCarousel] Fallback affiches locales: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || _banners.isEmpty) return;
      final next = (_currentPage + 1) % _banners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onBannerTap(_HeroBannerItem item) {
    final route = item.actionUrl?.trim();
    if (route != null && route.isNotEmpty) {
      if (route == '/noter' || route == 'noter' || route == 'playstore') {
        AppRatingService.instance.showRatingDialog(context, source: 'banniere_admin');
      } else if (route.startsWith('/')) {
        context.push(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Carrousel Bannières Hero
        SizedBox(
          height: 125,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final item = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => _onBannerTap(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(20),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: item.isLocal
                          ? Image.asset(
                              item.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            )
                          : CachedNetworkImage(
                              imageUrl: item.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              placeholder: (ctx, url) => Container(
                                color: const Color(0xFFF1F5F9),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                              ),
                              errorWidget: (ctx, url, error) => Image.asset(
                                'assets/images/hero_banner_1.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),

        // 2. Indicateurs de pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _banners.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentPage ? 22 : 6,
              height: 5,
              decoration: BoxDecoration(
                gradient: i == _currentPage ? AppColors.brandGradientHorizontal : null,
                color: i == _currentPage ? null : AppColors.borderGray,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),

        // 3. Ruban d'Alerte / Annonce Urgente (si actif sur le Web Admin)
        if (_alertMessage != null && _alertMessage!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                if (_alertLink == '/noter' || _alertLink == 'noter' || _alertLink == 'playstore') {
                  AppRatingService.instance.showRatingDialog(context, source: 'ruban_admin');
                } else if (_alertLink != null && _alertLink!.startsWith('/')) {
                  context.push(_alertLink!);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF7ED), Color(0xFFFFF1F2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF7A00),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _alertMessage!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_alertLink != null && _alertLink!.isNotEmpty)
                      const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFF7A00), size: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
