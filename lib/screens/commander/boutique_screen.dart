// screens/commander/boutique_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/produit.dart';
import '../../models/prestataire.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/miwodo_svg_icon.dart';
import 'commande_providers.dart';

enum CommanderTab { boutique, prestataires, panier, commandes }

class BoutiqueScreen extends ConsumerStatefulWidget {
  const BoutiqueScreen({super.key});

  @override
  ConsumerState<BoutiqueScreen> createState() => _BoutiqueScreenState();
}

class _BoutiqueScreenState extends ConsumerState<BoutiqueScreen> {
  CommanderTab _selectedTab = CommanderTab.boutique;

  @override
  Widget build(BuildContext context) {
    final cartCount = ref.watch(cartItemCountProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.white,
        title: Text(
          'Commander',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_selectedTab == CommanderTab.boutique)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  MiwodoSvgIcon(
                    'assets/icons/ic_cart.svg',
                    size: 16,
                    color: AppColors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$cartCount',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: CommanderTab.values.map((tab) {
          final isSelected = _selectedTab == tab;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primaryOrange : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _getTabLabel(tab),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getTabLabel(CommanderTab tab) {
    switch (tab) {
      case CommanderTab.boutique:
        return 'Boutique';
      case CommanderTab.prestataires:
        return 'Prestataires';
      case CommanderTab.panier:
        return 'Panier';
      case CommanderTab.commandes:
        return 'Mes commandes';
    }
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case CommanderTab.boutique:
        return const _BoutiqueTab();
      case CommanderTab.prestataires:
        return const _PrestatairesTab();
      case CommanderTab.panier:
        return const _PanierTab();
      case CommanderTab.commandes:
        return const _CommandesTab();
    }
  }
}

class _BoutiqueTab extends ConsumerWidget {
  const _BoutiqueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final vendeursAsync = ref.watch(vendeursProvider);
    final cartNotifier = ref.read(cartProvider.notifier);
    final cartState = ref.watch(cartProvider);
    final currentPrestataire = ref.watch(currentUserPrestataireProvider).valueOrNull;
    final isVendeur = currentPrestataire?.isVendeur ?? false;

    return productsAsync.when(
      data: (products) {
        final vendeurs = vendeursAsync.maybeWhen(
          data: (data) => data,
          orElse: () => const [],
        );
        final Map<String, List<Produit>> sections = {};
        for (final produit in products) {
          sections.putIfAbsent(produit.prestataireId, () => []).add(produit);
        }

        final sellersById = {
          for (final vendeur in vendeurs) vendeur.id: vendeur,
        };
        final orderedSections = sections.entries.toList()
          ..sort((a, b) {
            final aName = sellersById[a.key]?.nom ?? 'Vendeur';
            final bName = sellersById[b.key]?.nom ?? 'Vendeur';
            return aName.compareTo(bName);
          });

        if (orderedSections.isEmpty) {
          return Stack(
            children: [
              Center(
                child: Text(
                  'Aucun produit disponible pour le moment.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (isVendeur)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.extended(
                    onPressed: () => context.push('/mes-produits/${currentPrestataire!.id}'),
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: Text('Mes produits', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          );
        }

        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orderedSections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final section = orderedSections[index];
                final vendeur = sellersById[section.key];
                final vendeurName = vendeur != null ? vendeur.nom : 'Vendeur';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendeurName,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(height: 1, color: AppColors.borderGray),
                    const SizedBox(height: 12),
                    ...section.value.map((produit) {
                      final quantity = cartState.quantityFor(produit.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProductCard(
                          produit: produit,
                          vendeurName: vendeurName,
                          quantity: quantity,
                          onAdd: () => cartNotifier.add(produit),
                          onRemove: () => cartNotifier.decrement(produit),
                          vendeur: sellersById[section.key],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
            if (isVendeur)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton.extended(
                  onPressed: () => context.push('/mes-produits/${currentPrestataire!.id}'),
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: Text('Mes produits', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Impossible de charger les produits.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PanierTab extends ConsumerWidget {
  const _PanierTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartProvider.notifier);

    if (cartState.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MiwodoSvgIcon(
              'assets/icons/ic_cart.svg',
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Votre panier est vide',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/boutique'),
              child: const Text('Parcourir la boutique'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: cartState.itemsList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = cartState.itemsList[index];
              return _CartItem(
                item: item,
                onRemove: () => cartNotifier.remove(item.produit),
                onIncrement: () => cartNotifier.add(item.produit),
                onDecrement: () => cartNotifier.decrement(item.produit),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${cartState.totalAmount.toStringAsFixed(0)} F CFA',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/panier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Passer la commande'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommandesTab extends ConsumerWidget {
  const _CommandesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MiwodoSvgIcon(
            'assets/icons/ic_cart.svg',
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune commande pour le moment',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final CartItem item;
  final VoidCallback onRemove;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _CartItem({
    required this.item,
    required this.onRemove,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.produit.imageUrl != null && item.produit.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: item.produit.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        color: AppColors.surfaceGray,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        color: AppColors.surfaceGray,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: AppColors.surfaceGray,
                      child: const Icon(Icons.image, color: Colors.grey, size: 24),
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.produit.prix.toStringAsFixed(0)} F CFA',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onDecrement,
                ),
                Text(
                  '${item.quantity}',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onIncrement,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Produit produit;
  final String vendeurName;
  final int quantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final Prestataire? vendeur;

  const _ProductCard({
    required this.produit,
    required this.vendeurName,
    required this.quantity,
    required this.onAdd,
    required this.onRemove,
    this.vendeur,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: AppColors.white,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: produit.imageUrl != null && produit.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: produit.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 60,
                        height: 60,
                        color: AppColors.surfaceGray,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 60,
                        height: 60,
                        color: AppColors.surfaceGray,
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: AppColors.surfaceGray,
                      child: const Center(
                        child: Icon(Icons.image, color: Colors.grey, size: 24),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    produit.nom,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vendeurName,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${produit.prix.toStringAsFixed(0)} ${vendeur?.symbole ?? 'F CFA'}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            quantity > 0
                ? Row(
                    children: [
                      _ActionButton(icon: Icons.remove, onTap: onRemove),
                      const SizedBox(width: 8),
                      Text(
                        '$quantity',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ActionButton(icon: Icons.add, onTap: onAdd),
                    ],
                  )
                : _ActionButton(icon: Icons.add, onTap: onAdd),
          ],
        ),
      ),
    );
  }
}

class _PrestatairesTab extends StatelessWidget {
  const _PrestatairesTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 64,
            color: AppColors.borderGray,
          ),
          const SizedBox(height: 16),
          Text(
            'Trouvez des prestataires',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Filtrez par ville, pays et catégorie',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/prestataires'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Voir tous les prestataires',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.primaryOrange,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
