// screens/splash/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/miwodo_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  final _pages = const [
    _OnboardPage(
      icon: 'assets/icons/ic_artisan.svg',
      title: 'Artisans & Professionnels',
      description:
          'Trouvez maçons, menuisiers, électriciens, avocats, médecins et bien plus près de chez vous.',
      features: ['500 F inscription', '100 F/parrainage', 'Paiements directs', 'Multi-pays'],
    ),
    _OnboardPage(
      icon: 'assets/icons/ic_vendeur.svg',
      title: 'Boutiques & Restaurants',
      description:
          'Commandez vos produits en ligne, payez directement et faites-les livrer à domicile.',
      features: ['500 F inscription', '100 F/parrainage', 'Paiements directs', 'Multi-pays'],
    ),
    _OnboardPage(
      icon: 'assets/icons/ic_livreur.svg',
      title: 'Livraison Express',
      description:
          'Livreurs disponibles par moto, voiture ou vélo. Tarifs transparents par zone.',
      features: ['500 F inscription', '100 F/parrainage', 'Paiements directs', 'Multi-pays'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      context.go('/selection-pays');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 20),
                child: TextButton(
                  onPressed: _finishOnboarding,
                  child: Text(
                    'Passer',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            // Logo
            const MiwodoLogo(size: 80, showText: false, textSpacing: 0),
            const SizedBox(height: 4),
            Text(
              'miwodo',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 2,
              ),
            ),
            Text(
              'Artisans · Pros · Vendeurs · Livreurs',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _animController.reset();
                  _animController.forward();
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _OnboardContent(page: page),
                  );
                },
              ),
            ),
            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? AppColors.primaryOrange
                          : AppColors.borderGray,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            // CTA button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _onNext,
                  child: Text(
                    _currentPage < _pages.length - 1
                        ? 'Suivant'
                        : 'C\'est parti !',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
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

class _OnboardPage {
  final String icon;
  final String title;
  final String description;
  final List<String> features;

  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.features,
  });
}

class _OnboardContent extends StatelessWidget {
  final _OnboardPage page;

  const _OnboardContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primaryOrangeLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Center(
              child: SvgPicture.asset(
                page.icon,
                width: 56,
                height: 56,
                colorFilter: const ColorFilter.mode(
                  AppColors.primaryOrange,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          // Features chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: page.features.map((f) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrangeLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryOrange.withAlpha(40),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/ic_money.svg',
                      width: 14,
                      height: 14,
                      colorFilter: const ColorFilter.mode(
                        AppColors.primaryOrange,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryOrange,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
