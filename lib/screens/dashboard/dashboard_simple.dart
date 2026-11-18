// screens/dashboard/dashboard_simple.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/miwodo_button.dart';

class DashboardSimple extends ConsumerWidget {
  const DashboardSimple({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: AppColors.primaryOrange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Dashboard (simplifié pour tests)',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            MiwodoButton(
              label: 'Aller à l\'inscription',
              onPressed: () => context.push('/inscription'),
            ),
            const SizedBox(height: 8),
            MiwodoButton(
              label: 'Aller au panier',
              onPressed: () => context.push('/panier'),
            ),
          ],
        ),
      ),
    );
  }
}
