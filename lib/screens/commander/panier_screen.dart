// screens/commander/panier_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/constants/zones.dart';
import '../../models/commande.dart';
import '../../models/pays.dart';
import '../../providers/pays_provider.dart';
import '../../services/commande_vendeur_service.dart';
import '../../services/firebase_service.dart';
import '../../services/firestore_service.dart';
import '../../services/geolocation_service.dart';
import '../../services/moneroo_service.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';
import '../../widgets/moneroo_webview.dart';
import 'commande_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PROVIDERS ADDITIONNELS
// ═══════════════════════════════════════════════════════════════════════════

final geoDetectionProvider = StateProvider<GeoDetectionState>(
  (ref) => GeoDetectionState(),
);

class GeoDetectionState {
  final bool isDetecting;
  final String? detectedZone;
  final String? errorMessage;
  final Position? position;

  GeoDetectionState({
    this.isDetecting = false,
    this.detectedZone,
    this.errorMessage,
    this.position,
  });

  GeoDetectionState copyWith({
    bool? isDetecting,
    String? detectedZone,
    String? errorMessage,
    Position? position,
  }) => GeoDetectionState(
    isDetecting: isDetecting ?? this.isDetecting,
    detectedZone: detectedZone ?? this.detectedZone,
    errorMessage: errorMessage ?? this.errorMessage,
    position: position ?? this.position,
  );
}

final selectedZoneProvider = StateProvider<String?>((ref) => null);
final selectedCityProvider = StateProvider<String?>((ref) => null);
final adresseTexteProvider = StateProvider<String>((ref) => '');
final clientNomProvider = StateProvider<String>((ref) => '');
final clientTelephoneProvider = StateProvider<String>((ref) => '');
final selectedLivreurProvider = StateProvider<LivreurDisponible?>(
  (ref) => null,
);
final livreursDisponiblesProvider =
    FutureProvider.family<List<LivreurDisponible>, String>((ref, zone) async {
      final geoState = ref.watch(geoDetectionProvider);
      GeoPoint? coords;
      if (geoState.position != null) {
        coords = GeoPoint(
          geoState.position!.latitude,
          geoState.position!.longitude,
        );
      }
      return GeolocationService.instance.getLivreursDisponibles(
        zone: zone,
        clientCoords: coords,
      );
    });

final checkoutStepProvider = StateProvider<int>(
  (ref) => 0,
); // 0: panier, 1: adresse, 2: livreur, 3: recap

class PanierScreen extends ConsumerStatefulWidget {
  const PanierScreen({super.key});

  @override
  ConsumerState<PanierScreen> createState() => _PanierScreenState();
}

class _PanierScreenState extends ConsumerState<PanierScreen> {
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _adresseController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initClientInfo();
  }

  void _initClientInfo() {
    final user = FirebaseService.instance.auth.currentUser;
    if (user != null) {
      _nomController.text = user.displayName ?? '';
      _telephoneController.text = user.phoneNumber ?? '';
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartProvider);
    final step = ref.watch(checkoutStepProvider);
    final isProcessing = ref.watch(checkoutLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        leading: step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(checkoutStepProvider.notifier).state--,
              )
            : null,
        title: Text(
          _getStepTitle(step),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        elevation: 0,
        backgroundColor: AppColors.white,
        actions: [
          if (cartState.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  '${cartState.itemsList.length} article${cartState.itemsList.length > 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: cartState.isEmpty
            ? _EmptyCartView(onBrowse: () => context.go('/commander'))
            : _buildStepContent(step, cartState, isProcessing),
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Mon panier';
      case 1:
        return 'Adresse de livraison';
      case 2:
        return 'Choisir un livreur';
      case 3:
        return 'Récapitulatif';
      default:
        return 'Panier';
    }
  }

  Widget _buildStepContent(int step, CartState cartState, bool isProcessing) {
    switch (step) {
      case 0:
        return _CartStep(cartState: cartState);
      case 1:
        return _AdresseStep(
          nomController: _nomController,
          telephoneController: _telephoneController,
          adresseController: _adresseController,
        );
      case 2:
        return const _LivreurStep();
      case 3:
        return _RecapStep(
          cartState: cartState,
          isProcessing: isProcessing,
          nomController: _nomController,
          telephoneController: _telephoneController,
          adresseController: _adresseController,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _EmptyCartView extends StatelessWidget {
  final VoidCallback onBrowse;

  const _EmptyCartView({required this.onBrowse});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MiwodoSvgIcon(
            'ic_cart.svg',
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 24),
          Text(
            'Votre panier est vide',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            'Ajoutez des produits et revenez ici pour finaliser votre commande.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          MiwodoButton(label: 'Voir les produits', onPressed: onBrowse),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAPE 1 : PANIER
// ═══════════════════════════════════════════════════════════════════════════

class _CartStep extends ConsumerWidget {
  final CartState cartState;

  const _CartStep({required this.cartState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subtotal = cartState.totalAmount;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartState.itemsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = cartState.itemsList[index];
              return _CartItemCard(
                item: item,
                onAdd: () => ref.read(cartProvider.notifier).add(item.produit),
                onRemove: () =>
                    ref.read(cartProvider.notifier).decrement(item.produit),
              );
            },
          ),
        ),
        _BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sous-total',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${subtotal.toStringAsFixed(0)} F',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MiwodoButton(
                label: 'Continuer',
                fullWidth: true,
                onPressed: () =>
                    ref.read(checkoutStepProvider.notifier).state = 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CartItemCard extends StatelessWidget {
  final CartItem item;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CartItemCard({
    required this.item,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = item.produit.prix * item.quantity;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child:
                  item.produit.imageUrl != null &&
                      item.produit.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.produit.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: AppColors.surfaceGray,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.produit.nom,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.produit.prix.toStringAsFixed(0)} F',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuantityButton(icon: Icons.remove, onTap: onRemove),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '${item.quantity}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _QuantityButton(icon: Icons.add, onTap: onAdd),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '${total.toStringAsFixed(0)} F',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.primaryOrange,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAPE 2 : ADRESSE DE LIVRAISON
// ═══════════════════════════════════════════════════════════════════════════

class _AdresseStep extends ConsumerStatefulWidget {
  final TextEditingController nomController;
  final TextEditingController telephoneController;
  final TextEditingController adresseController;

  const _AdresseStep({
    required this.nomController,
    required this.telephoneController,
    required this.adresseController,
  });

  @override
  ConsumerState<_AdresseStep> createState() => _AdresseStepState();
}

class _AdresseStepState extends ConsumerState<_AdresseStep> {
  @override
  void initState() {
    super.initState();
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    ref.read(geoDetectionProvider.notifier).state = GeoDetectionState(
      isDetecting: true,
    );

    final position = await GeolocationService.instance.getCurrentPosition();
    if (position == null) {
      ref.read(geoDetectionProvider.notifier).state = GeoDetectionState(
        isDetecting: false,
        errorMessage:
            'Impossible de détecter votre position. Sélectionnez manuellement.',
      );
      return;
    }

    final zone = await GeolocationService.instance.detectZoneFromPosition(
      position,
    );
    ref.read(geoDetectionProvider.notifier).state = GeoDetectionState(
      isDetecting: false,
      detectedZone: zone,
      position: position,
    );
    if (zone != null) {
      ref.read(selectedZoneProvider.notifier).state = zone;
    }
  }

  @override
  Widget build(BuildContext context) {
    final geoState = ref.watch(geoDetectionProvider);
    final selectedZone = ref.watch(selectedZoneProvider);
    final selectedCity = ref.watch(selectedCityProvider);
    final pays = ref.watch(paysSelectionneProvider) ?? Pays.togo;
    final villes = Zones.villesParPays(pays.id);
    final zones = selectedCity != null
        ? Zones.zonesParVille(pays.id, selectedCity)
        : <String>[];

    final canContinue =
        selectedZone != null &&
        selectedCity != null &&
        widget.nomController.text.isNotEmpty &&
        widget.telephoneController.text.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Zone de livraison multi-pays
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  color: Colors.white,
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const MiwodoSvgIcon(
                              'ic_location.svg',
                              size: 18,
                              color: AppColors.primaryOrange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Zone de livraison',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Pays actuel
                        Text(
                          'Pays: ${pays.nom} ${pays.drapeauEmoji}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Sélecteur de ville
                        DropdownButtonFormField<String>(
                          value: selectedCity,
                          decoration: InputDecoration(
                            hintText: 'Choisissez votre ville',
                            filled: true,
                            fillColor: AppColors.surfaceGray,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: villes
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) {
                            ref.read(selectedCityProvider.notifier).state = v;
                            ref.read(selectedZoneProvider.notifier).state =
                                null;
                          },
                        ),
                        const SizedBox(height: 12),
                        // Sélecteur de zone (quartier)
                        if (selectedCity != null)
                          DropdownButtonFormField<String>(
                            value: selectedZone,
                            decoration: InputDecoration(
                              hintText: 'Choisissez votre quartier',
                              filled: true,
                              fillColor: AppColors.surfaceGray,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: zones
                                .map(
                                  (z) => DropdownMenuItem(
                                    value: z,
                                    child: Text(z),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                ref.read(selectedZoneProvider.notifier).state =
                                    v,
                          ),
                        if (geoState.isDetecting)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Détection GPS en cours...',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (geoState.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              geoState.errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Adresse précise
                _buildTextField(
                  label: 'Adresse précise (optionnel)',
                  hint: 'ex: Rue des Flamboyants, en face du lycée...',
                  controller: widget.adresseController,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Nom
                _buildTextField(
                  label: 'Nom du destinataire *',
                  hint: 'Votre nom complet',
                  controller: widget.nomController,
                ),
                const SizedBox(height: 16),

                // Téléphone
                _buildTextField(
                  label: 'Téléphone *',
                  hint: '90 XX XX XX',
                  controller: widget.telephoneController,
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          child: MiwodoButton(
            label: 'Choisir un livreur',
            fullWidth: true,
            onPressed: canContinue
                ? () => ref.read(checkoutStepProvider.notifier).state = 2
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderGray),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAPE 3 : SÉLECTION LIVREUR
// ═══════════════════════════════════════════════════════════════════════════

class _LivreurStep extends ConsumerWidget {
  const _LivreurStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedZoneProvider);
    final selectedLivreur = ref.watch(selectedLivreurProvider);

    if (zone == null) {
      return const Center(child: Text('Zone non sélectionnée'));
    }

    final livreursAsync = ref.watch(livreursDisponiblesProvider(zone));

    return Column(
      children: [
        Expanded(
          child: livreursAsync.when(
            data: (livreurs) {
              if (livreurs.isEmpty) {
                return _NoLivreurView(zone: zone);
              }

              final livreursExacts = livreurs
                  .where((l) => l.estZoneExacte)
                  .toList();
              final livreursProches = livreurs
                  .where((l) => !l.estZoneExacte)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    '${livreurs.length} livreur${livreurs.length > 1 ? 's' : ''} disponible${livreurs.length > 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (livreursExacts.isNotEmpty) ...[
                    _SectionHeader(
                      icon: 'ic_location.svg',
                      title: 'Dans votre zone',
                    ),
                    const SizedBox(height: 8),
                    ...livreursExacts.map(
                      (l) => _LivreurCard(
                        livreur: l,
                        isSelected: selectedLivreur?.id == l.id,
                        onTap: () =>
                            ref.read(selectedLivreurProvider.notifier).state =
                                l,
                      ),
                    ),
                  ],

                  if (livreursProches.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionHeader(
                      icon: 'ic_refresh.svg',
                      title: 'Zones proches',
                    ),
                    const SizedBox(height: 8),
                    ...livreursProches.map(
                      (l) => _LivreurCard(
                        livreur: l,
                        isSelected: selectedLivreur?.id == l.id,
                        onTap: () =>
                            ref.read(selectedLivreurProvider.notifier).state =
                                l,
                        showZoneBadge: true,
                      ),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
          ),
        ),
        _BottomBar(
          child: MiwodoButton(
            label: 'Continuer',
            fullWidth: true,
            onPressed: selectedLivreur != null
                ? () => ref.read(checkoutStepProvider.notifier).state = 3
                : null,
          ),
        ),
      ],
    );
  }
}

class _NoLivreurView extends StatelessWidget {
  final String zone;

  const _NoLivreurView({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MiwodoSvgIcon(
              'ic_sad.svg',
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun livreur disponible',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aucun livreur n\'est disponible dans la zone $zone pour le moment.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            MiwodoButton(
              label: 'Contacter le vendeur',
              variant: MiwodoButtonVariant.secondary,
              onPressed: () => launchUrl(Uri.parse('tel:+22890000000')),
            ),
          ],
        ),
      ),
    );
  }
}

class _LivreurCard extends StatelessWidget {
  final LivreurDisponible livreur;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showZoneBadge;

  const _LivreurCard({
    required this.livreur,
    required this.isSelected,
    required this.onTap,
    this.showZoneBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? AppColors.primaryOrange : AppColors.borderGray,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? const Color(0xFFFFF4ED) : Colors.white,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primaryOrangeLight,
                child: Text(
                  livreur.initiales,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryOrange,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Infos
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          livreur.nomComplet,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (showZoneBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ZONE PROCHE',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _EnginIcon(type: livreur.typeEngin),
                        const SizedBox(width: 4),
                        Text(
                          livreur.typeEngin,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Text(
                          ' · ',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          livreur.zonePrincipale,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    if (livreur.nbAvis > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${livreur.noteMoyenne.toStringAsFixed(1)} (${livreur.nbAvis})',
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
              // Tarif
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${livreur.tarifPourZone} F',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  Text(
                    'pour cette zone',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected
                    ? AppColors.primaryOrange
                    : AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnginIcon extends StatelessWidget {
  final String type;

  const _EnginIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (type.toLowerCase()) {
      case 'moto':
        icon = Icons.two_wheeler;
        break;
      case 'voiture':
        icon = Icons.directions_car;
        break;
      case 'velo':
        icon = Icons.pedal_bike;
        break;
      case 'tricycle':
        icon = Icons.electric_rickshaw;
        break;
      default:
        icon = Icons.local_shipping;
    }
    return Icon(icon, size: 14, color: AppColors.textSecondary);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉTAPE 4 : RÉCAPITULATIF & PAIEMENT
// ═══════════════════════════════════════════════════════════════════════════

class _RecapStep extends ConsumerWidget {
  final CartState cartState;
  final bool isProcessing;
  final TextEditingController nomController;
  final TextEditingController telephoneController;
  final TextEditingController adresseController;

  const _RecapStep({
    required this.cartState,
    required this.isProcessing,
    required this.nomController,
    required this.telephoneController,
    required this.adresseController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zone = ref.watch(selectedZoneProvider);
    final livreur = ref.watch(selectedLivreurProvider);
    final user = FirebaseService.instance.auth.currentUser;
    final isInvite = user == null;

    if (livreur == null || zone == null) {
      return const Center(child: Text('Données manquantes'));
    }

    final subtotal = cartState.totalAmount.toInt();
    final fraisLivraison = livreur.tarifPourZone;
    final total = subtotal + fraisLivraison;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Articles
                _RecapCard(
                  title: 'Articles',
                  child: Column(
                    children: cartState.itemsList
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${item.quantity}x ${item.produit.nom}',
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                ),
                                Text(
                                  '${(item.produit.prix * item.quantity).toStringAsFixed(0)} F',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),

                // Livraison
                _RecapCard(
                  title: 'Livraison',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primaryOrangeLight,
                            child: Text(
                              livreur.initiales,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  livreur.nomComplet,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${livreur.typeEngin} · $zone',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$fraisLivraison F',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${nomController.text} · ${telephoneController.text}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (adresseController.text.isNotEmpty)
                        Text(
                          adresseController.text,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Escrow info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const MiwodoSvgIcon(
                        'ic_lock.svg',
                        size: 18,
                        color: AppColors.primaryOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Paiement sécurisé',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Votre argent est protégé jusqu\'à confirmation de la livraison.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Invité info
                if (isInvite)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryOrange.withAlpha(50),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vous commandez en tant qu\'invité',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () => context.push('/inscription'),
                                child: Text(
                                  'Créer un compte',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.primaryOrange,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        _BottomBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SummaryRow(label: 'Articles', value: '$subtotal F'),
              const SizedBox(height: 4),
              _SummaryRow(label: 'Livraison', value: '$fraisLivraison F'),
              const Divider(height: 16),
              _SummaryRow(
                label: 'Total',
                value: '$total F CFA',
                labelStyle: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                valueStyle: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 12),
              MiwodoButton(
                label: 'Payer $total F en toute sécurité',
                icon: 'ic_lock.svg',
                fullWidth: true,
                isLoading: isProcessing,
                onPressed: isProcessing
                    ? null
                    : () => _checkout(context, ref, total),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref, int total) async {
    ref.read(checkoutLoadingProvider.notifier).state = true;

    try {
      final user = FirebaseService.instance.auth.currentUser;
      final zone = ref.read(selectedZoneProvider)!;
      final livreur = ref.read(selectedLivreurProvider)!;
      final geoState = ref.read(geoDetectionProvider);

      // Récupérer le pays sélectionné pour utiliser les bonnes méthodes de paiement
      final pays = ref.read(paysSelectionneProvider) ?? Pays.togo;

      // Vérifier que le pays a des méthodes de paiement configurées
      if (pays.monerooMethods.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le paiement en ligne n\'est pas disponible dans ce pays. Contactez le support.',
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      // Initier paiement Moneroo avec les paramètres du pays sélectionné
      final payment = await MonerooService.instance.initierCommande(
        montant: total,
        clientEmail:
            user?.email ??
            '${telephoneController.text}@miwodo.${pays.id.toLowerCase()}',
        clientPrenom: nomController.text.split(' ').first,
        clientNom: nomController.text.split(' ').skip(1).join(' '),
        commandeId: DateTime.now().millisecondsSinceEpoch.toString(),
        paysId: pays.id,
        devise: pays.devise,
        methods: pays.monerooMethods,
      );

      if (!context.mounted) return;

      if (payment.checkoutUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: URL de paiement non reçue.')),
        );
        return;
      }

      final paymentId = await Navigator.push<String?>(
        context,
        MaterialPageRoute(
          builder: (_) => MonerooWebView(
            checkoutUrl: payment.checkoutUrl,
            paymentId: payment.id,
            onSuccess: (_) {},
            onFailure: () {},
            onClose: () {},
          ),
        ),
      );

      if (paymentId == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Paiement annulé')));
        }
        return;
      }

      // Vérifier le paiement avec retry (le paiement mobile money peut prendre du temps)
      MonerooVerifyResult? verify;
      for (int i = 0; i < 3; i++) {
        try {
          verify = await MonerooService.instance.verifierPaiement(paymentId);
          if (verify.status == 'success' || verify.status == 'successful')
            break;
          if (verify.status != 'pending') break;
          await Future.delayed(const Duration(seconds: 3));
        } catch (e) {
          if (i == 2) rethrow;
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      if (verify == null ||
          (verify.status != 'success' && verify.status != 'successful')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Paiement non confirmé (statut: ${verify?.status ?? 'inconnu'}). Si vous avez payé, contactez le support.',
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
        return;
      }

      // Créer la commande
      final articles = cartState.itemsList
          .map(
            (item) => ArticleCommande(
              produitId: item.produit.id,
              nom: item.produit.nom,
              prixUnitaire: item.produit.prix.toInt(),
              quantite: item.quantity,
              sousTotal: (item.produit.prix * item.quantity).toInt(),
              imageUrl: item.produit.imageUrl,
            ),
          )
          .toList();

      // Récupérer infos vendeur (premier produit)
      final vendeurId = cartState.itemsList.first.produit.prestataireId;

      final commande = await CommandeVendeurService.instance.creerCommande(
        estInscrit: user != null,
        clientUid: user?.uid,
        clientNom: nomController.text,
        clientTelephone: telephoneController.text,
        clientZone: zone,
        clientAdresseTexte: adresseController.text,
        clientCoords: geoState.position != null
            ? GeoPoint(
                geoState.position!.latitude,
                geoState.position!.longitude,
              )
            : null,
        vendeurId: vendeurId,
        vendeurNom: '', // À récupérer depuis Firestore
        livreurId: livreur.id,
        livreurNom: livreur.nomComplet,
        livreurTelephone: '', // À récupérer
        livreurTarifZone: livreur.tarifPourZone,
        livreurTypeEngin: livreur.typeEngin,
        articles: articles,
        monerooPaymentId: paymentId,
      );

      // Vider le panier
      ref.read(cartProvider.notifier).clear();
      ref.read(checkoutStepProvider.notifier).state = 0;
      ref.read(selectedLivreurProvider.notifier).state = null;

      // Enregistrer la transaction pour le dashboard admin
      try {
        await FirestoreService.instance.createTransaction(
          paymentId: paymentId,
          type: 'commande',
          montant: total.toDouble(),
        );
      } catch (e) {
        // non-blocking
      }
      ref.read(selectedZoneProvider.notifier).state = null;

      if (!context.mounted) return;

      // Naviguer vers suivi commande
      context.go('/suivi-commande/${commande.id}');
    } on MonerooException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.userMessage),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      ref.read(checkoutLoadingProvider.notifier).state = false;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGETS UTILITAIRES
// ═══════════════════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  final Widget child;

  const _BottomBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(child: child),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MiwodoSvgIcon(icon, size: 16, color: AppColors.primaryOrange),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _RecapCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _RecapCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style:
              labelStyle ??
              GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style:
              valueStyle ??
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ÉCRAN CONFIRMATION
// ═══════════════════════════════════════════════════════════════════════════

class CommandeConfirmationScreen extends StatefulWidget {
  final String commandeId;

  const CommandeConfirmationScreen({super.key, required this.commandeId});

  @override
  State<CommandeConfirmationScreen> createState() =>
      _CommandeConfirmationScreenState();
}

class _CommandeConfirmationScreenState extends State<CommandeConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(
                  parent: _controller,
                  curve: Curves.elasticOut,
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: AppColors.successGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Commande confirmée !',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Votre livreur a été notifié',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGray,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Numéro de commande',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.commandeId,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              MiwodoButton(
                label: 'Nouvelle commande',
                onPressed: () => context.go('/commander'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
