// screens/conversation_screen.dart
// Écran de conversation avec support images, vidéos, audio

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_colors.dart';
import '../models/message.dart';
import '../models/prestataire.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
import '../widgets/miwodo_svg_icon.dart';

// Provider pour les messages d'une conversation
final messagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return FirebaseFirestore.instance
      .collection('conversations')
      .doc(conversationId)
      .collection('messages')
      .orderBy('creeLe', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs.map((d) => Message.fromJson({...d.data(), 'id': d.id})).toList())
      .transform(
        StreamTransformer.fromHandlers(
          handleError: (error, stack, sink) {
            if (kDebugMode) {
              print('[Conversation] messagesProvider stream error: $error');
            }
            sink.add(<Message>[]);
          },
        ),
      );
});

// Provider pour les infos du destinataire
final destinataireProvider = FutureProvider.family<Prestataire?, String>((ref, id) async {
  final doc = await FirebaseFirestore.instance.collection('prestataires').doc(id).get();
  if (!doc.exists) return null;
  return Prestataire.fromJson({...doc.data()!, 'id': doc.id});
});

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.id});

  final String id; // ID de la conversation (format: minId_maxId)

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  double _uploadProgress = 0;
  String? _uploadingType;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  String get _otherUserId {
    final parts = widget.id.split('_');
    return parts.firstWhere((p) => p != _currentUserId, orElse: () => parts.first);
  }

  @override
  void initState() {
    super.initState();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    final unread = await FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.id)
        .collection('messages')
        .where('destinataireId', isEqualTo: _currentUserId)
        .where('estLu', isEqualTo: false)
        .get();

    for (final doc in unread.docs) {
      batch.update(doc.reference, {'estLu': true});
    }

    // Marquer la conversation comme lue
    batch.update(
      FirebaseFirestore.instance.collection('conversations').doc(widget.id),
      {'lastMessageLu': true},
    );

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.id));
    final destinataireAsync = ref.watch(destinataireProvider(_otherUserId));

    return Scaffold(
      backgroundColor: AppColors.surfaceGray,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const MiwodoSvgIcon('assets/icons/ic_arrow_back.svg', size: 24),
          onPressed: () => context.pop(),
        ),
        title: destinataireAsync.when(
          loading: () => const Text('...'),
          error: (e, st) => const Text('Conversation'),
          data: (dest) => dest == null
              ? const Text('Conversation')
              : Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: dest.photoUrl != null ? CachedNetworkImageProvider(dest.photoUrl!) : null,
                      backgroundColor: AppColors.primaryOrangeLight,
                      child: dest.photoUrl == null ? Text(dest.prenom[0], style: const TextStyle(color: AppColors.primaryOrange)) : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${dest.prenom} ${dest.nom}', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          Text(dest.categorie, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        actions: [
          destinataireAsync.whenOrNull(
            data: (dest) => dest != null
                ? IconButton(
                    icon: const MiwodoSvgIcon('assets/icons/ic_phone.svg', size: 22, color: AppColors.primaryOrange),
                    onPressed: () => _callPrestataire(dest.telephone),
                  )
                : null,
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Erreur: $e')),
              data: (messages) {
                final destinataire = destinataireAsync.asData?.value;
                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const MiwodoSvgIcon('assets/icons/ic_chat.svg', size: 64, color: AppColors.borderGray),
                          const SizedBox(height: 16),
                          Text('Aucun message', style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
                          const SizedBox(height: 8),
                          Text('Envoyez le premier message !', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.expediteurId == _currentUserId;
                    final showDate = index == messages.length - 1 ||
                        !_isSameDay(msg.creeLe, messages[index + 1].creeLe);

                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(msg.creeLe),
                        _MessageBubble(
                          message: msg,
                          isMe: isMe,
                          otherUserName: isMe ? null : destinataire?.prenom ?? 'Prestataire',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Upload progress
          if (_uploadingType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primaryOrangeLight,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: _uploadProgress,
                      strokeWidth: 2,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Envoi ${_uploadingType == 'image' ? 'de l\'image' : _uploadingType == 'video' ? 'de la vidéo' : 'de l\'audio'}... ${(_uploadProgress * 100).toInt()}%',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.primaryOrange),
                  ),
                ],
              ),
            ),

          // Input
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final isToday = _isSameDay(date, now);
    final isYesterday = _isSameDay(date, now.subtract(const Duration(days: 1)));

    String label;
    if (isToday) {
      label = 'Aujourd\'hui';
    } else if (isYesterday) {
      label = 'Hier';
    } else {
      label = DateFormat('d MMMM yyyy', 'fr_FR').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.borderGray,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.textSecondary)),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderGray)),
      ),
      child: Row(
        children: [
          // Bouton média
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primaryOrange, size: 28),
            onSelected: _handleMediaSelection,
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'image', child: Row(children: [Icon(Icons.image_outlined, size: 20), SizedBox(width: 8), Text('Photo')])),
              const PopupMenuItem(value: 'camera', child: Row(children: [Icon(Icons.camera_alt_outlined, size: 20), SizedBox(width: 8), Text('Caméra')])),
              const PopupMenuItem(value: 'video', child: Row(children: [Icon(Icons.videocam_outlined, size: 20), SizedBox(width: 8), Text('Vidéo')])),
            ],
          ),

          // Champ texte
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Votre message...',
                filled: true,
                fillColor: AppColors.surfaceGray,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Bouton micro (désactivé temporairement - audio non fonctionnel)
          // if (_messageController.text.trim().isEmpty) ...[
          //   GestureDetector(
          //     onTap: _startRecording,
          //     child: Container(
          //       padding: const EdgeInsets.all(10),
          //       decoration: BoxDecoration(
          //         color: AppColors.surfaceGray,
          //         shape: BoxShape.circle,
          //       ),
          //       child: const Icon(Icons.mic, color: AppColors.primaryOrange, size: 22),
          //     ),
          //   ),
          //   const SizedBox(width: 8),
          // ],

          // Bouton envoyer
          GestureDetector(
            onTap: _isSending ? null : _sendTextMessage,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMediaSelection(String type) async {
    final picker = ImagePicker();
    XFile? picked;

    switch (type) {
      case 'image':
        picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        break;
      case 'camera':
        picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
        break;
      case 'video':
        picked = await picker.pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
        break;
    }

    if (picked == null) return;

    final file = File(picked.path);
    final sizeBytes = await file.length();

    // Vérifier la taille (50 Mo max)
    if (sizeBytes > Message.maxMediaSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le fichier est trop volumineux (max 50 Mo)'), backgroundColor: AppColors.errorRed),
        );
      }
      return;
    }

    await _sendMediaMessage(file, type == 'video' ? MessageType.video : MessageType.image, sizeBytes);
  }

  Future<void> _sendTextMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _sendMessage(
        contenu: text,
        type: MessageType.text,
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMediaMessage(File file, MessageType type, int sizeBytes, {int? durationSeconds}) async {
    setState(() {
      _uploadingType = type == MessageType.image ? 'image' : type == MessageType.video ? 'video' : 'audio';
      _uploadProgress = 0;
    });

    try {
      // Extension selon le type
      String ext;
      switch (type) {
        case MessageType.video:
          ext = 'mp4';
          break;
        case MessageType.audio:
          ext = 'm4a';
          break;
        default:
          ext = 'jpg';
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = 'messages/${widget.id}/$fileName';
      String? url;
      try {
        url = await SupabaseService.uploadPhoto(
          bucket: 'miwodo-photos',
          path: path,
          file: file,
          contentType: type == MessageType.video ? 'video/mp4' : 'image/jpeg',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur upload média: $e'), backgroundColor: AppColors.errorRed),
          );
        }
        return;
      }

      await _sendMessage(
        contenu: type == MessageType.image ? '📷 Photo' : type == MessageType.video ? '🎥 Vidéo' : '🎵 Audio',
        type: type,
        mediaUrl: url,
        mediaSizeBytes: sizeBytes,
        mediaDurationSeconds: durationSeconds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi: $e'), backgroundColor: AppColors.errorRed),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingType = null;
          _uploadProgress = 0;
        });
      }
    }
  }

  Future<void> _sendMessage({
    required String contenu,
    required MessageType type,
    String? mediaUrl,
    int? mediaSizeBytes,
    int? mediaDurationSeconds,
  }) async {
    final msgData = {
      'expediteurId': _currentUserId,
      'destinataireId': _otherUserId,
      'contenu': contenu,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'mediaSizeBytes': mediaSizeBytes,
      'mediaDurationSeconds': mediaDurationSeconds,
      'estLu': false,
      'creeLe': FieldValue.serverTimestamp(),
    };

    // Créer/mettre à jour la conversation
    final convRef = FirebaseFirestore.instance.collection('conversations').doc(widget.id);
    await convRef.set({
      'participants': [_currentUserId, _otherUserId],
      'dernierMessage': contenu,
      'dernierMessageDate': FieldValue.serverTimestamp(),
      'dernierExpediteurId': _currentUserId,
      'lastMessageLu': false,
    }, SetOptions(merge: true));

    // Ajouter le message
    await convRef.collection('messages').add(msgData);

    // Créer une notification Firestore pour le destinataire
    try {
      final senderDoc = await FirebaseFirestore.instance
          .collection('prestataires')
          .doc(_currentUserId)
          .get();
      final senderName = senderDoc.exists
          ? '${senderDoc.data()?['prenom'] ?? ''} ${senderDoc.data()?['nom'] ?? ''}'.trim()
          : 'Utilisateur';
      await NotificationService.instance.notifyNewMessage(
        recipientId: _otherUserId,
        senderName: senderName.isEmpty ? 'Utilisateur' : senderName,
        messagePreview: contenu,
        conversationId: widget.id,
      );
    } catch (e) {
      // Silent fail — notification is best-effort
    }
  }

  Future<void> _callPrestataire(String telephone) async {
    final uri = Uri.parse('tel:$telephone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? otherUserName;

  const _MessageBubble({required this.message, required this.isMe, this.otherUserName});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: message.hasMedia ? const EdgeInsets.all(4) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primaryOrange : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(10),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom de l'expéditeur pour les messages reçus (invité ou utilisateur)
                  if (!isMe) ...[
                    if (message.isGuest && message.guestName != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.guestName!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (message.guestPhone != null) ...[
                            const SizedBox(width: 4),
                            Text(
                              '(${message.guestPhone})',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.infoBlue,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                    ] else if (otherUserName != null) ...[
                      Text(
                        otherUserName!,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ],
                  // Média
                  if (message.hasMedia) ...[
                    _buildMediaContent(context),
                    if (message.contenu.isNotEmpty && !message.contenu.startsWith('📷') && !message.contenu.startsWith('🎥'))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                        child: Text(
                          message.contenu,
                          style: GoogleFonts.inter(fontSize: 14, color: isMe ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                  ] else
                    Text(
                      message.contenu,
                      style: GoogleFonts.inter(fontSize: 14, color: isMe ? Colors.white : AppColors.textPrimary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('HH:mm').format(message.creeLe),
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.estLu ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.estLu ? AppColors.primaryOrange : AppColors.textSecondary,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    if (message.isImage) {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, message.mediaUrl!),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: message.mediaUrl!,
            width: 220,
            height: 220,
            fit: BoxFit.cover,
            placeholder: (ctx, url) => Container(
              width: 220,
              height: 220,
              color: AppColors.borderGray,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );
    }

    if (message.isVideo) {
      return GestureDetector(
        onTap: () => _playVideo(context, message.mediaUrl!),
        child: Container(
          width: 220,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (message.thumbnailUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: message.thumbnailUrl!,
                    width: 220,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(100),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _formatSize(message.mediaSizeBytes ?? 0),
                    style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (message.isAudio) {
      return _AudioPlayerWidget(message: message, isMe: isMe);
    }

    return const SizedBox.shrink();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url),
            ),
          ),
        ),
      ),
    );
  }

  void _playVideo(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Widget lecteur audio pour les messages vocaux
class _AudioPlayerWidget extends StatefulWidget {
  final Message message;
  final bool isMe;

  const _AudioPlayerWidget({
    required this.message,
    required this.isMe,
  });

  @override
  State<_AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<_AudioPlayerWidget> {
  final _player = AudioPlayerService.instance;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration>? _durationSubscription;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.message.mediaDurationSeconds ?? 0);

    _stateSubscription = _player.stateStream.listen((state) {
      if (_player.currentUrl == widget.message.mediaUrl) {
        if (mounted) {
          setState(() => _isPlaying = state == PlayerState.playing);
        }
      } else if (_isPlaying) {
        if (mounted) {
          setState(() => _isPlaying = false);
        }
      }
    });

    _positionSubscription = _player.positionStream.listen((pos) {
      if (_player.currentUrl == widget.message.mediaUrl && mounted) {
        setState(() => _position = pos);
      }
    });

    _durationSubscription = _player.durationStream.listen((dur) {
      if (_player.currentUrl == widget.message.mediaUrl && mounted) {
        setState(() => _duration = dur);
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.white.withAlpha(30) : AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bouton play/pause
          GestureDetector(
            onTap: () => _player.play(widget.message.mediaUrl!),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.isMe ? Colors.white : AppColors.primaryOrange,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMe ? AppColors.primaryOrange : Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Barre de progression et durée
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: widget.isMe ? Colors.white30 : AppColors.borderGray,
                    valueColor: AlwaysStoppedAnimation(
                      widget.isMe ? Colors.white : AppColors.primaryOrange,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                // Durée
                Text(
                  _isPlaying ? _formatDuration(_position) : _formatDuration(_duration),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: widget.isMe ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
