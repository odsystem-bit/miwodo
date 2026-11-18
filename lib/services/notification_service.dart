// services/notification_service.dart
// Service de notifications push (FCM) + notifications locales

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// Handler pour les messages en arrière-plan (doit être top-level)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) print('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _initialized = false;
  String? _fcmToken;
  GoRouter? _router;

  String? get fcmToken => _fcmToken;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALISATION
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> initialize({GoRouter? router}) async {
    if (_initialized) return;
    _router = router;

    // Configurer le handler background
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Demander les permissions
    await _requestPermissions();

    // Initialiser les notifications locales
    await _initLocalNotifications();

    // Configurer les listeners FCM
    _setupFCMListeners();

    // Récupérer et sauvegarder le token
    await _getAndSaveToken();

    // Écouter les changements de token
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    _initialized = true;
    if (kDebugMode) print('[NotificationService] Initialized');
  }

  Future<void> _requestPermissions() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('[FCM] Permission status: ${settings.authorizationStatus}');
    }

    // iOS: Configurer les options de présentation foreground
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _initLocalNotifications() async {
    // Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Créer le canal Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'miwodo_default',
        'Notifications Miwodo',
        description: 'Notifications générales de Miwodo',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  void _setupFCMListeners() {
    // Message reçu quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Message tapé quand l'app était en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Vérifier si l'app a été ouverte via une notification
    _checkInitialMessage();
  }

  Future<void> _checkInitialMessage() async {
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageOpenedApp(initialMessage);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GESTION DU TOKEN FCM
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _getAndSaveToken() async {
    try {
      _fcmToken = await _fcm.getToken();
      if (_fcmToken != null) {
        await _saveTokenToFirestore(_fcmToken!);
      }
    } catch (e) {
      if (kDebugMode) print('[FCM] Error getting token: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Check if user is an admin first
      final adminDoc = await _db.collection('admins').doc(user.uid).get();
      final isAdmin = adminDoc.exists && (adminDoc.data()?['actif'] as bool? ?? false);

      if (isAdmin) {
        await _db.collection('admins').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        });
      } else {
        await _db.collection('prestataires').doc(user.uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'platform': Platform.isIOS ? 'ios' : 'android',
        });
      }
      if (kDebugMode) print('[FCM] Token saved for user ${user.uid} (admin: $isAdmin)');
    } catch (e) {
      if (kDebugMode) print('[FCM] Error saving token: $e');
    }
  }

  /// Supprimer le token (à appeler lors de la déconnexion)
  Future<void> removeToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Try removing from both collections (one will succeed, the other will silently fail)
      try {
        await _db.collection('prestataires').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (_) {}
      try {
        await _db.collection('admins').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
      } catch (_) {}
      await _fcm.deleteToken();
      _fcmToken = null;
    } catch (e) {
      if (kDebugMode) print('[FCM] Error removing token: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GESTION DES MESSAGES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) {
      print('[FCM] Foreground message: ${message.notification?.title}');
    }

    final notification = message.notification;
    if (notification == null) return;

    // Afficher une notification locale
    await showLocalNotification(
      title: notification.title ?? 'Miwodo',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      print('[FCM] Message opened app: ${message.data}');
    }
    _navigateFromPayload(message.data);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _navigateFromPayload(data);
    } catch (e) {
      if (kDebugMode) print('[Notification] Error parsing payload: $e');
    }
  }

  void _navigateFromPayload(Map<String, dynamic> data) {
    if (_router == null) return;

    final type = data['type'] as String?;
    final targetId = data['targetId'] as String?;
    final isAdmin = data['isAdmin'] as bool? ?? false;

    switch (type) {
      case 'message':
        if (targetId != null) {
          _router!.go('/conversation/$targetId');
        }
        break;
      case 'commande':
        if (isAdmin) {
          _router!.go('/admin/commandes');
        } else if (targetId != null) {
          _router!.go('/suivi-commande/$targetId');
        }
        break;
      case 'avis':
        _router!.go('/dashboard');
        break;
      case 'admin_prestataire':
        _router!.go('/admin/prestataires');
        break;
      case 'admin_signalement':
        _router!.go('/admin/signalements');
        break;
      case 'retrait':
        if (isAdmin) {
          _router!.go('/admin/retraits');
        } else {
          _router!.go('/dashboard');
        }
        break;
      default:
        _router!.go('/accueil');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICATIONS LOCALES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    int id = 0,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'miwodo_default',
      'Notifications Miwodo',
      channelDescription: 'Notifications générales de Miwodo',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Notification pour nouveau message
  Future<void> showMessageNotification({
    required String senderName,
    required String message,
    required String conversationId,
  }) async {
    await showLocalNotification(
      title: senderName,
      body: message,
      payload: jsonEncode({'type': 'message', 'targetId': conversationId}),
      id: conversationId.hashCode,
    );
  }

  /// Notification pour nouvelle commande
  Future<void> showOrderNotification({
    required String title,
    required String body,
    required String commandeId,
  }) async {
    await showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({'type': 'commande', 'targetId': commandeId}),
      id: commandeId.hashCode,
    );
  }

  /// Annuler une notification
  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Annuler toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FIRESTORE NOTIFICATION RECORDS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a notification document in Firestore for a specific user
  Future<void> createNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? targetId,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'targetId': targetId,
        'data': data ?? {},
        'estLu': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) print('[Notification] Error creating notification: $e');
    }
  }

  /// Create notifications for all active admins
  Future<void> notifyAdmins({
    required String title,
    required String body,
    required String type,
    String? targetId,
  }) async {
    try {
      final adminsSnap = await _db
          .collection('admins')
          .where('actif', isEqualTo: true)
          .get();

      for (final doc in adminsSnap.docs) {
        await createNotification(
          userId: doc.id,
          title: title,
          body: body,
          type: type,
          targetId: targetId,
          data: {'isAdmin': true},
        );
      }
    } catch (e) {
      if (kDebugMode) print('[Notification] Error notifying admins: $e');
    }
  }

  /// Notify a specific user about a new message
  Future<void> notifyNewMessage({
    required String recipientId,
    required String senderName,
    required String messagePreview,
    required String conversationId,
  }) async {
    await createNotification(
      userId: recipientId,
      title: senderName,
      body: messagePreview,
      type: 'message',
      targetId: conversationId,
    );
  }

  /// Notify a user and admins about a new order
  Future<void> notifyNewOrder({
    required String vendeurId,
    required String commandeId,
    required String clientName,
    required int total,
  }) async {
    // Notify the seller
    await createNotification(
      userId: vendeurId,
      title: 'Nouvelle commande',
      body: '$clientName a passé une commande de ${total.toStringAsFixed(0)} F',
      type: 'commande',
      targetId: commandeId,
    );
    // Notify all admins
    await notifyAdmins(
      title: 'Nouvelle commande',
      body: 'Commande $commandeId de ${total.toStringAsFixed(0)} F par $clientName',
      type: 'commande',
      targetId: commandeId,
    );
  }

  /// Notify admins about a new prestataire registration
  Future<void> notifyNewPrestataire({
    required String prestataireId,
    required String prestataireName,
  }) async {
    await notifyAdmins(
      title: 'Nouveau prestataire',
      body: '$prestataireName s\'est inscrit',
      type: 'admin_prestataire',
      targetId: prestataireId,
    );
  }

  /// Notify admins about a new signalement
  Future<void> notifyNewSignalement({
    required String signalementId,
    required String motif,
  }) async {
    await notifyAdmins(
      title: 'Nouveau signalement',
      body: 'Motif: $motif',
      type: 'admin_signalement',
      targetId: signalementId,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BADGES (iOS)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> updateBadgeCount(int count) async {
    if (Platform.isIOS) {
      // iOS gère automatiquement via APNs
    }
  }

  Future<void> clearBadge() async {
    if (Platform.isIOS) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(badge: true);
    }
  }
}
