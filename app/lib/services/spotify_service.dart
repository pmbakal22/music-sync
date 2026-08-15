import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:spotify_sdk/spotify_sdk.dart';
import '../config/spotify_config.dart';
import '../models/spotify_track.dart';

/// Service wrapping Spotify App Remote SDK and Spotify Web API queries.
class SpotifyService {
  SpotifyService._();
  static final SpotifyService instance = SpotifyService._();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _accessToken;
  String? get accessToken => _accessToken;

  /// Set token manually (e.g. for testing / Web fallback).
  void setAccessToken(String token) {
    _accessToken = token;
    _isConnected = true;
    debugPrint('🔑 Access token set manually: ${token.substring(0, token.length > 10 ? 10 : token.length)}...');
  }

  /// Connect to Spotify App Remote SDK & Web OAuth.
  Future<bool> connectToSpotify() async {
    try {
      debugPrint('🎵 Step 1: Requesting Spotify OAuth Access Token (Client ID: ${SpotifyConfig.clientId})...');

      // Request Spotify Access Token via SDK OAuth prompt
      final token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.redirectUrl,
        scope: SpotifyConfig.scope,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          debugPrint('⏱️ Spotify access token request timed out');
          return '';
        },
      );

      if (token.isNotEmpty) {
        _accessToken = token;
        _isConnected = true;
        debugPrint('🔑 Access Token retrieved successfully!');
      }

      debugPrint('🎵 Step 2: Connecting to Spotify App Remote service...');
      final remoteConnected = await SpotifySdk.connectToSpotifyRemote(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.redirectUrl,
        scope: SpotifyConfig.scope,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⏱️ Spotify App Remote connection timed out');
          return false;
        },
      );

      _isConnected = remoteConnected || (_accessToken != null && _accessToken!.isNotEmpty);
      debugPrint('🎵 Final Spotify connection status: $_isConnected');
      return _isConnected;
    } catch (e) {
      debugPrint('❌ Spotify connection error: $e');
      _isConnected = (_accessToken != null && _accessToken!.isNotEmpty);
      return _isConnected;
    }
  }

  /// Retrieve Spotify Web API Access Token.
  Future<String?> fetchAccessToken() async {
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      return _accessToken;
    }
    try {
      final token = await SpotifySdk.getAccessToken(
        clientId: SpotifyConfig.clientId,
        redirectUrl: SpotifyConfig.redirectUrl,
        scope: SpotifyConfig.scope,
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          debugPrint('⏱️ Spotify access token fetch timed out');
          return '';
        },
      );

      if (token.isNotEmpty) {
        _accessToken = token;
        _isConnected = true;
        debugPrint('🔑 Spotify access token fetched successfully');
      }
      return _accessToken;
    } catch (e) {
      debugPrint('❌ Error fetching Spotify access token: $e');
      return null;
    }
  }

  /// Search Spotify Web API for tracks matching [query].
  Future<List<SpotifyTrack>> searchTracks(String query) async {
    if (query.trim().isEmpty) return [];

    // Ensure we have an access token
    if (_accessToken == null || _accessToken!.isEmpty) {
      await fetchAccessToken();
    }

    if (_accessToken == null || _accessToken!.isEmpty) {
      debugPrint('⚠️ Cannot search Spotify Web API: Access token missing.');
      throw Exception('Spotify Access Token missing. Please log in with Spotify.');
    }

    final url = Uri.https('api.spotify.com', '/v1/search', {
      'q': query.trim(),
      'type': 'track',
      'limit': '20',
    });

    debugPrint('🔍 Searching Spotify Web API: $url');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tracksJson = data['tracks']?['items'] as List?;
      if (tracksJson != null) {
        return tracksJson
            .map((item) => SpotifyTrack.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } else if (response.statusCode == 401) {
      debugPrint('❌ Spotify Search HTTP 401: Unauthorized (token expired)');
      _accessToken = null;
      throw Exception('Spotify access token expired. Please re-authenticate.');
    } else {
      debugPrint('❌ Spotify Search HTTP ${response.statusCode}: ${response.body}');
      throw Exception('Spotify API error (${response.statusCode}): ${response.reasonPhrase}');
    }
  }

  /// Play track by URI using Spotify App Remote.
  Future<void> play(String spotifyUri) async {
    try {
      await SpotifySdk.play(spotifyUri: spotifyUri);
      debugPrint('▶️ Playing: $spotifyUri');
    } catch (e) {
      debugPrint('❌ Spotify play error: $e');
    }
  }

  /// Pause playback.
  Future<void> pause() async {
    try {
      await SpotifySdk.pause();
      debugPrint('⏸️ Paused playback');
    } catch (e) {
      debugPrint('❌ Spotify pause error: $e');
    }
  }

  /// Resume playback.
  Future<void> resume() async {
    try {
      await SpotifySdk.resume();
      debugPrint('▶️ Resumed playback');
    } catch (e) {
      debugPrint('❌ Spotify resume error: $e');
    }
  }

  /// Seek to position in milliseconds.
  Future<void> seekTo(int positionMs) async {
    try {
      await SpotifySdk.seekTo(positionedMilliseconds: positionMs);
      debugPrint('⏩ Seeked to ${positionMs}ms');
    } catch (e) {
      debugPrint('❌ Spotify seek error: $e');
    }
  }

  /// Skip next.
  Future<void> skipNext() async {
    try {
      await SpotifySdk.skipNext();
      debugPrint('⏭️ Skipped next');
    } catch (e) {
      debugPrint('❌ Spotify skipNext error: $e');
    }
  }

  /// Skip previous.
  Future<void> skipPrevious() async {
    try {
      await SpotifySdk.skipPrevious();
      debugPrint('⏮️ Skipped previous');
    } catch (e) {
      debugPrint('❌ Spotify skipPrevious error: $e');
    }
  }

  /// Disconnect.
  Future<void> disconnect() async {
    try {
      await SpotifySdk.disconnect();
      _isConnected = false;
      _accessToken = null;
      debugPrint('🔌 Spotify disconnected');
    } catch (e) {
      debugPrint('❌ Spotify disconnect error: $e');
    }
  }
}
