// screens/inscription/inscription_confirmation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

class InscriptionConfirmationScreen extends StatefulWidget {
  final String prestataireId;
  final String referralLink;

  const InscriptionConfirmationScreen({super.key, required this.prestataireId, required this.referralLink});

  @override
  State<InscriptionConfirmationScreen> createState() => _InscriptionConfirmationScreenState();
}

class _InscriptionConfirmationScreenState extends State<InscriptionConfirmationScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
                child: Opacity(
                  opacity: _ctrl.value,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(color: AppColors.successGreen, shape: BoxShape.circle),
                    child: const Center(child: MiwodoSvgIcon('assets/icons/ic_verified.svg', size: 40, color: Colors.white)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Bienvenue sur Miwodo !', style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(child: Text(widget.referralLink, style: const TextStyle(fontSize: 14))),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.referralLink));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié')));
                        },
                        icon: const Icon(Icons.copy),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              MiwodoButton(
                label: 'Voir mon tableau de bord',
                onPressed: () => context.go('/accueil'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
