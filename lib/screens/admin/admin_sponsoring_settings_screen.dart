// screens/admin/admin_sponsoring_settings_screen.dart
// Paramétrage de la validation automatique du sponsoring

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../models/sponsoring_validation.dart';
import '../../services/sponsoring_validation_service.dart';
import '../../widgets/miwodo_button.dart';
import 'admin_shell.dart';

class AdminSponsoringSettingsScreen extends ConsumerStatefulWidget {
  const AdminSponsoringSettingsScreen({super.key});

  @override
  ConsumerState<AdminSponsoringSettingsScreen> createState() => _AdminSponsoringSettingsScreenState();
}

class _AdminSponsoringSettingsScreenState extends ConsumerState<AdminSponsoringSettingsScreen> {
  int _currentTab = 0;
  final _tabs = ['Paramètres', 'Mots interdits', 'Historique', 'Rejetées'];

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Config. Sponsoring',
      child: Column(
        children: [
          _buildTabBar(),
          const SizedBox(height: 8),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_tabs.length, (i) {
            final isSelected = i == _currentTab;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_tabs[i]),
                selected: isSelected,
                onSelected: (_) => setState(() => _currentTab = i),
                selectedColor: AppColors.primaryOrange,
                labelStyle: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                backgroundColor: AppColors.white,
                side: BorderSide(color: AppColors.borderGray),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_currentTab) {
      case 0:
        return _SettingsTab();
      case 1:
        return _ForbiddenWordsTab();
      case 2:
        return _HistoryTab();
      case 3:
        return _RejectedTab();
      default:
        return const SizedBox.shrink();
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB: PARAMÈTRES
// ═══════════════════════════════════════════════════════════════════════════

class _SettingsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late double _seuilAuto;
  late double _seuilLog;
  late bool _autoActive;
  late int _maxEmojis;
  late int _maxRepetition;
  bool _isLoading = false;
  bool _hasLoaded = false;

  @override
  Widget build(BuildContext context) {
    if (!_hasLoaded) {
      return _buildLoading();
    }
    return _buildContent();
  }

  Widget _buildLoading() {
    return StreamBuilder<SponsoringSettings>(
      stream: SponsoringValidationService.instance.watchSettings(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final s = snap.data;
        if (s != null && !_hasLoaded) {
          _seuilAuto = s.seuilConfianceAuto;
          _seuilLog = s.seuilJournalisation;
          _autoActive = s.autoValidationActive;
          _maxEmojis = s.maxEmojisAutorises;
          _maxRepetition = s.maxCaracteresRepetition;
          _hasLoaded = true;
        }
        if (!_hasLoaded) {
          return const Center(child: Text('Chargement...'));
        }
        return _buildContent();
      },
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle validation auto
          _buildSectionCard(
            'Validation automatique',
            SwitchListTile(
              title: Text('Activer la validation automatique', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('Si activé, les campagnes conformes sont validées sans intervention manuelle',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              value: _autoActive,
              activeThumbColor: AppColors.primaryOrange,
              onChanged: (v) => setState(() => _autoActive = v),
            ),
          ),
          const SizedBox(height: 16),

          // Seuils
          _buildSectionCard(
            'Seuils de confiance',
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Score pour validation automatique: ${_seuilAuto.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _seuilAuto,
                    min: 50,
                    max: 100,
                    divisions: 10,
                    activeColor: AppColors.primaryOrange,
                    label: '${_seuilAuto.toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _seuilAuto = v),
                  ),
                  Text('Au-dessus de ce seuil, la campagne est validée automatiquement.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  Text('Score pour journalisation: ${_seuilLog.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _seuilLog,
                    min: 50,
                    max: 100,
                    divisions: 10,
                    activeColor: AppColors.primaryOrange,
                    label: '${_seuilLog.toStringAsFixed(0)}%',
                    onChanged: (v) => setState(() => _seuilLog = v),
                  ),
                  Text('Entre ce seuil et le seuil auto, la campagne est validée avec journalisation.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Paramètres anti-spam
          _buildSectionCard(
            'Paramètres anti-spam',
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Emojis maximum autorisés: $_maxEmojis',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _maxEmojis.toDouble(),
                    min: 0,
                    max: 20,
                    divisions: 20,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (v) => setState(() => _maxEmojis = v.toInt()),
                  ),
                  const SizedBox(height: 8),
                  Text('Répétition max de caractères: $_maxRepetition',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                  Slider(
                    value: _maxRepetition.toDouble(),
                    min: 2,
                    max: 10,
                    divisions: 8,
                    activeColor: AppColors.primaryOrange,
                    onChanged: (v) => setState(() => _maxRepetition = v.toInt()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Bouton sauvegarder
          MiwodoButton(
            label: 'Sauvegarder les paramètres',
            variant: MiwodoButtonVariant.primary,
            isLoading: _isLoading,
            onPressed: _save,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final current = await SponsoringValidationService.instance.getSettings();
      final updated = current.copyWith(
        autoValidationActive: _autoActive,
        seuilConfianceAuto: _seuilAuto,
        seuilJournalisation: _seuilLog,
        maxEmojisAutorises: _maxEmojis,
        maxCaracteresRepetition: _maxRepetition,
        modifieLe: DateTime.now(),
      );
      await SponsoringValidationService.instance.updateSettings(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paramètres sauvegardés ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionCard(String title, Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(title, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB: MOTS INTERDITS
// ═══════════════════════════════════════════════════════════════════════════

class _ForbiddenWordsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ForbiddenWordsTab> createState() => _ForbiddenWordsTabState();
}

class _ForbiddenWordsTabState extends ConsumerState<_ForbiddenWordsTab> {
  final _controller = TextEditingController();
  List<String> _forbidden = [];
  List<String> _suspicious = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    final settings = await SponsoringValidationService.instance.getSettings();
    setState(() {
      _forbidden = List.from(settings.motsInterdits);
      _suspicious = List.from(settings.motsSuspects);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mots interdits
          Text('Mots interdits', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Ces mots bloquent automatiquement la validation', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _buildWordList(_forbidden, true),
          const SizedBox(height: 24),

          // Mots suspects
          Text('Mots suspects', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Ces mots réduisent le score de confiance sans bloquer', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          _buildWordList(_suspicious, false),
          const SizedBox(height: 24),

          MiwodoButton(
            label: 'Sauvegarder les listes',
            variant: MiwodoButtonVariant.primary,
            isLoading: _isLoading,
            onPressed: _saveWords,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildWordList(List<String> words, bool isForbidden) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: words.map((word) {
              return Chip(
                label: Text(word, style: GoogleFonts.inter(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  setState(() {
                    if (isForbidden) {
                      _forbidden.remove(word);
                    } else {
                      _suspicious.remove(word);
                    }
                  });
                },
                backgroundColor: isForbidden ? AppColors.errorRed.withAlpha(20) : AppColors.primaryOrange.withAlpha(20),
                side: BorderSide.none,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ajouter un mot...',
                    hintStyle: GoogleFonts.inter(fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (value) => _addWord(value, isForbidden),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primaryOrange),
                onPressed: () => _addWord(_controller.text, isForbidden),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addWord(String word, bool isForbidden) {
    final trimmed = word.trim().toLowerCase();
    if (trimmed.isEmpty) return;
    setState(() {
      if (isForbidden && !_forbidden.contains(trimmed)) {
        _forbidden.add(trimmed);
      } else if (!isForbidden && !_suspicious.contains(trimmed)) {
        _suspicious.add(trimmed);
      }
      _controller.clear();
    });
  }

  Future<void> _saveWords() async {
    setState(() => _isLoading = true);
    try {
      final settings = await SponsoringValidationService.instance.getSettings();
      final updated = settings.copyWith(
        motsInterdits: _forbidden,
        motsSuspects: _suspicious,
        modifieLe: DateTime.now(),
      );
      await SponsoringValidationService.instance.updateSettings(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listes sauvegardées ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB: HISTORIQUE
// ═══════════════════════════════════════════════════════════════════════════

class _HistoryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<SponsoringValidationLog>>(
      stream: SponsoringValidationService.instance.getValidationLogs(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) {
          return Center(
            child: Text('Aucun historique de validation', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return _ValidationLogCard(log: log);
          },
        );
      },
    );
  }
}

class _ValidationLogCard extends StatelessWidget {
  final SponsoringValidationLog log;

  const _ValidationLogCard({required this.log});

  Color _scoreColor() {
    if (log.score >= 95) return AppColors.successGreen;
    if (log.score >= 80) return const Color(0xFFF59E0B);
    return AppColors.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final color = _scoreColor();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  log.serviceName,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${log.score.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.person, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(log.prestataireNom, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              Icon(log.autoApproved ? Icons.check_circle : Icons.pending, size: 14, color: log.autoApproved ? AppColors.successGreen : AppColors.primaryOrange),
              const SizedBox(width: 4),
              Text(log.mode.displayLabel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          if (log.reasons.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGray,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: log.reasons.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber, size: 14, color: AppColors.errorRed),
                      const SizedBox(width: 4),
                      Expanded(child: Text(r, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary))),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '${log.analyseLe.day}/${log.analyseLe.month}/${log.analyseLe.year} ${log.analyseLe.hour}:${log.analyseLe.minute.toString().padLeft(2, '0')}',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB: REJETÉES / VÉRIFICATION HUMAINE
// ═══════════════════════════════════════════════════════════════════════════

class _RejectedTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<List<SponsoringValidationLog>>(
      stream: SponsoringValidationService.instance.getValidationLogs(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final allLogs = snapshot.data ?? [];
        // Filtrer: seulement celles en vérification humaine (score < seuil ou avec raisons)
        final rejected = allLogs.where((l) => !l.autoApproved && l.reasons.isNotEmpty).toList();
        if (rejected.isEmpty) {
          return Center(
            child: Text('Aucune campagne en vérification humaine', style: GoogleFonts.inter(color: AppColors.textSecondary)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: rejected.length,
          itemBuilder: (context, index) {
            return _ValidationLogCard(log: rejected[index]);
          },
        );
      },
    );
  }
}
