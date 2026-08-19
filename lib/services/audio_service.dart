// services/audio_service.dart
// Service de lecture audio pour la messagerie

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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
