// screens/messages/messages_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/message_api_service.dart';

// Provider pour charger le nom d'un prestataire lazily (Firestore pour les profils)
final prestataireNameProvider = FutureProvider.family<({String name, String? photoUrl}), String>((ref, uid) async {
  try {
    final doc = await FirebaseService.instance.firestore.collection('prestataires').doc(uid).get();
    if (!doc.exists) return (name: 'Utilisateur', photoUrl: null);
    final data = doc.data()!;
    final name = '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
    return (name: name.isEmpty ? 'Utilisateur' : name, photoUrl: data['photoUrl'] as String? ?? data['photo_url'] as String?);
  } catch (e) {
    return (name: 'Utilisateur', photoUrl: null);
  }
});

class ConversationPreview {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime updatedAt;
  final String otherUserId;
  final String? otherUserName;
  final String? otherUserPhotoUrl;
  final bool isLastMessageFromMe;
  final bool lastMessageLu;
  final int unreadCount;
  final bool isGuestConversation;

  ConversationPreview({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
    required this.otherUserId,
    this.otherUserName,
    this.otherUserPhotoUrl,
    this.isLastMessageFromMe = false,
    this.lastMessageLu = false,
    this.unreadCount = 0,
    this.isGuestConversation = false,
  });
}

final conversationsProvider =
    StreamProvider<List<ConversationPreview>>((ref) {
      final user = ref.watch(authStateChangesProvider).asData?.value;
      final uid = user?.uid;
      if (uid == null) {
        return Stream.value(<ConversationPreview>[]);
      }

      // Polling MySQL pour les conversations
      return Stream.periodic(const Duration(seconds: 5), (_) => uid)
          .asyncMap((userId) async {
        try {
          final conversations = await MessageApiService.instance.getConversations(userId);
          final List<ConversationPreview> previews = [];
          for (final conv in conversations) {
            try {
              final participants = List<String>.from(conv['participants'] ?? []);
              final isGuestConv = (conv['is_guest_conversation'] == true || conv['is_guest_conversation'] == 1);
              final lastMessageLu = (conv['last_message_lu'] == true || conv['last_message_lu'] == 1);

              String otherUserId;
              String? otherUserName;

              if (isGuestConv) {
                otherUserId = conv['guest_id'] as String? ?? '';
                otherUserName = conv['guest_name'] as String? ?? 'Invité';
                final guestPhone = conv['guest_phone'] as String?;
                if (guestPhone != null && guestPhone.isNotEmpty) {
                  otherUserName = '$otherUserName ($guestPhone)';
                }
              } else {
                otherUserId = participants.firstWhere(
                  (p) => p != uid,
                  orElse: () => '',
                );
                otherUserName = null;
              }

              final lastMessage = conv['dernier_message'] as String? ?? 'Dernier message indisponible';
              final dernierExpediteurId = conv['dernier_expediteur_id'] as String? ?? '';
              final updatedAt = _parseDate(conv['dernier_message_date']);
              final unreadCount = (!lastMessageLu && dernierExpediteurId != uid) ? 1 : 0;

              previews.add(ConversationPreview(
                id: conv['id'] as String,
                title: otherUserName?.isNotEmpty == true ? otherUserName! : 'Discussion',
                lastMessage: lastMessage,
                updatedAt: updatedAt,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                isLastMessageFromMe: dernierExpediteurId == uid,
                lastMessageLu: lastMessageLu,
                unreadCount: unreadCount,
                isGuestConversation: isGuestConv,
              ));
            } catch (e) {
              if (kDebugMode) print('[MessagesScreen] Error processing conversation: $e');
            }
          }
          previews.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return previews;
        } catch (e) {
          if (kDebugMode) print('[MessagesScreen] conversationsProvider error: $e');
          return <ConversationPreview>[];
        }
      }).transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) print('[MessagesScreen] conversationsProvider stream error: $error');
            sink.add(<ConversationPreview>[]);
          },
        ),
      );
    });

final searchQueryProvider = StateProvider<String>((ref) => '');
final messageFilterProvider = StateProvider<MessageFilter>((ref) => MessageFilter.all);

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
  return DateTime.now();
}

enum MessageFilter { all, unread, recent }

class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final filter = ref.watch(messageFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Messages',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une conversation...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: (value) {
                ref.read(searchQueryProvider.notifier).state = value;
              },
            ),
          ),
          // Filtres
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: MessageFilter.values.map((f) {
                final isSelected = filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_getFilterLabel(f)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(messageFilterProvider.notifier).state = f;
                      }
                    },
                    selectedColor: AppColors.primaryOrange.withAlpha(26),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      color: isSelected ? AppColors.primaryOrange : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Liste des conversations
          Expanded(
            child: conversationsAsync.when(
              skipLoadingOnRefresh: true,
              data: (conversations) {
                final filtered = _filterConversations(conversations, searchQuery, filter);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: AppColors.textSecondary.withAlpha(128),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          conversations.isEmpty
                              ? 'Aucune conversation'
                              : 'Aucun résultat',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          conversations.isEmpty
                              ? 'Vos conversations apparaîtront ici'
                              : 'Essayez une autre recherche',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textSecondary.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final conversation = filtered[index];
                    final showDateHeader = index == 0 ||
                        !_isSameDay(conversation.updatedAt, filtered[index - 1].updatedAt);
                    
                    return Column(
                      children: [
                        if (showDateHeader) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.borderGray,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _formatDateHeader(conversation.updatedAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        InkWell(
                          onTap: () => context.push('/messages/${conversation.id}'),
                          borderRadius: BorderRadius.circular(16),
                          child: _ConversationTile(
                            conversation: conversation,
                            prestataireName: conversation.otherUserName == null && conversation.otherUserId.isNotEmpty
                                ? ref.watch(prestataireNameProvider(conversation.otherUserId))
                                : null,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Impossible de charger les messages.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<ConversationPreview> _filterConversations(
    List<ConversationPreview> conversations,
    String searchQuery,
    MessageFilter filter,
  ) {
    var filtered = conversations;

    // Filtre par recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((c) =>
              c.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              c.lastMessage.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }

    // Filtre par type
    switch (filter) {
      case MessageFilter.recent:
        final now = DateTime.now();
        filtered = filtered
            .where((c) => now.difference(c.updatedAt).inDays < 7)
            .toList();
        break;
      case MessageFilter.unread:
        filtered = filtered.where((c) => c.unreadCount > 0).toList();
        break;
      case MessageFilter.all:
        break;
    }

    return filtered;
  }

  String _getFilterLabel(MessageFilter filter) {
    switch (filter) {
      case MessageFilter.all:
        return 'Toutes';
      case MessageFilter.unread:
        return 'Non lues';
      case MessageFilter.recent:
        return 'Récentes';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final isYesterday = _isSameDay(date, now.subtract(const Duration(days: 1)));

    if (isToday) return 'Aujourd\'hui';
    if (isYesterday) return 'Hier';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _ConversationTile extends StatelessWidget {
  final ConversationPreview conversation;
  final AsyncValue<({String name, String? photoUrl})>? prestataireName;

  const _ConversationTile({
    required this.conversation,
    this.prestataireName,
  });

  @override
  Widget build(BuildContext context) {
    // Résoudre le nom et la photo
    String title = conversation.title;
    String? photoUrl = conversation.otherUserPhotoUrl;

    if (prestataireName != null) {
      final data = prestataireName!.asData?.value;
      if (data != null) {
        title = data.name;
        photoUrl = data.photoUrl;
      } else if (prestataireName!.isLoading) {
        title = 'Chargement...';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray, width: 1),
        boxShadow: conversation.unreadCount > 0
            ? [
                BoxShadow(
                  color: AppColors.primaryOrange.withAlpha(26),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: photoUrl != null && photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _buildInitialsAvatar(title),
                  )
                : _buildInitialsAvatar(title),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: conversation.unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (conversation.isGuestConversation)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.infoBlue.withAlpha(30),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Invité',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.infoBlue,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (conversation.unreadCount > 0)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          conversation.unreadCount > 99 ? '99+' : conversation.unreadCount.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  conversation.isLastMessageFromMe
                      ? 'Vous: ${conversation.lastMessage}'
                      : conversation.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: conversation.unreadCount > 0 && !conversation.isLastMessageFromMe ? FontWeight.w600 : FontWeight.w400,
                    color: conversation.unreadCount > 0 && !conversation.isLastMessageFromMe ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(conversation.updatedAt),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: conversation.unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                  color: conversation.unreadCount > 0 ? AppColors.primaryOrange : AppColors.textSecondary,
                ),
              ),
              if (conversation.isLastMessageFromMe) ...[
                const SizedBox(height: 4),
                Icon(
                  conversation.lastMessageLu ? Icons.done_all : Icons.done,
                  size: 14,
                  color: conversation.lastMessageLu ? AppColors.primaryOrange : AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(String title) {
    final initial = title.isNotEmpty ? title[0].toUpperCase() : 'C';
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.primaryOrangeLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryOrange,
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    if (now.difference(dateTime).inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}
