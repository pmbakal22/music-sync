import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'spotify_service.dart';

/// Unified Audio Playback Manager.
/// Handles both Spotify App Remote playback (`spotify:track:...`)
/// AND local MP3 file playback (`local:...`) using `audioplayers`.
class AudioManager {
  AudioManager._();
  static final AudioManager instance = AudioManager._();

  final AudioPlayer _localAudioPlayer = AudioPlayer();
  bool _isLocalPlaying = false;
  String? _currentLocalUri;

  /// Play track by URI (dispatches to Spotify or local AudioPlayer).
  Future<void> play(String trackUri) async {
    if (trackUri.startsWith('local:')) {
      final filePath = trackUri.replaceFirst('local:', '');
      debugPrint('🎵 Playing Local Audio File via AudioPlayer: $filePath');

      // Pause Spotify if running
      await SpotifyService.instance.pause().catchError((_) {});

      try {
        if (filePath.startsWith('demo_track_')) {
          debugPrint('🎵 Demo local track trigger (simulated local play)');
          _isLocalPlaying = true;
          _currentLocalUri = trackUri;
          return;
        }

        final file = File(filePath);
        if (await file.exists()) {
          await _localAudioPlayer.stop();
          await _localAudioPlayer.play(DeviceFileSource(filePath));
          _isLocalPlaying = true;
          _currentLocalUri = trackUri;
          debugPrint('▶️ Local AudioPlayer playing: $filePath');
        } else {
          debugPrint('⚠️ Local audio file not found on device storage: $filePath');
        }
      } catch (e) {
        debugPrint('❌ Local AudioPlayer error: $e');
      }
    } else {
      // Pause local audio player if active
      if (_isLocalPlaying) {
        await _localAudioPlayer.pause();
        _isLocalPlaying = false;
      }
      // Play via Spotify SDK
      await SpotifyService.instance.play(trackUri);
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    if (_isLocalPlaying) {
      await _localAudioPlayer.pause();
      _isLocalPlaying = false;
    }
    await SpotifyService.instance.pause().catchError((_) {});
  }

  /// Resume playback.
  Future<void> resume() async {
    if (_currentLocalUri != null && _currentLocalUri!.startsWith('local:')) {
      await _localAudioPlayer.resume();
      _isLocalPlaying = true;
    } else {
      await SpotifyService.instance.resume().catchError((_) {});
    }
  }

  /// Seek to position in milliseconds.
  Future<void> seekTo(int positionMs) async {
    if (_isLocalPlaying) {
      await _localAudioPlayer.seek(Duration(milliseconds: positionMs));
    } else {
      await SpotifyService.instance.seekTo(positionMs).catchError((_) {});
    }
  }
}
