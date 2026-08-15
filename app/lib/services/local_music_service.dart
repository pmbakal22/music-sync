import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/spotify_track.dart';

/// Service for scanning and managing local MP3/Audio files from phone storage.
class LocalMusicService {
  LocalMusicService._();
  static final LocalMusicService instance = LocalMusicService._();

  List<SpotifyTrack> _localTracks = [];
  List<SpotifyTrack> get localTracks => List.unmodifiable(_localTracks);

  /// Request storage/audio permission on Android.
  Future<bool> requestStoragePermission() async {
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      PermissionStatus status = await Permission.audio.request();
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }
      return status.isGranted;
    }
    return true;
  }

  /// Scan common phone directories for MP3/Audio files.
  Future<List<SpotifyTrack>> scanLocalAudioFiles() async {
    if (kIsWeb) return _getDemoLocalTracks();

    final isGranted = await requestStoragePermission();
    if (!isGranted) {
      debugPrint('⚠️ Storage permission denied for local audio scan.');
      return _getDemoLocalTracks();
    }

    final List<SpotifyTrack> foundTracks = [];

    // Common Android Music Directories
    final List<String> searchPaths = [
      '/storage/emulated/0/Music',
      '/storage/emulated/0/Download',
      '/sdcard/Music',
      '/sdcard/Download',
    ];

    int idCounter = 1000;

    for (final path in searchPaths) {
      final dir = Directory(path);
      if (await dir.exists()) {
        try {
          final List<FileSystemEntity> files = dir.listSync(recursive: true);
          for (final entity in files) {
            if (entity is File) {
              final fileName = entity.path.split('/').last.split('\\').last;
              final extension = fileName.split('.').last.toLowerCase();

              if (extension == 'mp3' || extension == 'm4a' || extension == 'wav' || extension == 'flac') {
                final title = fileName.replaceAll('.$extension', '').replaceAll('_', ' ');
                final uri = 'local:${entity.path}';

                foundTracks.add(
                  SpotifyTrack(
                    id: 'local_${idCounter++}',
                    name: title,
                    artist: 'Local Device File',
                    albumName: 'Phone Storage ($path)',
                    albumArtUrl: '',
                    uri: uri,
                    durationMs: 180000, // Estimated default 3 min
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Error scanning dir $path: $e');
        }
      }
    }

    _localTracks = foundTracks.isEmpty ? _getDemoLocalTracks() : foundTracks;
    debugPrint('🎵 Local Audio Scan complete: Found ${_localTracks.length} files.');
    return _localTracks;
  }

  /// Demo fallback local tracks if storage is empty or denied
  List<SpotifyTrack> _getDemoLocalTracks() {
    return [
      SpotifyTrack(
        id: 'local_demo_1',
        name: 'My Local Downloaded Track 1',
        artist: 'Local Phone Storage',
        albumName: 'Downloads Folder',
        albumArtUrl: '',
        uri: 'local:demo_track_1.mp3',
        durationMs: 210000,
      ),
      SpotifyTrack(
        id: 'local_demo_2',
        name: 'My Local Downloaded Track 2',
        artist: 'Local Phone Storage',
        albumName: 'Music Folder',
        albumArtUrl: '',
        uri: 'local:demo_track_2.mp3',
        durationMs: 195000,
      ),
    ];
  }
}
