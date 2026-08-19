// screens/admin/admin_notifications_screen.dart
// Notifications admin — temps réel via Firestore, marquer comme lu
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'admin_shell.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends ConsumerState<AdminNotificationsScreen> {
  String _filter = 'tous';
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  List<({String id, Map<String, dynamic> data})> _allNotifications = [];

  static const int _pageSize = 25;

  final _filters = [
    ('tous', 'Tous'),
    ('non_lus', 'Non lus'),
    ('message', 'Messages'),
    ('commande', 'Commandes'),
    ('admin_prestataire', 'Inscriptions'),
    ('admin_signalement', 'Signalements'),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      title: 'Notifications',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final (value, label) = _filters[index];
                  return ChoiceChip(
                    label: Text(label),
                    selected: _filter == value,
                    selectedColor: AppColors.primaryOrange.withAlpha(46),
                    onSelected: (_) => setState(() => _filter = value),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: Text('Tout marquer lu', style: GoogleFonts.inter(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(child: _buildNotificationsList()),
            if (_hasMore && _allNotifications.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: _isLoadingMore ? null : _loadMore,
                  icon: _isLoadingMore
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.expand_more),
                  label: Text(_isLoadingMore ? 'Chargement...' : 'Charger plus', style: GoogleFonts.inter(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Text('Non connecté', style: GoogleFonts.inter(color: AppColors.textSecondary));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(_pageSize)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        _allNotifications = docs.map((doc) {
          final data = doc.data();
          return (id: doc.id, data: data);
        }).toList();

        _lastDoc = docs.isNotEmpty ? docs.last : null;
        _hasMore = docs.length == _pageSize;

        // Apply filter
        var notifications = _allNotifications;
        if (_filter == 'non_lus') {
          notifications = notifications.where((n) => n.data['estLu'] != true).toList();
        } else if (_filter != 'tous') {
          notifications = notifications.where((n) => n.data['type'] == _filter).toList();
        }

        if (notifications.isEmpty) {
          return Center(
            child: Text(
              'Aucune notification.',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView.separated(
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final n = notifications[index];
            return _NotificationCard(
              id: n.id,
              data: n.data,
              onTap: () => _markAsRead(n.id),
            );
          },
        );
      },
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoadingMore = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      if (snap.docs.isEmpty) {
        _hasMore = false;
      } else {
        _allNotifications.addAll(snap.docs.map((doc) {
          final data = doc.data();
          return (id: doc.id, data: data);
        }));
        _lastDoc = snap.docs.last;
        _hasMore = snap.docs.length == _pageSize;
      }
    } catch (e) {
      if (kDebugMode) print('[AdminNotifications] loadMore error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'estLu': true});
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('estLu', isEqualTo: false)
          .get();

      for (final doc in snap.docs) {
        batch.update(doc.reference, {'estLu': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Toutes les notifications marquées comme lues')),
        );
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

class _NotificationCard extends StatelessWidget {
  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _NotificationCard({required this.id, required this.data, required this.onTap});

  IconData _typeIcon() {
    switch (data['type']) {
      case 'message':
        return Icons.message;
      case 'commande':
        return Icons.shopping_bag;
      case 'admin_prestataire':
        return Icons.person_add;
      case 'admin_signalement':
        return Icons.flag;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor() {
    switch (data['type']) {
      case 'message':
        return const Color(0xFF2196F3);
      case 'commande':
        return AppColors.primaryOrange;
      case 'admin_prestataire':
        return AppColors.successGreen;
      case 'admin_signalement':
        return AppColors.errorRed;
      default:
        return AppColors.textSecondary;
    }
  }

  String _formatDate(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final dt = createdAt.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      return '${dt.day}/${dt.month}/${dt.year}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = data['estLu'] != true;
    final color = _typeColor();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isUnread ? BorderSide(color: color.withAlpha(80), width: 1.5) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_typeIcon(), color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['title'] as String? ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['body'] as String? ?? '',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDate(data['createdAt']),
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary),
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
