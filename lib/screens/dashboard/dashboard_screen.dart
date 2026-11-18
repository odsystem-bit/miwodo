// screens/dashboard/dashboard_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../models/demande_retrait.dart';
import '../../models/prestataire.dart';
import '../../providers/pays_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/firestore_service.dart';
import '../../services/retrait_service.dart';
import '../../widgets/livreur_courses_widget.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  Prestataire? _prestataire;
  bool _isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseService.instance.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final p = await FirestoreService.instance.getPrestataire(user.uid);
      if (mounted) {
        setState(() {
          _prestataire = p;
          _isLoading = false;
        });
        if (p != null) {
          _tabController = TabController(length: 6, vsync: this);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (mounted) context.go('/accueil');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseService.instance.auth.currentUser;
    final isAdmin = AuthService.instance.isAdminUser;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surfaceGray,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryOrange)),
      );
    }

    if (user == null) {
      return _buildGuestView();
    }

    if (isAdmin) {
      return _buildAdminRedirect();
    }

    if (_prestataire == null) {
      return _buildNoProfileView();
    }

    return _buildPrestataireDashboard();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VUE NON-CONNECTÉ
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildGuestView() {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: const MiwodoSvgIcon('assets/icons/ic_user.svg', size: 36, color: AppColors.primaryOrange),
              ),
              const SizedBox(height: 24),
              Text(
                'Bienvenue sur Miwodo',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Connectez-vous pour accéder à votre espace et gérer vos services.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              MiwodoButton(
                label: 'Se connecter',
                onPressed: () => context.push('/login'),
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              MiwodoButton(
                label: 'Créer un compte',
                onPressed: () => context.go('/inscription'),
                fullWidth: true,
                variant: MiwodoButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VUE ADMIN (redirection)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminRedirect() {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.admin_panel_settings, size: 64, color: AppColors.primaryOrange),
              const SizedBox(height: 16),
              Text(
                'Espace Admin',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Vous êtes connecté en tant qu\'administrateur.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              MiwodoButton(
                label: 'Aller au dashboard admin',
                onPressed: () => context.go('/admin'),
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _logout,
                child: Text('Se déconnecter', style: GoogleFonts.inter(color: AppColors.errorRed)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VUE CONNECTÉ SANS PROFIL PRESTATAIRE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildNoProfileView() {
    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        title: const Text('Mon compte'),
        backgroundColor: AppColors.primaryOrange,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 20),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrangeLight,
                  shape: BoxShape.circle,
                ),
                child: const MiwodoSvgIcon('assets/icons/ic_briefcase.svg', size: 36, color: AppColors.primaryOrange),
              ),
              const SizedBox(height: 24),
              Text(
                'Créez votre profil',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Devenez artisan, professionnel, vendeur ou livreur sur Miwodo.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              MiwodoButton(
                label: 'Créer mon profil',
                onPressed: () => context.go('/inscription'),
                fullWidth: true,
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () => _confirmDeleteAccount(),
                icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.errorRed),
                label: Text(
                  'Supprimer mon compte',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.errorRed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Supprimer définitivement mon compte ?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppColors.errorRed, fontSize: 17),
        ),
        content: Text(
          'Attention : cette action est irréversible. Toutes vos informations de profil, coordonnées et données associées seront supprimées définitivement de Miwodo.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer la suppression'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await AuthService.instance.deleteAccount();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre compte a été supprimé avec succès.'),
              backgroundColor: AppColors.infoBlue,
            ),
          );
          context.go('/accueil');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
          );
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VUE CONNECTÉ AVEC PROFIL PRESTATAIRE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPrestataireDashboard() {
    final p = _prestataire!;
    final pays = ref.watch(paysSelectionneProvider);
    final symbole = pays?.symbole ?? p.symbole;

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.primaryOrange,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildDashboardHeader(p, symbole),
            ),
            actions: [
              IconButton(
                onPressed: _logout,
                icon: const Icon(Icons.logout, size: 20, color: Colors.white),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primaryOrange,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primaryOrange,
                labelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
                isScrollable: true,
                tabs: [
                  const Tab(text: 'Vue d\'ensemble'),
                  Tab(text: p.isVendeur ? 'Produits' : (p.isLivreur ? 'Disponibilité' : 'Services')),
                  Tab(text: p.isLivreur ? 'Mes Courses' : 'Commandes'),
                  const Tab(text: 'Messages'),
                  const Tab(text: 'Parrainage'),
                  const Tab(text: 'Publicité'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(p, symbole),
            _buildServicesTab(p),
            _buildCommandesTab(p),
            _buildMessagesTab(),
            _buildParrainageTab(p, symbole),
            _buildPubliciteTab(p),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardHeader(Prestataire p, String symbole) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.brandGradient,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage: p.photoUrl != null && p.photoUrl!.isNotEmpty
                        ? CachedNetworkImageProvider(p.photoUrl!) as ImageProvider
                        : null,
                    child: p.photoUrl == null || p.photoUrl!.isEmpty
                        ? Text(
                            '${p.prenom.isNotEmpty ? p.prenom[0] : ''}${p.nom.isNotEmpty ? p.nom[0] : ''}',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p.prenom} ${p.nom}',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (p.estVerifie)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: MiwodoSvgIcon('assets/icons/ic_verified.svg', size: 14, color: Colors.white),
                              ),
                            Text(
                              p.metier ?? p.categorie,
                              style: GoogleFonts.inter(fontSize: 12, color: Colors.white.withAlpha(220)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      'Revenus',
                      '${p.gainsParrainage.toStringAsFixed(0)} $symbole',
                      'assets/icons/ic_money.svg',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Commandes',
                      '0',
                      'assets/icons/ic_orders.svg',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetricCard(
                      'Note',
                      p.noteMoyenne > 0 ? p.noteMoyenne.toStringAsFixed(1) : 'N/A',
                      'assets/icons/ic_star.svg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildHeaderButton(
                      'Mes services',
                      'assets/icons/ic_briefcase.svg',
                      () => context.push('/mes-services/${p.id}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHeaderButton(
                      'Mon profil',
                      'assets/icons/ic_user.svg',
                      () => context.push('/profil/${p.id}'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String iconPath) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          MiwodoSvgIcon(iconPath, size: 18, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white.withAlpha(200)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(String label, String iconPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MiwodoSvgIcon(iconPath, size: 16, color: AppColors.primaryOrange),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 1: VUE D'ENSEMBLE ──────────────────────────────────────────────
  Widget _buildOverviewTab(Prestataire p, String symbole) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard('Informations', [
          _buildInfoRow('Catégorie', p.categorie),
          _buildInfoRow('Métier', p.metier ?? 'Non précisé'),
          _buildInfoRow('Ville', p.ville),
          _buildInfoRow('Zone', p.zone),
          _buildInfoRow('Téléphone', p.telephone),
          _buildInfoRow('Email', p.email ?? 'Non renseigné'),
          _buildInfoRow('Disponible', p.estDisponible ? 'Oui' : 'Non'),
          _buildInfoRow('Vérifié', p.estVerifie ? 'Oui' : 'En attente'),
        ]),
        const SizedBox(height: 12),
        if (p.description != null && p.description!.isNotEmpty) ...[
          _buildInfoCard('Description', [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                p.description!,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            if (p.isVendeur) ...[
              Expanded(
                child: _buildActionCard(
                  'Mes produits',
                  'assets/icons/ic_cart.svg',
                  () => context.push('/mes-produits/${p.id}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionCard(
                  'Mes commandes',
                  'assets/icons/ic_orders.svg',
                  () => _tabController?.animateTo(2),
                ),
              ),
            ] else if (p.isLivreur) ...[
              Expanded(
                child: _buildActionCard(
                  'Mes courses',
                  'assets/icons/ic_livreur.svg',
                  () => _tabController?.animateTo(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionCard(
                  'Messages clients',
                  'assets/icons/ic_chat.svg',
                  () => _tabController?.animateTo(3),
                ),
              ),
            ] else ...[
              Expanded(
                child: _buildActionCard(
                  'Mes services',
                  'assets/icons/ic_briefcase.svg',
                  () => context.push('/mes-services/${p.id}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionCard(
                  'Mes messages',
                  'assets/icons/ic_chat.svg',
                  () => _tabController?.animateTo(3),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                'Mon profil public',
                'assets/icons/ic_user.svg',
                () => context.push('/profil/${p.id}'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildActionCard(
                'Modifier le profil',
                'assets/icons/ic_edit.svg',
                () => context.push('/prestataire/${p.id}'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Section Paramètres & Suppression de compte (Google Play Compliance)
        _buildInfoCard('Sécurité & Compte', [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout, size: 20, color: AppColors.textSecondary),
            title: Text('Se déconnecter', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: _logout,
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_forever_outlined, size: 20, color: AppColors.errorRed),
            title: Text(
              'Supprimer définitivement mon compte',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.errorRed),
            ),
            subtitle: Text(
              'Supprime votre profil, vos services/produits et vos données personnelles',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.errorRed),
            onTap: _confirmDeleteAccount,
          ),
        ]),
      ],
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String label, String iconPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderGray),
        ),
        child: Column(
          children: [
            MiwodoSvgIcon(iconPath, size: 24, color: AppColors.primaryOrange),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 2: SERVICES / PRODUITS / ENGIN ────────────────────────────────
  Widget _buildServicesTab(Prestataire p) {
    if (p.isVendeur) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const MiwodoSvgIcon('assets/icons/ic_cart.svg', size: 48, color: AppColors.primaryOrange),
              const SizedBox(height: 16),
              Text(
                'Catalogue de votre boutique',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Ajoutez vos articles avec photos, prix et stock pour permettre aux clients d\'acheter en ligne.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              MiwodoButton(
                label: 'Gérer mes produits',
                onPressed: () => context.push('/mes-produits/${p.id}'),
              ),
            ],
          ),
        ),
      );
    } else if (p.isLivreur) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard('Profil & Équipement Livreur', [
            _buildInfoRow('Engin de livraison', p.typeEngin ?? 'Moto standard'),
            _buildInfoRow('Capacité de charge', p.capaciteCharge ?? 'Colis standards'),
            _buildInfoRow('Livraison Express', p.livraisonExpress ? 'Oui' : 'Non'),
            _buildInfoRow('Disponible le week-end', p.disponibleWeekend ? 'Oui' : 'Non'),
            _buildInfoRow('Disponible la nuit', p.disponibleNuit ? 'Oui' : 'Non'),
          ]),
          const SizedBox(height: 16),
          MiwodoButton(
            label: 'Mettre à jour mes informations livreur',
            variant: MiwodoButtonVariant.secondary,
            onPressed: () => context.push('/prestataire/${p.id}'),
          ),
        ],
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MiwodoSvgIcon('assets/icons/ic_briefcase.svg', size: 48, color: AppColors.primaryOrange),
            const SizedBox(height: 16),
            Text(
              'Gérez vos prestations de services',
              style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez et détaillez vos compétences, prestations et tarifs pour les clients.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            MiwodoButton(
              label: 'Gérer mes prestations',
              onPressed: () => context.push('/mes-services/${p.id}'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 3: COMMANDES / COURSES ─────────────────────────────────────────
  Widget _buildCommandesTab(Prestataire p) {
    if (p.isLivreur) {
      return LivreurCoursesWidget(prestataire: p);
    }

    return StreamBuilder(
      stream: FirestoreService.instance.getCommandes(p.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
        }
        final commandes = snapshot.data ?? [];
        if (commandes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MiwodoSvgIcon('assets/icons/ic_orders.svg', size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text('Aucune commande', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Vos commandes de produits apparaîtront ici.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: commandes.length,
          itemBuilder: (context, index) {
            final cmd = commandes[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _statutColor(cmd.statut).withAlpha(20),
                  child: Text(
                    '${commandes.length - index}',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: _statutColor(cmd.statut)),
                  ),
                ),
                title: Text(
                  'Commande #${cmd.id.substring(0, 8)}',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  cmd.statut.label,
                  style: GoogleFonts.inter(fontSize: 12, color: _statutColor(cmd.statut)),
                ),
                trailing: Text(
                  '${cmd.totalClient} F',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryOrange),
                ),
                onTap: () => context.push('/suivi-commande/${cmd.id}'),
              ),
            );
          },
        );
      },
    );
  }

  Color _statutColor(dynamic statut) {
    final name = statut.toString().split('.').last;
    switch (name) {
      case 'paye':
        return AppColors.infoBlue;
      case 'livre':
      case 'confirme':
      case 'forceConfirme':
        return AppColors.successGreen;
      case 'litige':
        return AppColors.errorRed;
      default:
        return AppColors.warningYellow;
    }
  }

  // ─── ONGLET 4: MESSAGES ────────────────────────────────────────────────────
  Widget _buildMessagesTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MiwodoSvgIcon('assets/icons/ic_chat.svg', size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Messages', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Vos conversations avec les clients.',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            MiwodoButton(
              label: 'Voir mes messages',
              onPressed: () => context.go('/messages'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 5: PARRAINAGE ──────────────────────────────────────────────────
  Widget _buildParrainageTab(Prestataire p, String symbole) {
    final gainParrainage = ref.watch(gainParrainageProvider);
    final gainsDisponibles = p.gainsParrainage.toInt();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── BANNIÈRE EN-TÊTE AUX COULEURS OFFICIELLES ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.brandMagenta.withAlpha(50),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard, size: 28, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                'Gagnez +${gainParrainage > 0 ? gainParrainage.toInt() : 100} $symbole',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'automatiquement à chaque filleul inscrit avec votre code',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withAlpha(220)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── STATISTIQUES & SOLDE RETIRABLE ──
        _buildInfoCard('Mes statistiques de parrainage', [
          _buildInfoRow('Filleuls inscrits', '${p.filleuls}'),
          _buildInfoRow('Total des gains', '${p.gainsParrainage.toStringAsFixed(0)} $symbole'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Solde retirable', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '$gainsDisponibles $symbole',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: gainsDisponibles >= 1000
                    ? () => _showRetraitParrainageDialog(context, p, symbole)
                    : null,
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                label: Text(
                  gainsDisponibles >= 1000 ? 'Retirer mes gains' : 'Min. 1000 $symbole',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  disabledForegroundColor: Colors.grey.shade500,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ]),
        const SizedBox(height: 16),

        // ── CODE DE PARRAINAGE ET PARTAGE ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mon code de parrainage unique',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'Partagez ce code à vos confrères ou relations pour qu\'ils le renseignent lors de leur inscription.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              if (p.codeParrain != null && p.codeParrain!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primaryOrange.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.codeParrain!,
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: AppColors.primaryOrangeDark,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: p.codeParrain!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Code de parrainage copié !'),
                              backgroundColor: AppColors.infoBlue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 20, color: AppColors.primaryOrange),
                        tooltip: 'Copier le code',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                        'Rejoins Miwodo ! Utilise mon code de parrainage ${p.codeParrain} lors de ton inscription pour développer tes activités : https://miwodo.app/parrainage/${p.codeParrain}',
                        subject: 'Invitation Miwodo',
                      );
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(
                      'Partager mon lien de parrainage',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandDarkNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ] else ...[
                MiwodoButton(
                  label: 'Générer mon code de parrainage',
                  onPressed: () => _genererCodeParrain(p),
                  fullWidth: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── HISTORIQUE DES FILLEULS ──
        _buildHistoriqueFilleuls(p.id, symbole),
      ],
    );
  }

  Future<void> _genererCodeParrain(Prestataire p) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final newCode = 'MW${timestamp.substring(timestamp.length - 6).toUpperCase()}';
    try {
      await FirestoreService.instance.updatePrestataire(p.id, {'codeParrain': newCode});
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code de parrainage activé avec succès !'), backgroundColor: AppColors.successGreen),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
      }
    }
  }

  Widget _buildHistoriqueFilleuls(String prestataireId, String symbole) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people_outline, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(
                'Historique des filleuls',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseService.instance.firestore
                .collection('parrainages')
                .where('parrainId', isEqualTo: prestataireId)
                .orderBy('created_at', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 2)));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Aucun filleul inscrit pour le moment.\nPartagez votre code pour commencer à gagner !',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 16),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final nom = data['filleulNom'] as String? ?? 'Filleul';
                  final metier = data['filleulMetier'] as String? ?? data['filleulCategorie'] as String? ?? '';
                  final gain = (data['montantGain'] as num?)?.toInt() ?? 100;

                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, size: 14, color: AppColors.successGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nom, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                            if (metier.isNotEmpty)
                              Text(metier, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '+$gain $symbole',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.successGreen),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _showRetraitParrainageDialog(BuildContext context, Prestataire p, String symbole) {
    final montantController = TextEditingController();
    final numeroController = TextEditingController();
    final nomController = TextEditingController();
    MethodePaiement methode = MethodePaiement.mobileMoney;
    bool isSubmitting = false;
    const retraitMinimum = 1000;
    final soldeDisponible = p.gainsParrainage.toInt();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Retrait des gains de parrainage', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryOrangeLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gains disponibles:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                      Text('$soldeDisponible $symbole', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryOrange)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: montantController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Montant à retirer ($symbole)',
                    hintText: 'Minimum $retraitMinimum $symbole',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Mode de réception', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...MethodePaiement.values.map((m) => RadioListTile<MethodePaiement>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: m,
                      groupValue: methode,
                      title: Text(m.label, style: GoogleFonts.inter(fontSize: 13)),
                      onChanged: (v) => setDialogState(() => methode = v!),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: numeroController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: methode == MethodePaiement.virementBancaire
                        ? 'Numéro de compte (RIB)'
                        : 'Numéro Mobile Money (T-Money / Moov / Wave)',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du titulaire (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: GoogleFonts.inter(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final montant = int.tryParse(montantController.text.trim());
                      if (montant == null || montant <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Montant invalide'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (montant < retraitMinimum) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Minimum: $retraitMinimum $symbole'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (montant > soldeDisponible) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Montant supérieur aux gains disponibles'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }
                      if (numeroController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Numéro de paiement requis'), backgroundColor: AppColors.errorRed),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);
                      try {
                        await RetraitService.instance.creerDemandeRetrait(
                          prestataireId: p.id,
                          prestataireNom: '${p.prenom} ${p.nom}',
                          source: RetraitSource.parrainage,
                          montant: montant,
                          devise: p.devise,
                          methodePaiement: methode,
                          numeroDestinataire: numeroController.text.trim(),
                          nomDestinataire: nomController.text.trim().isEmpty ? null : nomController.text.trim(),
                          retraitMinimum: retraitMinimum,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demande de retrait envoyée !'),
                              backgroundColor: AppColors.successGreen,
                            ),
                          );
                          await _loadProfile();
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => isSubmitting = false);
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Confirmer le retrait'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 6: PUBLICITÉ ────────────────────────────────────────────────────
  Widget _buildPubliciteTab(Prestataire p) {
    final pubStandardMontant = ref.watch(pubStandardMontantProvider);
    final pubPremiumMontant = ref.watch(pubPremiumMontantProvider);
    final symbole = ref.watch(symboleProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (p.sponsorise && p.planPub != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryOrangeLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryOrange.withAlpha(50)),
            ),
            child: Column(
              children: [
                const MiwodoSvgIcon('assets/icons/ic_star.svg', size: 28, color: AppColors.primaryOrange),
                const SizedBox(height: 8),
                Text(
                  'Plan ${p.planPub} actif',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
                ),
                if (p.pubExpireLe != null)
                  Text(
                    'Expire le ${p.pubExpireLe!.day}/${p.pubExpireLe!.month}/${p.pubExpireLe!.year}',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildPubCard(
          'Standard',
          '${pubStandardMontant.toInt()} $symbole',
          'Votre service apparaît dans la section "Services sponsorisés" de l\'accueil.',
          p.planPub == 'standard',
        ),
        const SizedBox(height: 12),
        _buildPubCard(
          'Premium',
          '${pubPremiumMontant.toInt()} $symbole',
          'Affichage prioritaire en tête des résultats + badge "Sponsorisé" + mise en avant.',
          p.planPub == 'premium',
        ),
      ],
    );
  }

  Widget _buildPubCard(String plan, String prix, String description, bool isActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? AppColors.primaryOrange : AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                plan,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              Text(
                prix,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.primaryOrange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          MiwodoButton(
            label: isActive ? 'Plan actif' : 'Souscrire',
            onPressed: isActive ? null : () {
              // TODO: Initier paiement publicité
            },
            fullWidth: true,
            variant: isActive ? MiwodoButtonVariant.primary : MiwodoButtonVariant.secondary,
          ),
        ],
      ),
    );
  }
}
