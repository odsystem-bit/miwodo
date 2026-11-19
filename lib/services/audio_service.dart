// services/audio_service.dart
// Service de lecture et d'enregistrement audio pour la messagerie MIWODO

import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service d'enregistrement vocal natif (MethodChannel Android MediaRecorder)
class AudioRecorderService {
  AudioRecorderService._();
  static final AudioRecorderService instance = AudioRecorderService._();

  static const MethodChannel _channel =
      MethodChannel('com.miwodo.miwodo/audio_recorder');

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Vérifie / demande la permission microphone
  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Démarre l'enregistrement vocal (.m4a AAC)
  Future<String?> startRecording() async {
    final granted = await requestPermission();
    if (!granted) {
      throw Exception('Permission microphone refusée');
    }
    final path = await _channel.invokeMethod<String>('startRecording');
    _isRecording = path != null && path.isNotEmpty;
    return path;
  }

  /// Arrête l'enregistrement et retourne le fichier et sa durée en secondes
  Future<({File file, int durationSeconds})?> stopRecording() async {
    if (!_isRecording) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('stopRecording');
      _isRecording = false;
      if (res == null) return null;
      final path = res['path']?.toString() ?? '';
      final duration = int.tryParse(res['duration']?.toString() ?? '1') ?? 1;
      if (path.isEmpty) return null;
      final file = File(path);
      if (!await file.exists()) return null;
      return (file: file, durationSeconds: duration);
    } catch (e) {
      _isRecording = false;
      if (kDebugMode) print('[AudioRecorder] stopRecording error: $e');
      return null;
    }
  }

  /// Annule l'enregistrement en cours et supprime le fichier temporaire
  Future<void> cancelRecording() async {
    try {
      await _channel.invokeMethod('cancelRecording');
    } catch (_) {}
    _isRecording = false;
  }
}

/// Service de lecture audio
class AudioPlayerService {
  AudioPlayerService._();
  static final AudioPlayerService instance = AudioPlayerService._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentUrl;
  PlayerState _state = PlayerState.stopped;

  PlayerState get state => _state;
  bool get isPlaying => _state == PlayerState.playing;
  String? get currentUrl => _currentUrl;

  /// Stream de l'état du lecteur
  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;

  /// Stream de la position actuelle
  Stream<Duration> get positionStream => _player.onPositionChanged;

  /// Stream de la durée totale
  Stream<Duration> get durationStream => _player.onDurationChanged;

  /// Initialiser les listeners
  void initialize() {
    _player.onPlayerStateChanged.listen((state) {
      _state = state;
    });

    _player.onPlayerComplete.listen((_) {
      _state = PlayerState.stopped;
      _currentUrl = null;
    });
  }

  /// Jouer un audio depuis une URL
  Future<void> play(String url) async {
    try {
      if (_currentUrl == url) {
        if (_state == PlayerState.playing) {
          await pause();
          return;
        } else if (_state == PlayerState.paused) {
          await resume();
          return;
        }
      }

      await stop();

      _currentUrl = url;
      await _player.play(UrlSource(url));
      _state = PlayerState.playing;

      if (kDebugMode) print('[AudioPlayer] Playing: $url');
    } catch (e) {
      if (kDebugMode) print('[AudioPlayer] Error playing: $e');
      _state = PlayerState.stopped;
    }
  }

  /// Jouer un fichier local
  Future<void> playFile(String path) async {
    try {
      await stop();
      _currentUrl = path;
      await _player.play(DeviceFileSource(path));
      _state = PlayerState.playing;
    } catch (e) {
      if (kDebugMode) print('[AudioPlayer] Error playing file: $e');
      _state = PlayerState.stopped;
    }
  }

  /// Mettre en pause
  Future<void> pause() async {
    await _player.pause();
    _state = PlayerState.paused;
  }

  /// Reprendre la lecture
  Future<void> resume() async {
    await _player.resume();
    _state = PlayerState.playing;
  }

  /// Arrêter la lecture
  Future<void> stop() async {
    await _player.stop();
    _state = PlayerState.stopped;
    _currentUrl = null;
  }

  /// Aller à une position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Libérer les ressources
  void dispose() {
    _player.dispose();
  }
}
