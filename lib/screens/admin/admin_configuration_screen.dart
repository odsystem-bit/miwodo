// screens/admin/admin_configuration_screen.dart
// Écran de configuration admin avec 6 onglets

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/config_models.dart';
import '../../models/pays.dart';
import '../../providers/config_provider.dart';
import '../../providers/pays_provider.dart';
import '../../core/utils/formatters.dart';
import '../../services/config_service.dart';
import '../../widgets/miwodo_button.dart';
import '../../widgets/miwodo_svg_icon.dart';
import 'admin_shell.dart';

class AdminConfigurationScreen extends ConsumerStatefulWidget {
  const AdminConfigurationScreen({super.key});

  @override
  ConsumerState<AdminConfigurationScreen> createState() => _AdminConfigurationScreenState();
}

class _AdminConfigurationScreenState extends ConsumerState<AdminConfigurationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Configuration',
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primaryOrange,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryOrange,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Pays'),
                Tab(text: 'Villes'),
                Tab(text: 'Zones'),
                Tab(text: 'Catégories'),
                Tab(text: 'Tarifs'),
                Tab(text: 'App'),
                Tab(text: 'Notifs'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _PaysTab(),
                _VillesTab(),
                _ZonesTab(),
                _CategoriesTab(),
                _TarifsTab(),
                _AppTab(),
                _NotificationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 1 : PAYS
// ═══════════════════════════════════════════════════════════════════════════

class _PaysTab extends ConsumerWidget {
  const _PaysTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paysAsync = ref.watch(tousLesPaysProvider);

    return paysAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (tousPays) => Stack(
        children: [
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: tousPays.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final pays = tousPays[index];
              return _PaysCard(
                pays: pays,
                onToggle: (val) => _togglePays(context, pays, val),
                onEdit: () => _showPaysDialog(context, ref, pays: pays),
              );
            },
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () => _showPaysDialog(context, ref),
              backgroundColor: AppColors.primaryOrange,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text('Ajouter un pays', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePays(BuildContext context, Pays pays, bool val) async {
    // Vérifier si désactivation possible
    if (!val) {
      // TODO: compter les prestataires actifs dans ce pays
      // Pour l'instant, simplement mettre à jour
    }
    try {
      await ConfigService.instance.updatePays(pays.copyWith(actif: val));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _showPaysDialog(BuildContext context, WidgetRef ref, {Pays? pays}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _PaysDialog(pays: pays),
    );
  }
}

// ─── Card pays ───────────────────────────────────────────────────────────

class _PaysCard extends StatelessWidget {
  final Pays pays;
  final void Function(bool) onToggle;
  final VoidCallback onEdit;

  const _PaysCard({required this.pays, required this.onToggle, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: ExpansionTile(
        leading: Text(pays.drapeauEmoji, style: const TextStyle(fontSize: 24)),
        title: Row(
          children: [
            Text(pays.nom, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: pays.actif ? Colors.green.shade50 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                pays.actif ? 'Actif' : 'Inactif',
                style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: pays.actif ? Colors.green.shade700 : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text('${pays.devise} · ${pays.symbole} · ${pays.regionLabel}',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _infoRow('Inscription', formatPrix(pays.inscriptionMontant, pays.symbole)),
                _infoRow('Pub standard', formatPrix(pays.pubStandardMontant, pays.symbole)),
                _infoRow('Pub premium', formatPrix(pays.pubPremiumMontant, pays.symbole)),
                _infoRow('Gain parrainage', formatPrix(pays.gainParrainage, pays.symbole)),
                _infoRow('Retrait min.', formatPrix(pays.retraitMinimum, pays.symbole)),
                _infoRow('Méthodes', pays.monerooMethods.map((m) => monerooMethodLabels[m] ?? m).join(', ')),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text('Actif', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        Switch(
                          value: pays.actif,
                          onChanged: onToggle,
                          activeThumbColor: AppColors.primaryOrange,
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Modifier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ─── Dialog ajout/modification pays ──────────────────────────────────────

class _PaysDialog extends ConsumerStatefulWidget {
  final Pays? pays;
  const _PaysDialog({this.pays});

  @override
  ConsumerState<_PaysDialog> createState() => _PaysDialogState();
}

class _PaysDialogState extends ConsumerState<_PaysDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _idCtrl, _nomCtrl, _drapeauCtrl, _symboleCtrl;
  late TextEditingController _inscriptionCtrl, _gainCtrl, _pubStdCtrl, _pubPremCtrl, _retraitCtrl, _methodesCtrl;
  String _region = 'afrique_ouest';
  String _devise = 'XOF';
  bool _actif = true;
  bool _loading = false;

  static const _devises = ['XOF', 'XAF', 'EUR', 'USD', 'CAD', 'GBP', 'GHS', 'NGN'];
  static const _regions = ['afrique_ouest', 'afrique_centrale', 'afrique_est', 'europe', 'amerique'];

  @override
  void initState() {
    super.initState();
    final p = widget.pays;
    _idCtrl = TextEditingController(text: p?.id ?? '');
    _nomCtrl = TextEditingController(text: p?.nom ?? '');
    _drapeauCtrl = TextEditingController(text: p?.drapeauEmoji ?? '');
    _symboleCtrl = TextEditingController(text: p?.symbole ?? 'F CFA');
    _inscriptionCtrl = TextEditingController(text: p?.inscriptionMontant.toString() ?? '500');
    _gainCtrl = TextEditingController(text: p?.gainParrainage.toString() ?? '100');
    _pubStdCtrl = TextEditingController(text: p?.pubStandardMontant.toString() ?? '2000');
    _pubPremCtrl = TextEditingController(text: p?.pubPremiumMontant.toString() ?? '5000');
    _retraitCtrl = TextEditingController(text: p?.retraitMinimum.toString() ?? '500');
    _methodesCtrl = TextEditingController(text: p?.monerooMethods.join(', ') ?? '');
    _region = p?.region ?? 'afrique_ouest';
    _devise = p?.devise ?? 'XOF';
    _actif = p?.actif ?? true;
  }

  @override
  void dispose() {
    for (final c in [_idCtrl, _nomCtrl, _drapeauCtrl, _symboleCtrl,
        _inscriptionCtrl, _gainCtrl, _pubStdCtrl, _pubPremCtrl, _retraitCtrl, _methodesCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.pays != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(isEdit ? 'Modifier ${widget.pays!.nom}' : 'Ajouter un pays',
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _field('Code ISO', _idCtrl, enabled: !isEdit, hint: 'ex: GH')),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Emoji drapeau', _drapeauCtrl, hint: '🇬🇭')),
                ]),
                const SizedBox(height: 12),
                _field('Nom du pays', _nomCtrl, hint: 'ex: Ghana'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _dropdown('Région', _regions, _region,
                      (v) => setState(() => _region = v!),
                      labelOf: (r) => Pays(id:'',nom:'',drapeauEmoji:'',region:r,actif:true,devise:'',symbole:'',inscriptionMontant:0,gainParrainage:0,commissionFixeCommande:0,pubStandardMontant:0,pubPremiumMontant:0,retraitMinimum:0,monerooMethods:const[],villesActives:const[],ordre:0).regionLabel)),
                  const SizedBox(width: 12),
                  Expanded(child: _dropdown('Devise', _devises, _devise, (v) => setState(() => _devise = v!))),
                ]),
                const SizedBox(height: 12),
                _field('Symbole affiché', _symboleCtrl, hint: 'F CFA / € / CA\$'),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Inscription', _inscriptionCtrl, isNum: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Gain parrainage', _gainCtrl, isNum: true)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _field('Pub Standard', _pubStdCtrl, isNum: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field('Pub Premium', _pubPremCtrl, isNum: true)),
                ]),
                const SizedBox(height: 12),
                _field('Retrait minimum', _retraitCtrl, isNum: true),
                const SizedBox(height: 12),
                _field('Méthodes Moneroo', _methodesCtrl, hint: 'moov_tg, togocel'),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Activer immédiatement'),
                  const Spacer(),
                  Switch(value: _actif, onChanged: (v) => setState(() => _actif = v), activeThumbColor: AppColors.primaryOrange),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
                  const SizedBox(width: 12),
                  Expanded(child: MiwodoButton(
                    label: isEdit ? 'Enregistrer' : 'Ajouter',
                    isLoading: _loading,
                    onPressed: _submit,
                  )),
                ]),
              ],
            ),
          ),
        ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool isNum = false, String? hint, bool enabled = true}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: isNum ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
    );
  }

  Widget _dropdown(String label, List<String> items, String value, void Function(String?) onChanged, {String Function(String)? labelOf}) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surfaceGray,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((v) => DropdownMenuItem(value: v, child: Text(labelOf != null ? labelOf(v) : v, style: GoogleFonts.inter(fontSize: 13)))).toList(),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final methodes = _methodesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final nouveau = Pays(
        id: _idCtrl.text.toUpperCase().trim(),
        nom: _nomCtrl.text.trim(),
        drapeauEmoji: _drapeauCtrl.text.trim(),
        region: _region,
        actif: _actif,
        devise: _devise,
        symbole: _symboleCtrl.text.trim(),
        inscriptionMontant: num.tryParse(_inscriptionCtrl.text) ?? 500,
        gainParrainage: num.tryParse(_gainCtrl.text) ?? 100,
        commissionFixeCommande: 0,
        pubStandardMontant: num.tryParse(_pubStdCtrl.text) ?? 2000,
        pubPremiumMontant: num.tryParse(_pubPremCtrl.text) ?? 5000,
        retraitMinimum: num.tryParse(_retraitCtrl.text) ?? 500,
        monerooMethods: methodes,
        villesActives: widget.pays?.villesActives ?? [],
        ordre: widget.pays?.ordre ?? 99,
      );
      await ConfigService.instance.updatePays(nouveau);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 2 : VILLES
// ═══════════════════════════════════════════════════════════════════════════

class _VillesTab extends ConsumerStatefulWidget {
  const _VillesTab();

  @override
  ConsumerState<_VillesTab> createState() => _VillesTabState();
}

class _VillesTabState extends ConsumerState<_VillesTab> {
  String? _selectedPaysId;

  @override
  Widget build(BuildContext context) {
    final villesAsync = ref.watch(configVillesProvider);
    final paysAsync = ref.watch(tousLesPaysProvider);
    final paysList = paysAsync.valueOrNull ?? [];

    return villesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erreur: $e')),
      data: (villes) {
        final filteredVilles = _selectedPaysId != null
            ? villes.where((v) => v.pays == (paysList.firstWhere((p) => p.id == _selectedPaysId).nom)).toList()
            : villes;
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Gestion des villes', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _buildInfoCard('Activer une ville la rend disponible dans les formulaires d\'inscription. Les prestataires pourront s\'inscrire dans cette ville dès l\'activation.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: _selectedPaysId,
                  decoration: InputDecoration(
                    labelText: 'Filtrer par pays',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tous les pays')),
                    ...paysList.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text('${p.nom} ${p.drapeauEmoji}'))),
                  ],
                  onChanged: (v) => setState(() => _selectedPaysId = v),
                ),
                const SizedBox(height: 16),
                ...filteredVilles.map((v) => _VilleCard(ville: v)),
                if (filteredVilles.isEmpty)
                  Center(child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Aucune ville pour ce filtre', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                  )),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: AppColors.primaryOrange,
                onPressed: () => _showAddVilleDialog(context, paysList),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAddVilleDialog(BuildContext context, List<Pays> paysList) {
    final nomController = TextEditingController();
    String? selectedPaysNom;
    final ordreController = TextEditingController(text: '10');
    bool actif = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Ajouter une ville', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(labelText: 'Nom de la ville *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedPaysNom,
                decoration: InputDecoration(labelText: 'Pays *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                items: paysList.map((p) => DropdownMenuItem(value: p.nom, child: Text('${p.nom} ${p.drapeauEmoji}'))).toList(),
                onChanged: (v) => setDialogState(() => selectedPaysNom = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ordreController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Ordre d\'affichage', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: actif,
                    onChanged: (v) => setDialogState(() => actif = v),
                    activeTrackColor: AppColors.primaryOrange,
                  ),
                  Text('Active immédiatement', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () async {
                if (nomController.text.isEmpty) return;
                if (selectedPaysNom == null) return;
                final ville = ConfigVille(
                  id: nomController.text.toLowerCase().replaceAll(' ', '_'),
                  nom: nomController.text,
                  pays: selectedPaysNom!,
                  actif: actif,
                  ordre: int.tryParse(ordreController.text) ?? 10,
                );
                try {
                  await ConfigService.instance.addVille(ville);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ville ajoutée ✓'), backgroundColor: AppColors.successGreen));
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
                  }
                }
              },
              child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _VilleCard extends ConsumerWidget {
  final ConfigVille ville;
  const _VilleCard({required this.ville});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ville.actif ? AppColors.successGreen.withAlpha(30) : AppColors.borderGray,
          child: Text(ville.nom[0], style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: ville.actif ? AppColors.successGreen : AppColors.textSecondary)),
        ),
        title: Text(ville.nom, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        subtitle: Text('${ville.pays} • Ordre: ${ville.ordre}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: ville.actif,
              onChanged: (v) async {
                await ConfigService.instance.updateVille(ville.id, {'actif': v});
              },
              activeTrackColor: AppColors.primaryOrange,
            ),
            PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'delete') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Supprimer cette ville ?'),
                      content: Text('La ville "${ville.nom}" sera supprimée.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ConfigService.instance.deleteVille(ville.id);
                  }
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 2 : ZONES
// ═══════════════════════════════════════════════════════════════════════════

class _ZonesTab extends ConsumerStatefulWidget {
  const _ZonesTab();

  @override
  ConsumerState<_ZonesTab> createState() => _ZonesTabState();
}

class _ZonesTabState extends ConsumerState<_ZonesTab> {
  String? _selectedVilleId;

  @override
  Widget build(BuildContext context) {
    final villesAsync = ref.watch(configVillesProvider);
    final zonesAsync = ref.watch(configZonesProvider);

    return villesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erreur: $e')),
      data: (villes) => zonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
        data: (allZones) {
          // Auto-select first ville if none selected
          if (_selectedVilleId == null && villes.isNotEmpty) {
            _selectedVilleId = villes.first.id;
          }
          final zones = _selectedVilleId != null
              ? allZones.where((z) => z.villeId == _selectedVilleId).toList()
              : <ConfigZone>[];
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Gestion des zones', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedVilleId,
                    decoration: InputDecoration(
                      labelText: 'Sélectionner une ville',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: villes.map((v) => DropdownMenuItem(value: v.id, child: Text(v.nom))).toList(),
                    onChanged: (v) => setState(() => _selectedVilleId = v),
                  ),
                  const SizedBox(height: 16),
                  ...zones.map((z) => _ZoneCard(zone: z)),
                  if (zones.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('Aucune zone pour cette ville', style: GoogleFonts.inter(color: AppColors.textSecondary)),
                    )),
                ],
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: AppColors.primaryOrange,
                  onPressed: () => _showAddZoneDialog(context, villes),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddZoneDialog(BuildContext context, List<ConfigVille> villes) {
    final nomController = TextEditingController();
    final ordreController = TextEditingController(text: '10');
    String? villeId = _selectedVilleId;
    bool actif = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Ajouter une zone', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomController,
                decoration: InputDecoration(labelText: 'Nom du quartier *', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: villeId,
                decoration: InputDecoration(labelText: 'Ville de rattachement', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                items: villes.map((v) => DropdownMenuItem(value: v.id, child: Text(v.nom))).toList(),
                onChanged: (v) => setDialogState(() => villeId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ordreController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Ordre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: actif,
                    onChanged: (v) => setDialogState(() => actif = v),
                    activeTrackColor: AppColors.primaryOrange,
                  ),
                  Text('Active immédiatement', style: GoogleFonts.inter(fontSize: 14)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
              onPressed: () async {
                if (nomController.text.isEmpty) return;
                if (villeId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sélectionnez une ville'), backgroundColor: AppColors.errorRed),
                  );
                  return;
                }
                final zone = ConfigZone(
                  id: nomController.text.toLowerCase().replaceAll(' ', '_').replaceAll('é', 'e').replaceAll('è', 'e'),
                  nom: nomController.text,
                  villeId: villeId!,
                  actif: actif,
                  ordre: int.tryParse(ordreController.text) ?? 10,
                );
                try {
                  await ConfigService.instance.addZone(zone);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zone ajoutée ✓'), backgroundColor: AppColors.successGreen));
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed));
                  }
                }
              },
              child: const Text('Ajouter', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoneCard extends ConsumerWidget {
  final ConfigZone zone;
  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: zone.actif ? AppColors.primaryOrangeLight : AppColors.borderGray,
          child: Text('${zone.ordre}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: zone.actif ? AppColors.primaryOrange : AppColors.textSecondary)),
        ),
        title: Text(zone.nom, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: zone.actif,
              onChanged: (v) async {
                await ConfigService.instance.updateZone(zone.id, {'actif': v});
              },
              activeTrackColor: AppColors.primaryOrange,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.errorRed),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer cette zone ?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ConfigService.instance.deleteZone(zone.id);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 3 : CATÉGORIES
// ═══════════════════════════════════════════════════════════════════════════

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(configCategoriesProvider);

    return catsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erreur: $e')),
      data: (categories) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Gestion des catégories', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _buildInfoCard('Les sous-catégories apparaissent dans le champ "Métier/Activité" lors de l\'inscription des prestataires.'),
          const SizedBox(height: 16),
          ...categories.map((c) => _CategorieCard(categorie: c)),
        ],
      ),
    );
  }
}

class _CategorieCard extends ConsumerStatefulWidget {
  final ConfigCategorie categorie;
  const _CategorieCard({required this.categorie});

  @override
  ConsumerState<_CategorieCard> createState() => _CategorieCardState();
}

class _CategorieCardState extends ConsumerState<_CategorieCard> {
  final _newSousCatController = TextEditingController();

  @override
  void dispose() {
    _newSousCatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cat = widget.categorie;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: MiwodoSvgIcon('assets/icons/${cat.iconeSvg}', size: 24, color: AppColors.primaryOrange),
        title: Text(cat.label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        subtitle: Text('${cat.sousCategories.length} sous-catégories', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        trailing: Switch(
          value: cat.actif,
          onChanged: (v) async {
            await ConfigService.instance.updateCategorie(cat.id, {'actif': v});
          },
          activeTrackColor: AppColors.primaryOrange,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cat.sousCategories.map((sc) => Chip(
                    label: Text(sc, style: GoogleFonts.inter(fontSize: 12)),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () async {
                      await ConfigService.instance.removeSousCategorie(cat.id, sc);
                    },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newSousCatController,
                        decoration: InputDecoration(
                          hintText: 'Nouvelle sous-catégorie',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: AppColors.primaryOrange),
                      onPressed: () async {
                        if (_newSousCatController.text.isEmpty) return;
                        await ConfigService.instance.addSousCategorie(cat.id, _newSousCatController.text);
                        _newSousCatController.clear();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 4 : TARIFS
// ═══════════════════════════════════════════════════════════════════════════

class _TarifsTab extends ConsumerStatefulWidget {
  const _TarifsTab();

  @override
  ConsumerState<_TarifsTab> createState() => _TarifsTabState();
}

class _TarifsTabState extends ConsumerState<_TarifsTab> {
  final _inscriptionController = TextEditingController();
  final _pubStandardController = TextEditingController();
  final _pubPremiumController = TextEditingController();
  final _parrainageController = TextEditingController();
  final _commissionController = TextEditingController();

  bool _initialized = false;

  void _initControllers(ConfigTarifs tarifs) {
    if (_initialized) return;
    _inscriptionController.text = tarifs.inscriptionPrestataire.toString();
    _pubStandardController.text = tarifs.pubStandardMensuel.toString();
    _pubPremiumController.text = tarifs.pubPremiumMensuel.toString();
    _parrainageController.text = tarifs.gainParrainage.toString();
    _commissionController.text = tarifs.commissionCommandePct.toString();
    _initialized = true;
  }

  @override
  void dispose() {
    _inscriptionController.dispose();
    _pubStandardController.dispose();
    _pubPremiumController.dispose();
    _parrainageController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tarifsAsync = ref.watch(configTarifsProvider);

    return tarifsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erreur: $e')),
      data: (tarifs) {
        _initControllers(tarifs);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Tarifs & Revenus', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildTarifCard(
              title: 'Inscription prestataire',
              controller: _inscriptionController,
              currentValue: tarifs.inscriptionPrestataire,
              fieldKey: 'inscription_prestataire',
              isHighlighted: true,
            ),
            _buildTarifCard(
              title: 'Publicité Standard / mois',
              controller: _pubStandardController,
              currentValue: tarifs.pubStandardMensuel,
              fieldKey: 'pub_standard_mensuel',
            ),
            _buildTarifCard(
              title: 'Publicité Premium / mois',
              controller: _pubPremiumController,
              currentValue: tarifs.pubPremiumMensuel,
              fieldKey: 'pub_premium_mensuel',
            ),
            _buildTarifCard(
              title: 'Gain parrainage / filleul',
              controller: _parrainageController,
              currentValue: tarifs.gainParrainage,
              fieldKey: 'gain_parrainage',
            ),
            _buildTarifCard(
              title: 'Commission commandes (%)',
              controller: _commissionController,
              currentValue: tarifs.commissionCommandePct.toInt(),
              fieldKey: 'commission_commande_pct',
              isDisabled: true,
              subtitle: 'Non activé — Modèle à venir',
            ),
          ],
        );
      },
    );
  }

  Widget _buildTarifCard({
    required String title,
    required TextEditingController controller,
    required int currentValue,
    required String fieldKey,
    bool isHighlighted = false,
    bool isDisabled = false,
    String? subtitle,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isHighlighted ? AppColors.primaryOrangeLight : (isDisabled ? Colors.grey.shade100 : Colors.white),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isDisabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      suffixText: fieldKey.contains('pct') ? '%' : 'F CFA',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDisabled ? AppColors.borderGray : AppColors.primaryOrange,
                  ),
                  onPressed: isDisabled ? null : () => _updateTarif(title, fieldKey, currentValue),
                  child: Text('Mettre à jour', style: TextStyle(color: isDisabled ? AppColors.textSecondary : Colors.white)),
                ),
              ],
            ),
            if (isHighlighted) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.primaryOrange, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Ce changement affecte toutes les nouvelles inscriptions', style: GoogleFonts.inter(fontSize: 11, color: AppColors.primaryOrange))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _updateTarif(String title, String fieldKey, int oldValue) async {
    final newValue = fieldKey.contains('pct')
        ? double.tryParse(_getControllerByKey(fieldKey).text) ?? 0.0
        : int.tryParse(_getControllerByKey(fieldKey).text) ?? 0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer le changement'),
        content: Text('Êtes-vous sûr de changer le tarif "$title" de $oldValue à $newValue ?\n\nCe changement est immédiat pour tous les nouveaux paiements.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ConfigService.instance.updateTarifs({fieldKey: newValue});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarif mis à jour ✓'), backgroundColor: AppColors.successGreen));
    }
  }

  TextEditingController _getControllerByKey(String key) {
    switch (key) {
      case 'inscription_prestataire': return _inscriptionController;
      case 'pub_standard_mensuel': return _pubStandardController;
      case 'pub_premium_mensuel': return _pubPremiumController;
      case 'gain_parrainage': return _parrainageController;
      case 'commission_commande_pct': return _commissionController;
      default: return _inscriptionController;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 5 : APP
// ═══════════════════════════════════════════════════════════════════════════

class _AppTab extends ConsumerStatefulWidget {
  const _AppTab();

  @override
  ConsumerState<_AppTab> createState() => _AppTabState();
}

class _AppTabState extends ConsumerState<_AppTab> {
  final _nomAppController = TextEditingController();
  final _sloganController = TextEditingController();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _versionController = TextEditingController();
  final _messageMaintenanceController = TextEditingController();
  final _texteBanniereController = TextEditingController();
  final _urlCguController = TextEditingController();
  final _urlConfidentialiteController = TextEditingController();

  bool _maintenanceMode = false;
  bool _banniereActive = false;
  bool _initialized = false;

  void _initControllers(ConfigApp config) {
    if (_initialized) return;
    _nomAppController.text = config.nomApp;
    _sloganController.text = config.slogan;
    _emailController.text = config.emailSupport;
    _telephoneController.text = config.telephoneSupport;
    _whatsappController.text = config.whatsappSupport;
    _versionController.text = config.versionMinimaleRequise;
    _messageMaintenanceController.text = config.messageMaintenance;
    _texteBanniereController.text = config.texteBanniere;
    _urlCguController.text = config.urlCgu;
    _urlConfidentialiteController.text = config.urlConfidentialite;
    _maintenanceMode = config.maintenanceMode;
    _banniereActive = config.banniereActive;
    _initialized = true;
  }

  @override
  void dispose() {
    _nomAppController.dispose();
    _sloganController.dispose();
    _emailController.dispose();
    _telephoneController.dispose();
    _whatsappController.dispose();
    _versionController.dispose();
    _messageMaintenanceController.dispose();
    _texteBanniereController.dispose();
    _urlCguController.dispose();
    _urlConfidentialiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appAsync = ref.watch(configAppProvider);

    return appAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erreur: $e')),
      data: (config) {
        _initControllers(config);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Paramètres de l\'application', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // Informations générales
            _buildSectionTitle('INFORMATIONS GÉNÉRALES'),
            _buildTextField('Nom de l\'app', _nomAppController),
            _buildTextField('Slogan', _sloganController),
            _buildTextField('Email support', _emailController),
            _buildTextField('Téléphone support', _telephoneController),
            _buildTextField('WhatsApp support', _whatsappController),

            const SizedBox(height: 24),

            // Mode maintenance
            _buildSectionTitle('MODE MAINTENANCE'),
            Card(
              color: _maintenanceMode ? AppColors.errorRed.withAlpha(20) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _maintenanceMode,
                          onChanged: (v) => setState(() => _maintenanceMode = v),
                          activeTrackColor: AppColors.errorRed,
                        ),
                        const SizedBox(width: 8),
                        Text('Activer le mode maintenance', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageMaintenanceController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Message de maintenance',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.warning, color: AppColors.errorRed, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: Text('ATTENTION : activer la maintenance coupe l\'accès à toute l\'application pour tous les utilisateurs sauf les admins.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.errorRed))),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mise à jour forcée
            _buildSectionTitle('MISE À JOUR FORCÉE'),
            _buildTextField('Version minimale requise', _versionController, hint: 'Ex: 1.2.0'),

            const SizedBox(height: 24),

            // Bannière accueil
            _buildSectionTitle('BANNIÈRE ACCUEIL'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Switch(
                          value: _banniereActive,
                          onChanged: (v) => setState(() => _banniereActive = v),
                          activeTrackColor: AppColors.primaryOrange,
                        ),
                        const SizedBox(width: 8),
                        Text('Activer la bannière parrainage', style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _texteBanniereController,
                      decoration: InputDecoration(
                        labelText: 'Texte de la bannière',
                        hintText: 'Ex: 🎉 Inscrivez-vous et gagnez 100 F par filleul !',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // CGU & Confidentialité
            _buildSectionTitle('CGU & CONFIDENTIALITÉ'),
            _buildTextField('URL CGU', _urlCguController),
            _buildTextField('URL Politique de confidentialité', _urlConfidentialiteController),

            const SizedBox(height: 24),

            MiwodoButton(
              label: 'Enregistrer tout',
              onPressed: _saveAll,
            ),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Future<void> _saveAll() async {
    await ConfigService.instance.updateAppConfig({
      'nom_app': _nomAppController.text,
      'slogan': _sloganController.text,
      'email_support': _emailController.text,
      'telephone_support': _telephoneController.text,
      'whatsapp_support': _whatsappController.text,
      'version_minimale_requise': _versionController.text,
      'maintenance_mode': _maintenanceMode,
      'message_maintenance': _messageMaintenanceController.text,
      'banniere_active': _banniereActive,
      'texte_banniere': _texteBanniereController.text,
      'url_cgu': _urlCguController.text,
      'url_confidentialite': _urlConfidentialiteController.text,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration enregistrée ✓'), backgroundColor: AppColors.successGreen));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ONGLET 6 : NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════════════════

class _NotificationsTab extends ConsumerStatefulWidget {
  const _NotificationsTab();

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  bool _notifCommande = true;
  bool _notifMessage = true;
  bool _notifAvis = true;
  bool _notifPubExpiree = true;
  bool _notifFilleul = true;
  final _texteInscriptionController = TextEditingController();
  final _texteCommandeController = TextEditingController();

  bool _initialized = false;

  void _initControllers(ConfigNotifications config) {
    if (_initialized) return;
    _notifCommande = config.notifNouvelleCommande;
    _notifMessage = config.notifNouveauMessage;
    _notifAvis = config.notifAvisRecu;
    _notifPubExpiree = config.notifPubExpiree;
    _notifFilleul = config.notifInscriptionFilleul;
    _texteInscriptionController.text = config.texteNotifInscription;
    _texteCommandeController.text = config.texteNotifCommande;
    _initialized = true;
  }

  @override
  void dispose() {
    _texteInscriptionController.dispose();
    _texteCommandeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(configNotificationsProvider);

    return notifsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Erreur: $e')),
      data: (config) {
        _initControllers(config);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Notifications push', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            _buildNotifSwitch('Nouvelle commande reçue', _notifCommande, (v) => setState(() => _notifCommande = v)),
            _buildNotifSwitch('Nouveau message client', _notifMessage, (v) => setState(() => _notifMessage = v)),
            _buildNotifSwitch('Avis reçu sur le profil', _notifAvis, (v) => setState(() => _notifAvis = v)),
            _buildNotifSwitch('Publicité expirée', _notifPubExpiree, (v) => setState(() => _notifPubExpiree = v)),
            _buildNotifSwitch('Filleul inscrit', _notifFilleul, (v) => setState(() => _notifFilleul = v)),

            const SizedBox(height: 24),

            Text('TEXTES DES NOTIFICATIONS', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 1)),
            const SizedBox(height: 8),
            TextField(
              controller: _texteInscriptionController,
              decoration: InputDecoration(
                labelText: 'Message notification inscription',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _texteCommandeController,
              decoration: InputDecoration(
                labelText: 'Message notification commande',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 16),
            MiwodoButton(
              label: 'Enregistrer',
              variant: MiwodoButtonVariant.secondary,
              onPressed: _saveNotifConfig,
            ),

            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  Widget _buildNotifSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: GoogleFonts.inter(fontSize: 14)),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: AppColors.primaryOrange,
        ),
      ),
    );
  }

  Future<void> _saveNotifConfig() async {
    await ConfigService.instance.updateNotificationsConfig({
      'notif_nouvelle_commande': _notifCommande,
      'notif_nouveau_message': _notifMessage,
      'notif_avis_recu': _notifAvis,
      'notif_pub_expiree': _notifPubExpiree,
      'notif_inscription_filleul': _notifFilleul,
      'texte_notif_inscription': _texteInscriptionController.text,
      'texte_notif_commande': _texteCommandeController.text,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration enregistrée ✓'), backgroundColor: AppColors.successGreen));
  }

}

// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════

Widget _buildInfoCard(String text) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.primaryOrangeLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: AppColors.primaryOrange, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryOrange))),
      ],
    ),
  );
}
