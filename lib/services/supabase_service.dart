// services/supabase_service.dart
// Migration: Supabase SDK → API PHP/HTTP pour le storage
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class SupabaseService {
  SupabaseService._();

  static final SupabaseService instance = SupabaseService._();

  static const String _baseUrl =
      String.fromEnvironment('PAYMENT_API_URL',
          defaultValue: 'https://bot.odsysteme.tech/api');
  static const String _apiKey =
      String.fromEnvironment('PAYMENT_API_KEY',
          defaultValue: 'aadc42b40f152ad0133c93e5e154a843fc61952072b35e80');

  static Future<void> initialize() async {
    // No-op: plus besoin d'initialiser Supabase SDK
    if (kDebugMode) print('[Storage] API PHP initialisée');
  }

  /// Upload une photo vers l'API PHP
  /// Retourne l'URL publique de l'image
  static Future<String> uploadPhoto({
    required String bucket,
    required String path,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload.php');
      final request = http.MultipartRequest('POST', uri)
        ..headers['X-Api-Key'] = _apiKey
        ..fields['path'] = path
        ..files.add(
          await http.MultipartFile.fromPath(
            'file',
            file.path,
            contentType: MediaType.parse(contentType),
          ),
        );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final resp = await http.Response.fromStream(streamedResponse);

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final url = data['url'] as String? ?? '';
        if (kDebugMode) print('[Storage] Upload OK: $url');
        if (url.isEmpty) {
          throw Exception('URL vide retournée par le serveur');
        }
        return url;
      } else {
        String errorMsg = 'Erreur upload (${resp.statusCode})';
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          errorMsg = data['error'] as String? ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e, st) {
      if (kDebugMode) print('[Storage] Upload FAILED: $e\n$st');
      throw Exception('Erreur upload: $e');
    }
  }

  /// Supprime une photo du storage
  static Future<void> deletePhoto({
    required String bucket,
    required String path,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/delete.php');
      final resp = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-Api-Key': _apiKey,
            },
            body: jsonEncode({'path': path}),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        String errorMsg = 'Erreur suppression (${resp.statusCode})';
        try {
          final data = jsonDecode(resp.body) as Map<String, dynamic>;
          errorMsg = data['error'] as String? ?? errorMsg;
        } catch (_) {}
        throw Exception(errorMsg);
      }

      if (kDebugMode) print('[Storage] Delete OK: $path');
    } catch (e) {
      if (kDebugMode) print('[Storage] Delete error: $e');
      throw Exception('Erreur suppression: $e');
    }
  }
}
