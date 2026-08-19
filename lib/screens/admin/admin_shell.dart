// screens/admin/admin_shell.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/miwodo_svg_icon.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminRole = ref.watch(adminRoleProvider).asData?.value;
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final location = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.toString();
    final destinations = _destinations(isSuperAdmin);
    final selectedIndex = _selectedIndex(location, isSuperAdmin);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primaryOrange,
        elevation: 0,
        title: Text(
          title,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        iconTheme: const IconThemeData(color: AppColors.white),
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
                .where('estLu', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: AppColors.white),
                    onPressed: () => context.go('/admin/notifications'),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.errorRed,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          count > 99 ? '99+' : '$count',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.white,
                      child: Text(
                        _initials(adminRole?.nom ?? adminRole?.email ?? 'A'),
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryOrange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminRole?.nom ??
                                adminRole?.email ??
                                'Administrateur',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryOrange.withAlpha(38),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              adminRole?.label ?? 'Administrateur',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryOrange,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Panel Administration Miwodo',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'v2.0',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.successGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: destinations[index].icon,
                      title: destinations[index].label,
                      selectedTileColor: AppColors.primaryOrange.withAlpha(20),
                      selectedColor: AppColors.primaryOrange,
                      selected: selectedIndex == index,
                      onTap: () => _onDestinationSelected(context, index, isSuperAdmin),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.errorRed,
                    ),
                    onPressed: () async {
                      try {
                        await AuthService.instance.signOut();
                      } catch (e) {
                        if (kDebugMode) print('[AdminShell] signOut error: $e');
                      }
                      try {
                        await NotificationService.instance.removeToken();
                      } catch (e) {
                        // Best-effort cleanup
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close drawer
                        context.go('/login');
                      }
                    },
                    child: Text(
                      'Déconnexion',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: child,
    );
  }

  List<NavigationDrawerDestination> _destinations(bool isSuperAdmin) {
    final all = <NavigationDrawerDestination>[
      NavigationDrawerDestination(
        icon: MiwodoSvgIcon('assets/icons/ic_dashboard.svg', color: AppColors.primaryOrange),
        label: const Text('Dashboard'),
      ),
      NavigationDrawerDestination(
        icon: MiwodoSvgIcon('assets/icons/ic_users.svg', color: AppColors.primaryOrange),
        label: const Text('Utilisateurs'),
      ),
      NavigationDrawerDestination(
        icon: MiwodoSvgIcon('assets/icons/ic_briefcase.svg', color: AppColors.primaryOrange),
        label: const Text('Prestataires'),
      ),
      NavigationDrawerDestination(
        icon: MiwodoSvgIcon('assets/icons/ic_chart.svg', color: AppColors.primaryOrange),
        label: const Text('Statistiques'),
      ),
      NavigationDrawerDestination(
        icon: MiwodoSvgIcon('assets/icons/ic_flag.svg', color: AppColors.primaryOrange),
        label: const Text('Signalements'),
      ),
      NavigationDrawerDestination(
        icon: Icon(Icons.campaign, color: AppColors.primaryOrange),
        label: const Text('Sponsoring'),
      ),
      NavigationDrawerDestination(
        icon: MiwodoSvgIcon('assets/icons/ic_star.svg', color: AppColors.primaryOrange),
        label: const Text('Avis'),
      ),
      NavigationDrawerDestination(
        icon: Icon(Icons.notifications, color: AppColors.primaryOrange),
        label: const Text('Notifications'),
      ),
      NavigationDrawerDestination(
        icon: Icon(Icons.account_balance_wallet, color: AppColors.primaryOrange),
        label: const Text('Retraits'),
      ),
    ];

    if (isSuperAdmin) {
      all.addAll([
        NavigationDrawerDestination(
          icon: MiwodoSvgIcon('assets/icons/ic_orders.svg', color: AppColors.primaryOrange),
          label: const Text('Commandes'),
        ),
        NavigationDrawerDestination(
          icon: MiwodoSvgIcon('assets/icons/ic_team.svg', color: AppColors.primaryOrange),
          label: const Text('Équipe'),
        ),
        NavigationDrawerDestination(
          icon: MiwodoSvgIcon('assets/icons/ic_settings.svg', color: AppColors.primaryOrange),
          label: const Text('Configuration'),
        ),
        NavigationDrawerDestination(
          icon: MiwodoSvgIcon('assets/icons/ic_chart.svg', color: AppColors.primaryOrange),
          label: const Text('Revenus'),
        ),
      ]);
    }

    return all;
  }

  int _selectedIndex(String location, bool isSuperAdmin) {
    // Modérateur: Dashboard(0), Utilisateurs(1), Prestataires(2), Statistiques(3), Signalements(4), Sponsoring(5), Avis(6), Notifications(7), Retraits(8)
    // SuperAdmin: + Commandes(9), Équipe(10), Config(11), Revenus(12)
    if (location.startsWith('/admin/users')) return 1;
    if (location.startsWith('/admin/prestataires')) return 2;
    if (location.startsWith('/admin/stats')) return 3;
    if (location.startsWith('/admin/signalements')) return 4;
    if (location.startsWith('/admin/sponsoring')) return 5;
    if (location.startsWith('/admin/avis')) return 6;
    if (location.startsWith('/admin/notifications')) return 7;
    if (location.startsWith('/admin/retraits')) return 8;
    if (isSuperAdmin) {
      if (location.startsWith('/admin/commandes')) return 9;
      if (location.startsWith('/admin/equipe')) return 10;
      if (location.startsWith('/admin/configuration')) return 11;
      if (location.startsWith('/admin/revenus')) return 12;
    }
    return 0;
  }

  void _onDestinationSelected(
    BuildContext context,
    int index,
    bool isSuperAdmin,
  ) {
    // Modérateur: Dashboard(0), Utilisateurs(1), Prestataires(2), Statistiques(3), Signalements(4), Sponsoring(5), Avis(6), Notifications(7)
    final moderatorRoutes = ['/admin', '/admin/users', '/admin/prestataires', '/admin/stats', '/admin/signalements', '/admin/sponsoring', '/admin/avis', '/admin/notifications', '/admin/retraits'];
    // SuperAdmin: ajoute Commandes, Équipe, Configuration, Revenus
    final superAdminRoutes = [
      ...moderatorRoutes,
      '/admin/commandes',
      '/admin/equipe',
      '/admin/configuration',
      '/admin/revenus',
    ];

    final routes = isSuperAdmin ? superAdminRoutes : moderatorRoutes;
    if (index < routes.length) {
      context.go(routes[index]);
    }
  }

  String _initials(String value) {
    final parts = value.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : 'A';
  }
}
