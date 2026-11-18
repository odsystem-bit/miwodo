// screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../screens/commander/commande_providers.dart';
import '../services/firebase_service.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    _TabItem(label: 'Accueil', icon: 'assets/icons/ic_home.svg'),
    _TabItem(label: 'Boutique', icon: 'assets/icons/ic_cart.svg'),
    _TabItem(label: 'Commandes', icon: 'assets/icons/ic_orders.svg'),
    _TabItem(label: 'Messages', icon: 'assets/icons/ic_chat.svg'),
    _TabItem(label: 'Profil', icon: 'assets/icons/ic_user.svg'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = FirebaseService.instance.auth.currentUser != null;

    // Construire la liste des onglets visibles et le mapping vers les indices de branches
    final visibleTabs = <_TabItem>[];
    final branchIndices = <int>[];

    for (var i = 0; i < _tabs.length; i++) {
      // Skip Commandes (index 2) si non connecté
      if (i == 2 && !isLoggedIn) continue;
      visibleTabs.add(_tabs[i]);
      branchIndices.add(i);
    }

    // Trouver l'index UI correspondant à la branche actuellement active
    final currentBranch = navigationShell.currentIndex;
    final currentUiIndex = branchIndices.indexOf(currentBranch);
    final safeIndex = currentUiIndex >= 0 ? currentUiIndex : 0;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: BottomNavigationBar(
          currentIndex: safeIndex,
          onTap: (uiIndex) {
            final branchIndex = branchIndices[uiIndex];
            navigationShell.goBranch(
              branchIndex,
              initialLocation: branchIndex == currentBranch,
            );
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppColors.brandOrange,
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: List.generate(visibleTabs.length, (i) {
            final tab = visibleTabs[i];
            final isActive = i == safeIndex;
            return BottomNavigationBarItem(
              label: tab.label,
              icon: _buildIcon(context, tab, isActive),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, _TabItem tab, bool isActive) {
    final color = isActive ? AppColors.primaryOrange : const Color(0xFF9CA3AF);

    // Badge rouge sur l'onglet Boutique (index 1)
    if (tab.label == 'Boutique') {
      return Consumer(
        builder: (context, ref, child) {
          final cartCount = ref.watch(cartItemCountProvider);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SvgPicture.asset(
                tab.icon,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              ),
              if (cartCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        cartCount > 9 ? '9+' : '$cartCount',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return SvgPicture.asset(
      tab.icon,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon});
  final String label;
  final String icon;
}
