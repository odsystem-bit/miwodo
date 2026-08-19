// screens/auth/login_screen_v2.dart
// Premium login screen - Senior Dev Level
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/app_typography.dart';
import '../../services/auth_service.dart';
import '../../widgets/animated_button.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/miwodo_svg_icon.dart';

final loginLoadingProvider = StateProvider<bool>((ref) => false);
final loginErrorProvider = StateProvider<String?>((ref) => null);

class LoginScreenV2 extends ConsumerStatefulWidget {
  final bool isRegisterMode;
  final String? referralCode;

  const LoginScreenV2({super.key, this.isRegisterMode = false, this.referralCode});

  @override
  ConsumerState<LoginScreenV2> createState() => _LoginScreenV2State();
}

class _LoginScreenV2State extends ConsumerState<LoginScreenV2>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _isEmailValid = false;
  bool _isRegister = false;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _isRegister = widget.isRegisterMode;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 30),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
    _animController.forward();

    _phoneController.addListener(_validatePhone);
  }

  void _validatePhone() {
    final value = _phoneController.text;
    final isValid = value.length >= 6;
    if (isValid != _isEmailValid) {
      setState(() => _isEmailValid = isValid);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final identifier = _phoneController.text.trim();
    final password = _passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      ref.read(loginErrorProvider.notifier).state = 'Veuillez remplir tous les champs';
      return;
    }

    // Les comptes sont crees avec un vrai email a l'inscription.
    // Si l'utilisateur saisit un email, on l'utilise directement.
    // Sinon (numero de telephone) on le convertit au format @miwodo.app.
    final email = identifier.contains('@')
        ? identifier
        : '${identifier.replaceAll(RegExp(r'[^0-9]'), '')}@miwodo.app';

    ref.read(loginLoadingProvider.notifier).state = true;
    ref.read(loginErrorProvider.notifier).state = null;

    try {
      final userCred = await AuthService.instance.signInWithEmail(email, password, rememberMe: _rememberMe);
      final adminRole = await AuthService.instance.getAdminRole(userCred.user!.uid);
      AuthService.instance.setAdminRole(adminRole);
      if (mounted) {
        if (adminRole != null && adminRole.actif) {
          context.go('/admin');
        } else {
          context.go('/accueil');
        }
      }
    } on Exception catch (e) {
      ref.read(loginErrorProvider.notifier).state = _formatError(e.toString());
    } finally {
      if (mounted) {
        ref.read(loginLoadingProvider.notifier).state = false;
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final identifier = _phoneController.text.trim();
    final prefill = identifier.contains('@') ? identifier : '';
    final emailController = TextEditingController(text: prefill);
    bool isSending = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Mot de passe oublié',
            style: AppTypography.titleMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entrez votre adresse email. Vous recevrez un lien pour réinitialiser votre mot de passe.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'exemple@email.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFF97316)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFF97316)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Veuillez entrer un email valide')),
                        );
                        return;
                      }
                      setDialogState(() => isSending = true);
                      try {
                        await AuthService.instance.sendPasswordResetEmail(email);
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email de réinitialisation envoyé ! Vérifiez votre boîte de réception.'),
                              backgroundColor: Color(0xFF22C55E),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Erreur: ${e.toString()}')),
                          );
                        }
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    // Rediriger vers l'écran d'inscription complet avec paiement obligatoire
    // L'inscription ne peut se faire que via le formulaire complet avec paiement
    if (mounted) {
      context.go('/inscription');
    }
  }

  String _formatError(String error) {
    if (error.contains('user-not-found')) return 'Aucun compte trouvé avec cet email';
    if (error.contains('wrong-password')) return 'Mot de passe incorrect';
    if (error.contains('invalid-email')) return 'Adresse email invalide';
    if (error.contains('too-many-requests')) return 'Trop de tentatives. Réessayez plus tard';
    return 'Erreur de connexion. Vérifiez vos identifiants';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loginLoadingProvider);
    final error = ref.watch(loginErrorProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/accueil'),
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
        ),
      ),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFF7ED),
                    Color(0xFFFFFFFF),
                    Color(0xFFFED7AA),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF97316).withAlpha(20),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withAlpha(15),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      // Logo + tagline (matching maquette)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'miwodo',
                            style: AppTypography.displaySmall.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: const Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Artisans · Pros · Vendeurs · Livreurs',
                            style: AppTypography.bodySmall.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Title
                      Text(
                        _isRegister ? 'Inscription' : 'Connexion',
                        style: AppTypography.headlineMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.02,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRegister
                            ? 'Créez un compte pour rejoindre Miwodo'
                            : 'Connectez-vous pour accéder à votre espace',
                        style: AppTypography.bodyLarge.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Form Card
                      GlassCard(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Email or phone field
                            _buildTextField(
                              label: 'Email ou téléphone',
                              hint: 'exemple@email.com',
                              controller: _phoneController,
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: 'assets/icons/ic_user.svg',
                              textInputAction: TextInputAction.next,
                              onSubmitted: () => _passwordFocus.requestFocus(),
                            ),
                            const SizedBox(height: 20),
                            // Password field
                            _buildPasswordField(),
                            const SizedBox(height: 16),
                            // Error message
                            if (error != null)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFEF4444),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Forgot password (only in login mode)
                            if (!_isRegister)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showForgotPasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 40),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Mot de passe oublié ?',
                                    style: AppTypography.labelMedium.copyWith(
                                      color: const Color(0xFFF97316),
                                    ),
                                  ),
                                ),
                              ),
                            // Remember me checkbox (only in login mode)
                            if (!_isRegister)
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (v) => setState(() => _rememberMe = v ?? true),
                                      activeColor: const Color(0xFFF97316),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Se souvenir de moi',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            if (!_isRegister) const SizedBox(height: 16),
                            // Login/Register button
                            AnimatedButton(
                              label: _isRegister ? 'Créer un compte' : 'Se connecter',
                              onPressed: isLoading ? null : (_isRegister ? _signUp : _signIn),
                              isLoading: isLoading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Toggle login/register link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            if (_isRegister) {
                              setState(() => _isRegister = false);
                            } else {
                              // Rediriger vers l'inscription complète avec paiement
                              context.go('/inscription');
                            }
                          },
                          child: RichText(
                            text: TextSpan(
                              text: _isRegister ? 'Déjà un compte ? ' : 'Pas encore de compte ? ',
                              style: AppTypography.bodyMedium.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegister ? 'Se connecter' : 'S\'inscrire',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: const Color(0xFFF97316),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required TextInputType keyboardType,
    required String prefixIcon,
    required TextInputAction textInputAction,
    required VoidCallback onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: (_) => onSubmitted(),
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(16),
                child: MiwodoSvgIcon(
                  prefixIcon,
                  size: 20,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 56),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mot de passe',
          style: AppTypography.labelMedium.copyWith(
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _signIn(),
            style: AppTypography.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Votre mot de passe',
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: const Color(0xFF94A3B8),
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.all(16),
                child: Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 56),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: Color(0xFFF97316), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    );
  }
}
