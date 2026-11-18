// screens/guest_contact_screen.dart
// Écran pour permettre aux invités (non connectés) de contacter un prestataire

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/app_colors.dart';
import '../models/prestataire.dart';
import '../services/message_api_service.dart';
import '../widgets/miwodo_button.dart';
import '../widgets/miwodo_svg_icon.dart';

class GuestContactScreen extends ConsumerStatefulWidget {
  const GuestContactScreen({super.key, required this.prestataireId});

  final String prestataireId;

  @override
  ConsumerState<GuestContactScreen> createState() => _GuestContactScreenState();
}

class _GuestContactScreenState extends ConsumerState<GuestContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;
  Prestataire? _prestataire;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrestataire();
    _loadSavedGuestInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrestataire() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('prestataires')
          .doc(widget.prestataireId)
          .get();
      if (doc.exists) {
        setState(() {
          _prestataire = Prestataire.fromJson({...doc.data()!, 'id': doc.id});
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSavedGuestInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('guest_name');
    final savedPhone = prefs.getString('guest_phone');
    if (savedName != null) _nameController.text = savedName;
    if (savedPhone != null) _phoneController.text = savedPhone;
  }

  Future<void> _saveGuestInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_name', _nameController.text.trim());
    await prefs.setString('guest_phone', _phoneController.text.trim());
  }

  String _generateGuestId() {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return 'guest_$phone';
  }

  String _generateConversationId(String guestId, String prestataireId) {
    final ids = [guestId, prestataireId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    if (_messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez écrire un message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _saveGuestInfo();

      final guestId = _generateGuestId();
      final conversationId = _generateConversationId(guestId, widget.prestataireId);
      final guestName = _nameController.text.trim();
      final guestPhone = _phoneController.text.trim();
      final messageText = _messageController.text.trim();

      // 1. Envoyer le message vers MySQL
      await MessageApiService.instance.sendMessage(
        conversationId: conversationId,
        expediteurId: guestId,
        destinataireId: widget.prestataireId,
        contenu: messageText,
        type: 'text',
        isGuest: true,
        guestName: guestName,
        guestPhone: guestPhone,
      );

      // 2. Notifier le prestataire (MySQL)
      try {
        await MessageApiService.instance.createNotification(
          userId: widget.prestataireId,
          title: guestName.isEmpty ? 'Invité' : guestName,
          body: messageText,
          type: 'message',
          targetId: conversationId,
        );
      } catch (e) {
        if (kDebugMode) print('[GuestContact] Notification error: $e');
      }

      // 3. Sauvegarder l'ID de conversation localement pour le retour
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_guest_conversation_id', conversationId);
      await prefs.setString('last_guest_id', guestId);
      await prefs.setString('last_guest_name', guestName);
      final guestConvs = prefs.getStringList('guest_conversations') ?? [];
      if (!guestConvs.contains(conversationId)) {
        guestConvs.add(conversationId);
        await prefs.setStringList('guest_conversations', guestConvs);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Message envoyé à ${_prestataire?.prenom ?? "le prestataire"}'),
            backgroundColor: AppColors.successGreen,
          ),
        );

        // 4. Naviguer vers la conversation pour voir les réponses en temps réel
        context.push('/messages/$conversationId');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const MiwodoSvgIcon('assets/icons/ic_arrow_back.svg', size: 24),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Contacter ${_prestataire?.prenom ?? "le prestataire"}',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _prestataire == null
              ? Center(
                  child: Text(
                    'Prestataire introuvable',
                    style: GoogleFonts.inter(color: AppColors.textSecondary),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Info prestataire
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.primaryOrangeLight,
                                backgroundImage: _prestataire!.photoUrl != null
                                    ? NetworkImage(_prestataire!.photoUrl!)
                                    : null,
                                child: _prestataire!.photoUrl == null
                                    ? Text(
                                        _prestataire!.prenom[0].toUpperCase(),
                                        style: GoogleFonts.inter(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryOrange,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_prestataire!.prenom} ${_prestataire!.nom}',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _prestataire!.categorie,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Titre section
                        Text(
                          'Vos coordonnées',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pour que le prestataire puisse vous recontacter',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Nom
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Votre nom *',
                            hintText: 'Ex: Jean Dupont',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Veuillez entrer votre nom';
                            }
                            if (v.trim().length < 2) {
                              return 'Nom trop court';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        // Téléphone
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Votre téléphone *',
                            hintText: 'Ex: 90 12 34 56',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Veuillez entrer votre téléphone';
                            }
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if (digits.length < 8) {
                              return 'Numéro invalide';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Message
                        Text(
                          'Votre message',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: _messageController,
                          maxLines: 5,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText: 'Décrivez votre besoin...',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Bouton envoyer
                        SizedBox(
                          width: double.infinity,
                          child: MiwodoButton(
                            label: _isSending ? 'Envoi en cours...' : 'Envoyer le message',
                            icon: 'assets/icons/ic_send.svg',
                            variant: MiwodoButtonVariant.primary,
                            onPressed: _isSending ? null : _sendMessage,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryOrangeLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const MiwodoSvgIcon(
                                'assets/icons/ic_info.svg',
                                size: 20,
                                color: AppColors.primaryOrange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Le prestataire recevra votre message et pourra vous contacter directement par téléphone.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
