// core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../screens/admin/admin_commandes_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/admin_equipe_screen.dart';
import '../../screens/admin/admin_notifications_screen.dart';
import '../../screens/admin/admin_retraits_screen.dart';
import '../../screens/admin/admin_prestataires_screen.dart';
import '../../screens/admin/admin_revenus_screen.dart';
import '../../screens/admin/admin_signalements_screen.dart';
import '../../screens/admin/admin_sponsoring_screen.dart';
import '../../screens/admin/admin_sponsoring_settings_screen.dart';
import '../../screens/admin/admin_configuration_screen.dart';
import '../../screens/admin/admin_users_screen.dart';
import '../../screens/admin/admin_avis_screen.dart';
import '../../screens/admin/admin_stats_screen.dart';
import '../../screens/commander/boutique_screen.dart';
import '../../screens/commander/panier_screen.dart';
import '../../screens/commande/suivi_commande_screen.dart';
import '../../screens/commande/mes_commandes_screen.dart';
import '../../screens/conversation_screen.dart';
import '../../screens/auth/login_screen_v2.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/messages/messages_screen.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/splash/onboarding_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/prestataire/prestataire_detail_screen.dart';
import '../../screens/prestataire/prestataire_profile_screen.dart';
import '../../screens/prestataire/mes_services_screen.dart';
import '../../screens/prestataire/mes_produits_screen.dart';
import '../../screens/prestataires_screen.dart';
import '../../screens/service/service_detail_screen.dart';
import '../../screens/inscription/selection_pays_screen.dart';
import '../../screens/inscription/inscription_screen.dart';
import '../../screens/guest_contact_screen.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  refreshListenable: AuthService.instance,
  initialLocation: '/splash',
  redirect: (context, state) {
    final location = state.uri.toString();

    // Laisser le splash et le login tranquilles (redirections explicites)
    if (location == '/splash' || location == '/login') return null;

    // Séparation stricte admin <-> utilisateur
    final isAdmin = AuthService.instance.isAdminUser;
    if (isAdmin) {
      // Un admin doit rester dans l'espace admin, sauf pour voir un profil prestataire
      if (!location.startsWith('/admin') &&
          !location.startsWith('/prestataire/'))
        return '/admin';
      return null;
    }

    // Utilisateur normal non connecté ou non-admin : ne pas rester dans /admin
    if (location.startsWith('/admin')) return '/accueil';

    return null;
  },
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        // Branch 0: Accueil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/accueil',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        // Branch 1: Boutique
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/commander',
              builder: (context, state) => const BoutiqueScreen(),
            ),
          ],
        ),
        // Branch 2: Commandes
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mes-commandes',
              builder: (context, state) => const MesCommandesScreen(),
              redirect: (context, state) {
                if (FirebaseService.instance.auth.currentUser == null) {
                  return '/login';
                }
                return null;
              },
            ),
          ],
        ),
        // Branch 3: Messages
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) => const MessagesScreen(),
              redirect: (context, state) {
                if (FirebaseService.instance.auth.currentUser == null) {
                  return '/login';
                }
                return null;
              },
            ),
          ],
        ),
        // Branch 4: Profil
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/compte',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
      ],
    ),
    // Espace admin complètement séparé de l'interface utilisateur
    ShellRoute(
      builder: (context, state, child) => child,
      routes: [
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const AdminUsersScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/stats',
          builder: (context, state) => const AdminStatsScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/prestataires',
          builder: (context, state) => const AdminPrestatairesScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/avis',
          builder: (context, state) => const AdminAvisScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/commandes',
          builder: (context, state) => const AdminCommandesScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/revenus',
          builder: (context, state) => const AdminRevenusScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/equipe',
          builder: (context, state) => const AdminEquipeScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/signalements',
          builder: (context, state) => const AdminSignalementsScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/sponsoring',
          builder: (context, state) => const AdminSponsoringScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/sponsoring/config',
          builder: (context, state) => const AdminSponsoringSettingsScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/notifications',
          builder: (context, state) => const AdminNotificationsScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
        GoRoute(
          path: '/admin/configuration',
          builder: (context, state) => const AdminConfigurationScreen(),
          redirect: (context, state) => _superAdminRedirect(state),
        ),
        GoRoute(
          path: '/admin/retraits',
          builder: (context, state) => const AdminRetraitsScreen(),
          redirect: (context, state) => _adminRedirect(state),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/prestataire/:id',
      builder: (context, state) =>
          PrestataireDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/service/:id',
      builder: (context, state) =>
          ServiceDetailScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/prestataires',
      builder: (context, state) => const PrestatairesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/profil/:id',
      builder: (context, state) =>
          PrestataireProfileScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/mes-services/:id',
      builder: (context, state) =>
          MesServicesScreen(prestataireId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/mes-produits/:id',
      builder: (context, state) =>
          MesProduitsScreen(prestataireId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/login',
      builder: (context, state) {
        final isRegister = state.uri.queryParameters['mode'] == 'register';
        return LoginScreenV2(isRegisterMode: isRegister);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/panier',
      builder: (context, state) => const PanierScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/suivi-commande/:id',
      builder: (context, state) =>
          SuiviCommandeScreen(commandeId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/messages/:id',
      builder: (context, state) =>
          ConversationScreen(id: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/contact/:id',
      builder: (context, state) =>
          GuestContactScreen(prestataireId: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/selection-pays',
      builder: (context, state) => SelectionPaysScreen(
        detectedCountryCode: state.uri.queryParameters['detected'],
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/parrainage/:code',
      builder: (context, state) {
        final code = state.pathParameters['code'];
        // Rediriger vers l'écran d'inscription avec le code parrain
        return InscriptionScreen(initialReferralCode: code);
      },
    ),
    GoRoute(
      parentNavigatorKey: _rootNavigatorKey,
      path: '/inscription',
      builder: (context, state) => const InscriptionScreen(),
    ),
  ],
);

Future<String?> _adminRedirect(GoRouterState state) async {
  final user = FirebaseService.instance.auth.currentUser;
  if (user == null) return '/accueil';
  final adminRole = await AuthService.instance.getAdminRole(user.uid);
  if (adminRole == null || !adminRole.actif) return '/accueil';

  final location = state.uri.toString();
  if (adminRole.role == 'super_admin') {
    return null;
  }

  final allowedModeratorPaths = [
    '/admin/users',
    '/admin/stats',
    '/admin/prestataires',
    '/admin/signalements',
    '/admin/sponsoring',
    '/admin/avis',
    '/admin/notifications',
    '/admin/retraits',
  ];
  if (location == '/admin') {
    return '/admin/users';
  }
  if (!allowedModeratorPaths.contains(location)) {
    return '/accueil';
  }
  return null;
}

Future<String?> _superAdminRedirect(GoRouterState state) async {
  final user = FirebaseService.instance.auth.currentUser;
  if (user == null) return '/accueil';
  final adminRole = await AuthService.instance.getAdminRole(user.uid);
  if (adminRole == null || !adminRole.actif || adminRole.role != 'super_admin')
    return '/accueil';
  return null;
}
