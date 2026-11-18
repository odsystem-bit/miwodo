import 'dart:io';

import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class StorageService {
  StorageService._();

  static final StorageService instance = StorageService._();

  Future<String> uploadPhoto(String uid, File file) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'prestataires/$uid/$timestamp.jpg';

      final url = await SupabaseService.uploadPhoto(
        bucket: 'miwodo-photos',
        path: path,
        file: file,
      );

      if (kDebugMode) print('[StorageService] Uploaded: $path');
      return url;
    } catch (e) {
      if (kDebugMode) print('[StorageService] uploadPhoto error: $e');
      rethrow;
    }
  }

  Future<void> deletePhoto(String url) async {
    try {
      // Extraire le path de l'URL (format: https://domain/uploads/path)
      final uri = Uri.parse(url);
      final path = uri.path.replaceFirst('/uploads/', '');
      if (path.isNotEmpty && path != uri.path) {
        await SupabaseService.deletePhoto(bucket: 'miwodo-photos', path: path);
        if (kDebugMode) print('[StorageService] Deleted: $path');
      }
    } catch (e) {
      if (kDebugMode) print('[StorageService] deletePhoto error: $e');
      rethrow;
    }
  }
}
