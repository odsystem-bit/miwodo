// screens/dashboard/dashboard_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/prestataire.dart';
import '../../providers/pays_provider.dart';
import '../../services/auth_service.dart';
import '../../services/firebase_service.dart';
import '../../services/firestore_service.dart';
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
                onPressed: () => context.go('/login'),
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
            ],
          ),
        ),
      ),
    );
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
                tabs: const [
                  Tab(text: 'Vue d\'ensemble'),
                  Tab(text: 'Services'),
                  Tab(text: 'Commandes'),
                  Tab(text: 'Messages'),
                  Tab(text: 'Parrainage'),
                  Tab(text: 'Publicité'),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryOrange, AppColors.primaryOrangeDark],
        ),
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
                'Mes produits',
                'assets/icons/ic_cart.svg',
                () => context.push('/mes-produits/${p.id}'),
              ),
            ),
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

  // ─── ONGLET 2: SERVICES ────────────────────────────────────────────────────
  Widget _buildServicesTab(Prestataire p) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MiwodoSvgIcon('assets/icons/ic_briefcase.svg', size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              'Gérez vos services',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajoutez, modifiez ou supprimez vos services proposés.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            MiwodoButton(
              label: 'Gérer mes services',
              onPressed: () => context.push('/mes-services/${p.id}'),
            ),
            const SizedBox(height: 12),
            MiwodoButton(
              label: 'Gérer mes produits',
              onPressed: () => context.push('/mes-produits/${p.id}'),
              variant: MiwodoButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  // ─── ONGLET 3: COMMANDES ──────────────────────────────────────────────────
  Widget _buildCommandesTab(Prestataire p) {
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
                    'Vos commandes apparaîtront ici.',
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryOrange, AppColors.primaryOrangeDark],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const MiwodoSvgIcon('assets/icons/ic_gift.svg', size: 32, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                'Gagnez ${gainParrainage.toInt()} $symbole',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'par filleul inscrit',
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withAlpha(220)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInfoCard('Mes statistiques', [
          _buildInfoRow('Filleuls', '${p.filleuls}'),
          _buildInfoRow('Gains parrainage', '${p.gainsParrainage.toStringAsFixed(0)} $symbole'),
          _buildInfoRow('Code de parrainage', p.codeParrain ?? 'Non généré'),
        ]),
        const SizedBox(height: 16),
        if (p.codeParrain != null)
          MiwodoButton(
            label: 'Partager mon code',
            onPressed: () {
              // TODO: Share functionality
            },
            fullWidth: true,
          ),
      ],
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
