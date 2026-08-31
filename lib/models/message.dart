// models/message.dart
// Modèle de message compatible MySQL (plus de dépendance Firestore)

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

  /// Parse depuis MySQL (réponse de l'API PHP)
  factory Message.fromMySQL(Map<String, dynamic> row) {
    return Message(
      id: row['id'].toString(),
      expediteurId: row['expediteur_id'] as String? ?? '',
      destinataireId: row['destinataire_id'] as String? ?? '',
      contenu: row['contenu'] as String? ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.name == (row['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      mediaUrl: row['media_url'] as String?,
      thumbnailUrl: null,
      mediaSizeBytes: row['media_size_bytes'] != null
          ? int.tryParse(row['media_size_bytes'].toString())
          : null,
      mediaDurationSeconds: row['media_duration_seconds'] != null
          ? int.tryParse(row['media_duration_seconds'].toString())
          : null,
      estLu: (row['est_lu'] != null && row['est_lu'] != 0 && row['est_lu'] != false),
      creeLe: _parseDate(row['cree_le']),
      guestName: row['guest_name'] as String?,
      guestPhone: row['guest_phone'] as String?,
      isGuest: (row['is_guest'] != null && row['is_guest'] != 0 && row['is_guest'] != false),
    );
  }

  /// Parse depuis Firestore (compatibilité ascendante)
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      expediteurId: json['expediteurId'] as String? ?? '',
      destinataireId: json['destinataireId'] as String? ?? '',
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
      creeLe: _parseDate(json['creeLe']),
      guestName: json['guestName'] as String?,
      guestPhone: json['guestPhone'] as String?,
      isGuest: json['isGuest'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return DateTime.now();
      }
    }
    // Firestore Timestamp fallback
    try {
      return value.toDate();
    } catch (_) {
      return DateTime.now();
    }
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
      'creeLe': creeLe.toIso8601String(),
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
