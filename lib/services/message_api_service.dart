// services/message_api_service.dart
// Service pour envoyer et recevoir des messages via l'API PHP/MySQL
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MessageApiService {
  MessageApiService._();
  static final MessageApiService instance = MessageApiService._();

  static const String _baseUrl =
      String.fromEnvironment('PAYMENT_API_URL',
          defaultValue: 'https://bot.odsysteme.tech/api');
  static const String _apiKey =
      String.fromEnvironment('PAYMENT_API_KEY',
          defaultValue: 'aadc42b40f152ad0133c93e5e154a843fc61952072b35e80');

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Api-Key': _apiKey,
      };

  /// Envoyer un message vers MySQL
  Future<bool> sendMessage({
    required String conversationId,
    required String expediteurId,
    required String destinataireId,
    required String contenu,
    String type = 'text',
    String? mediaUrl,
    int? mediaSizeBytes,
    int? mediaDurationSeconds,
    bool isGuest = false,
    String? guestName,
    String? guestPhone,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/messages'),
        headers: _headers,
        body: jsonEncode({
          'conversationId': conversationId,
          'expediteurId': expediteurId,
          'destinataireId': destinataireId,
          'contenu': contenu,
          'type': type,
          'mediaUrl': mediaUrl,
          'mediaSizeBytes': mediaSizeBytes,
          'mediaDurationSeconds': mediaDurationSeconds,
          'isGuest': isGuest,
          'guestName': guestName,
          'guestPhone': guestPhone,
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        if (kDebugMode) print('[MessageApi] Message sent to MySQL: $conversationId');
        return true;
      } else {
        if (kDebugMode) print('[MessageApi] Send failed: ${resp.statusCode} ${resp.body}');
        return false;
      }
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Send error: $e');
      return false;
    }
  }

  /// Récupérer les messages d'une conversation depuis MySQL
  Future<List<Map<String, dynamic>>> getMessages(String conversationId, {int lastId = 0}) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/messages?conv=$conversationId&lastId=$lastId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['messages'] ?? []);
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Get messages error: $e');
      return [];
    }
  }

  /// Récupérer une conversation spécifique
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/messages?conv=$conversationId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          final convs = data['conversations'] as List?;
          if (convs != null && convs.isNotEmpty) {
            return Map<String, dynamic>.from(convs.first);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Get conversation error: $e');
    }
    return null;
  }

  /// Récupérer les conversations d'un utilisateur ou invité
  Future<List<Map<String, dynamic>>> getConversations(String userId) async {
    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/messages?user=$userId'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['conversations'] ?? []);
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Get conversations error: $e');
      return [];
    }
  }

  /// Marquer les messages comme lus dans MySQL
  Future<bool> markAsRead({required String conversationId, required String userId}) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/messages'),
        headers: _headers,
        body: jsonEncode({
          'conversationId': conversationId,
          'userId': userId,
        }),
      ).timeout(const Duration(seconds: 10));

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Mark as read error: $e');
      return false;
    }
  }

  /// Créer une notification dans MySQL
  Future<bool> createNotification({
    required String userId,
    required String title,
    required String body,
    String type = 'general',
    String? targetId,
    Map<String, dynamic>? data,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse('$_baseUrl/notifications'),
        headers: _headers,
        body: jsonEncode({
          'userId': userId,
          'title': title,
          'body': body,
          'type': type,
          'targetId': targetId,
          'data': data,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        if (kDebugMode) print('[MessageApi] Notification created in MySQL for $userId');
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Notification error: $e');
      return false;
    }
  }

  /// Récupérer les notifications d'un utilisateur
  Future<Map<String, dynamic>> getNotifications(String userId, {bool unreadOnly = false}) async {
    try {
      final url = unreadOnly
          ? '$_baseUrl/notifications?user=$userId&unread=1'
          : '$_baseUrl/notifications?user=$userId';
      final resp = await http.get(Uri.parse(url), headers: _headers)
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) print('[MessageApi] Get notifications error: $e');
    }
    return {'success': false, 'notifications': [], 'unreadCount': 0};
  }
}
