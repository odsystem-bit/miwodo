import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme_v2.dart';
import 'services/config_service.dart';
import 'services/firebase_service.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.instance.initialize();
  await SupabaseService.initialize();

  // Initialiser les services en parallèle (fire-and-forget)
  unawaited(ConfigService.instance.initializePaysDefaults(force: true));
  unawaited(NotificationService.instance.initialize(router: appRouter));

  runApp(const ProviderScope(child: MiwodoApp()));
}

class MiwodoApp extends StatelessWidget {
  const MiwodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Miwodo',
      debugShowCheckedModeBanner: false,
      theme: AppThemeV2.lightTheme,
      routerConfig: appRouter,
    );
  }
}
