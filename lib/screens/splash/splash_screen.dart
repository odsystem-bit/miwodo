// screens/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Full screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Scale animation (0.5 -> 1.0)
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    // Fade animation for text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animations
    Future.delayed(const Duration(milliseconds: 300), () {
      _scaleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      _fadeController.forward();
    });

    // Navigate after animations directly to home
    Future.delayed(const Duration(milliseconds: 1800), () {
      _naviguerVersAccueil();
    });
  }

  Future<void> _naviguerVersAccueil() async {
    if (!mounted) return;
    final user = await FirebaseService.instance.auth.authStateChanges().first;
    if (!mounted) return;

    if (user != null) {
      final adminRole = await AuthService.instance.getAdminRole(user.uid);
      AuthService.instance.setAdminRole(adminRole);
      if (!mounted) return;
      if (adminRole != null && adminRole.actif) {
        context.go('/admin');
        return;
      }
    }

    // Check if onboarding has been completed
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;

    if (!onboardingDone) {
      context.go('/onboarding');
    } else {
      context.go('/accueil');
    }
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryOrange,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo avec animation scale
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Image.asset(
                    'assets/images/logo.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback si l'image n'existe pas encore
                      return Container(
                        color: Colors.white,
                        child: const Center(
                          child: Text(
                            'M',
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryOrange,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Texte avec fade
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    'MIWODO',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(
                          color: Colors.black.withAlpha(30),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Artisans · Pros · Vendeurs · Livreurs',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.white.withAlpha(230),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60),
            // Loading indicator
            FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withAlpha(200),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
