import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, video, audio }

class Message {
  final String id;
  final String expediteurId;
  final String destinataireId;
  final String contenu;
  final MessageType type;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int? mediaSizeBytes;
  final int? mediaDurationSeconds;
  final bool estLu;
  final DateTime creeLe;
  // Champs pour les invités (non connectés)
  final String? guestName;
  final String? guestPhone;
  final bool isGuest;

  Message({
    required this.id,
    required this.expediteurId,
    required this.destinataireId,
    required this.contenu,
    this.type = MessageType.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.mediaSizeBytes,
    this.mediaDurationSeconds,
    this.estLu = false,
    required this.creeLe,
    this.guestName,
    this.guestPhone,
    this.isGuest = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      expediteurId: json['expediteurId'] as String,
      destinataireId: json['destinataireId'] as String,
      contenu: json['contenu'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      mediaUrl: json['mediaUrl'] as String? ?? json['imageUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      mediaSizeBytes: json['mediaSizeBytes'] as int?,
      mediaDurationSeconds: json['mediaDurationSeconds'] as int?,
      estLu: json['estLu'] as bool? ?? false,
      creeLe: (json['creeLe'] as Timestamp).toDate(),
      guestName: json['guestName'] as String?,
      guestPhone: json['guestPhone'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expediteurId': expediteurId,
      'destinataireId': destinataireId,
      'contenu': contenu,
      'type': type.name,
      'mediaUrl': mediaUrl,
      'thumbnailUrl': thumbnailUrl,
      'mediaSizeBytes': mediaSizeBytes,
      'mediaDurationSeconds': mediaDurationSeconds,
      'estLu': estLu,
      'creeLe': Timestamp.fromDate(creeLe),
      if (guestName != null) 'guestName': guestName,
      if (guestPhone != null) 'guestPhone': guestPhone,
      if (isGuest) 'isGuest': isGuest,
    };
  }

  String get senderDisplayName => isGuest ? (guestName ?? 'Invité') : 'Utilisateur';

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;
  bool get isImage => type == MessageType.image;
  bool get isVideo => type == MessageType.video;
  bool get isAudio => type == MessageType.audio;

  static const int maxMediaSizeBytes = 50 * 1024 * 1024; // 50 Mo max
}
