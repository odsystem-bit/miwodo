// screens/auth/login_screen_v2.dart
// Premium login screen - Senior Dev Level
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
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

    ref.read(loginLoadingProvider.notifier).state = true;
    ref.read(loginErrorProvider.notifier).state = null;

    // 1. Détection prioritaire Commercial (ex: COM-STAN ou téléphone commercial)
    if (identifier.toUpperCase().startsWith('COM-') || (!identifier.contains('@') && identifier.length >= 6)) {
      try {
        final comRes = await http.post(
          Uri.parse('https://bot.odsysteme.tech/api/commercial_auth.php'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'login',
            'identifier': identifier,
            'password': password,
          }),
        ).timeout(const Duration(seconds: 4));

        if (comRes.statusCode == 200) {
          final comData = jsonDecode(comRes.body);
          if (comData['success'] == true && comData['role'] == 'commercial') {
            if (mounted) {
              ref.read(loginLoadingProvider.notifier).state = false;
              context.go('/commercial', extra: comData['commercial']);
              return;
            }
          }
        }
      } catch (_) {
        // Poursuivre vers l'authentification standard si ce n'est pas un commercial
      }
    }

    try {
      String email;
      
      if (identifier.contains('@')) {
        // L'utilisateur a saisi un email directement
        email = identifier;
      } else {
        // L'utilisateur a saisi un numéro de téléphone
        // Chercher le prestataire par téléphone pour récupérer son email
        final phone = identifier.replaceAll(RegExp(r'[^0-9]'), '');
        final snap = await FirebaseService.instance.firestore
            .collection('prestataires')
            .where('telephone', isEqualTo: phone)
            .limit(1)
            .get();
        
        if (snap.docs.isNotEmpty) {
          final data = snap.docs.first.data();
          email = data['email'] as String? ?? '$phone@miwodo.app';
          if (kDebugMode) print('[Login] Found prestataire email: $email');
        } else {
          // Fallback: essayer avec le format @miwodo.app
          email = '$phone@miwodo.app';
          if (kDebugMode) print('[Login] No prestataire found, using fallback: $email');
        }
      }

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
                              content: Text('Email de réinitialisation envoyé ! Vérifiez votre boîte de réception (et vos spams).'),
                              backgroundColor: Color(0xFF22C55E),
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } on FirebaseAuthException catch (e) {
                        setDialogState(() => isSending = false);
                        String errorMsg;
                        switch (e.code) {
                          case 'user-not-found':
                            errorMsg = 'Aucun compte trouvé avec cet email.';
                            break;
                          case 'invalid-email':
                            errorMsg = 'Adresse email invalide.';
                            break;
                          case 'too-many-requests':
                            errorMsg = 'Trop de tentatives. Réessayez plus tard.';
                            break;
                          case 'network-request-failed':
                            errorMsg = 'Erreur réseau. Vérifiez votre connexion.';
                            break;
                          default:
                            errorMsg = 'Erreur: ${e.message ?? e.code}';
                        }
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(errorMsg),
                              backgroundColor: const Color(0xFFDC2626),
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSending = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('Erreur inattendue. Réessayez.'),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
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
                      const SizedBox(height: 12),
                      // Logo + Brand identity matching the posters
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF7A00).withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/images/logo.jpeg',
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MIWODO',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  fontSize: 22,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Artisans · Pros · Vendeurs · Livreurs',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      // Title
                      Text(
                        _isRegister ? 'Créer un compte' : 'Bon retour parmi nous 👋',
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isRegister
                            ? 'Rejoignez la plus grande communauté de professionnels'
                            : 'Connectez-vous pour gérer vos demandes et activités',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 32),
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
