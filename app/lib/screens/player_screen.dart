import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/spotify_track.dart';
import '../services/spotify_service.dart';
import '../services/socket_service.dart';
import '../services/clock_sync_service.dart';
import '../widgets/search_bottom_sheet.dart';

class PlayerScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;

  const PlayerScreen({
    super.key,
    required this.roomCode,
    required this.isHost,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _isPlaying = false;
  double _currentPosition = 0.0;
  int _currentTrackIndex = 0;

  // Active Playlist (Demo tracks + dynamic search additions)
  final List<SpotifyTrack> _playlist = [
    SpotifyTrack(
      id: '1',
      name: 'Bohemian Rhapsody',
      artist: 'Queen',
      albumName: 'A Night at the Opera',
      albumArtUrl: 'https://i.scdn.co/image/ab67616d0000b273e319baafd16e84f0408af2a0',
      uri: 'spotify:track:4cOdK2wGLETKBW3PvgPWqT',
      durationMs: 354000,
    ),
    SpotifyTrack(
      id: '2',
      name: 'Blinding Lights',
      artist: 'The Weeknd',
      albumName: 'After Hours',
      albumArtUrl: 'https://i.scdn.co/image/ab67616d0000b2738863bc11d2aa12b54f5a86d7',
      uri: 'spotify:track:0VjDiY0FVCwcPOaGDPfStyl',
      durationMs: 200000,
    ),
    SpotifyTrack(
      id: '3',
      name: 'Shape of You',
      artist: 'Ed Sheeran',
      albumName: '÷ (Divide)',
      albumArtUrl: 'https://i.scdn.co/image/ab67616d0000b273ba5db46f4b838ef6027e6f96',
      uri: 'spotify:track:7qiZf24HYVision3B8Qn26',
      durationMs: 233000,
    ),
    SpotifyTrack(
      id: '4',
      name: 'Starboy',
      artist: 'The Weeknd, Daft Punk',
      albumName: 'Starboy',
      albumArtUrl: 'https://i.scdn.co/image/ab67616d0000b2734718e241261b0200593b4238',
      uri: 'spotify:track:7MXVkk9YMctZqd1Srtv4MB',
      durationMs: 230000,
    ),
  ];

  // Currently Active Track Metadata
  late String _currentTrackUri;
  late String _currentTrackTitle;
  late String _currentArtist;
  late String _currentAlbumArtUrl;
  late double _totalDuration;

  late String _activeRoomCode;

  // Stream Subscriptions
  StreamSubscription<ExecutePlayPayload>? _executePlaySub;
  StreamSubscription<Map<String, dynamic>>? _executePauseSub;
  StreamSubscription<String>? _roomCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _roomJoinedSub;
  StreamSubscription<String>? _errorSub;

  @override
  void initState() {
    super.initState();
    _activeRoomCode = widget.roomCode;
    _updateActiveTrackUI(_playlist[0]);

    // Force NTP clock sync to ensure high precision time alignment
    ClockSyncService.instance.syncClock();

    _setupSocketListeners();
  }

  void _updateActiveTrackUI(SpotifyTrack track) {
    setState(() {
      _currentTrackUri = track.uri;
      _currentTrackTitle = track.name;
      _currentArtist = '${track.artist} • ${track.albumName}';
      _currentAlbumArtUrl = track.albumArtUrl;
      _totalDuration = track.durationMs > 0 ? track.durationMs / 1000 : 200.0;
      _currentPosition = 0.0;
    });
  }

  void _setupSocketListeners() {
    final socketService = SocketService.instance;

    _roomCreatedSub = socketService.onRoomCreated.listen((code) {
      if (mounted) {
        setState(() {
          _activeRoomCode = code;
        });
      }
      debugPrint('✅ Room created on server with code: $code');
    });

    _roomJoinedSub = socketService.onRoomJoined.listen((data) {
      debugPrint('✅ Joined room on server: $data');
    });

    // ── BUFFER STRATEGY LISTENERS (NTP CLOCK ALIGNED) ─────────────────────────

    _executePlaySub = socketService.onExecutePlay.listen((payload) async {
      final currentServerTime = ClockSyncService.instance.currentServerTimeMs;
      final delayMs = payload.targetTimestamp - currentServerTime;

      debugPrint('⏱️ =================================================');
      debugPrint('⏱️ NTP BUFFER EXECUTE_PLAY RECEIVED');
      debugPrint('   Room Code           : ${payload.roomCode}');
      debugPrint('   Spotify Track       : ${payload.spotifyUri}');
      debugPrint('   Target Timestamp    : ${payload.targetTimestamp}');
      debugPrint('   Current Server Clock: $currentServerTime');
      debugPrint('   Calculated Delay    : ${delayMs}ms');
      debugPrint('⏱️ =================================================');

      // Update track metadata UI if track matches any item in playlist or received payload
      final matchingTrackIndex = _playlist.indexWhere((t) => t.uri == payload.spotifyUri);
      if (matchingTrackIndex != -1) {
        _currentTrackIndex = matchingTrackIndex;
        _updateActiveTrackUI(_playlist[matchingTrackIndex]);
      }

      if (delayMs > 0) {
        debugPrint('⏳ Precision delay for ${delayMs}ms...');
        await Future.delayed(Duration(milliseconds: delayMs));
        await SpotifyService.instance.play(payload.spotifyUri);
      } else {
        debugPrint('⚠️ Late frame detected (${delayMs.abs()}ms behind). Seeking & playing.');
        final seekPosition = payload.positionMs + delayMs.abs();
        await SpotifyService.instance.play(payload.spotifyUri);
        await SpotifyService.instance.seekTo(seekPosition);
      }

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
        _showBufferExecutionSnack(
          'Playing track via Spotify SDK (NTP Synced)',
          payload.targetTimestamp,
          delayMs > 0 ? delayMs : 0,
        );
      }
    });

    _executePauseSub = socketService.onExecutePause.listen((data) async {
      final targetTimestamp = (data['targetTimestamp'] as num?)?.toInt() ?? 0;
      final currentServerTime = ClockSyncService.instance.currentServerTimeMs;
      final delayMs = targetTimestamp - currentServerTime;

      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }

      await SpotifyService.instance.pause();

      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
        _showBufferExecutionSnack('Paused track via Spotify SDK', targetTimestamp, delayMs > 0 ? delayMs : 0);
      }
    });

    _errorSub = socketService.onError.listen((msg) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server Error: $msg'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    });
  }

  /// Open Search Modal Sheet
  void _openSearchModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SearchBottomSheet(
        onTrackSelected: _onTrackSelectedFromSearch,
      ),
    );
  }

  /// Called when Host selects a track from search results.
  void _onTrackSelectedFromSearch(SpotifyTrack track) {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Room Host can select tracks to play.'),
          backgroundColor: AppTheme.surfaceLight,
        ),
      );
      return;
    }

    // Add track to playlist if not already present
    final existingIndex = _playlist.indexWhere((t) => t.uri == track.uri);
    if (existingIndex == -1) {
      _playlist.add(track);
      _currentTrackIndex = _playlist.length - 1;
    } else {
      _currentTrackIndex = existingIndex;
    }

    _updateActiveTrackUI(track);

    // Broadcast selected track URI with 1.5s NTP Buffer Strategy
    _sendBufferPlayCommand(track.uri);
  }

  /// Calculate future 1.5s timestamp and send play_command to Socket.IO server.
  void _sendBufferPlayCommand(String spotifyUri) {
    final serverTime = ClockSyncService.instance.currentServerTimeMs;
    final targetTimestamp = serverTime + 1500;

    debugPrint('🚀 BROADCASTING SELECTED TRACK WITH 1.5s NTP BUFFER:');
    debugPrint('   Selected URI          : $spotifyUri');
    debugPrint('   Current Server Time   : $serverTime');
    debugPrint('   Target NTP Timestamp  : $targetTimestamp (+1500ms)');

    SocketService.instance.sendPlayCommand(
      roomCode: _activeRoomCode,
      spotifyUri: spotifyUri,
      targetTimestamp: targetTimestamp,
      positionMs: 0,
    );

    _showBroadcastSnack(targetTimestamp, _currentTrackTitle);
  }

  Future<void> _togglePlayPause() async {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Room Host can initiate playback commands.'),
          backgroundColor: AppTheme.surfaceLight,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isPlaying) {
      final serverTime = ClockSyncService.instance.currentServerTimeMs;
      final targetTimestamp = serverTime + 1500;
      SocketService.instance.sendPauseCommand(
        roomCode: _activeRoomCode,
        targetTimestamp: targetTimestamp,
      );
    } else {
      _sendBufferPlayCommand(_currentTrackUri);
    }
  }

  void _showBroadcastSnack(int targetTimestamp, String trackName) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.sensors_rounded, color: AppTheme.accentNeon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Broadcasted "$trackName"! Target: $targetTimestamp (+1500ms)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showBufferExecutionSnack(String action, int targetTimestamp, int waitedMs) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.spotifyGreen, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$action (Waited ${waitedMs}ms for Target $targetTimestamp)',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _skipTrack() {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Room Host can skip tracks.'),
          backgroundColor: AppTheme.surfaceLight,
        ),
      );
      return;
    }
    if (_playlist.isEmpty) return;
    _currentTrackIndex = (_currentTrackIndex + 1) % _playlist.length;
    final nextTrack = _playlist[_currentTrackIndex];
    _onTrackSelectedFromSearch(nextTrack);
  }

  void _skipPrevious() {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the Room Host can skip tracks.'),
          backgroundColor: AppTheme.surfaceLight,
        ),
      );
      return;
    }
    if (_playlist.isEmpty) return;
    _currentTrackIndex = (_currentTrackIndex - 1 + _playlist.length) % _playlist.length;
    final prevTrack = _playlist[_currentTrackIndex];
    _onTrackSelectedFromSearch(prevTrack);
  }

  String _formatDuration(double seconds) {
    final mins = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _executePlaySub?.cancel();
    _executePauseSub?.cancel();
    _roomCreatedSub?.cancel();
    _roomJoinedSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSpotifyConnected = SpotifyService.instance.isConnected;
    final isSocketConnected = SocketService.instance.isConnected;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'ROOM $_activeRoomCode',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppTheme.spotifyGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.isHost ? 'ROOM HOST (CONTROLLER)' : 'SYNC MEMBER (LISTENER)',
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.isHost ? AppTheme.spotifyGreen : AppTheme.accentNeon,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, color: AppTheme.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Room code $_activeRoomCode copied to clipboard!')),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Ambient Glow
          Positioned(
            top: 60,
            left: MediaQuery.of(context).size.width * 0.15,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.spotifyGreen.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.spotifyGreen.withOpacity(0.2),
                    blurRadius: 120,
                    spreadRadius: 60,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
              child: Column(
                children: [
                  // Connection Telemetry Badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSocketConnected ? AppTheme.accentNeon : Colors.redAccent,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cell_tower_rounded,
                              color: isSocketConnected ? AppTheme.accentNeon : Colors.redAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSocketConnected ? 'Server Connected' : 'Server Disconnected',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSocketConnected ? AppTheme.accentNeon : Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSpotifyConnected
                                ? AppTheme.spotifyGreen.withOpacity(0.5)
                                : Colors.redAccent.withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSpotifyConnected
                                  ? Icons.bluetooth_connected_rounded
                                  : Icons.bluetooth_disabled_rounded,
                              color: isSpotifyConnected ? AppTheme.spotifyGreen : Colors.redAccent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isSpotifyConnected ? 'Spotify SDK' : 'Not Connected',
                              style: TextStyle(
                                fontSize: 11,
                                color: isSpotifyConnected ? AppTheme.spotifyGreen : Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Search Spotify Tracks Button ──
                  if (widget.isHost)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.spotifyGreen.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.spotifyGreen.withOpacity(0.15),
                            blurRadius: 10,
                          )
                        ],
                      ),
                      child: InkWell(
                        onTap: _openSearchModal,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: const [
                              Icon(Icons.search_rounded, color: AppTheme.spotifyGreen, size: 22),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Search & Select Spotify Track...',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(Icons.tune_rounded, color: AppTheme.spotifyGreen, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn().moveY(begin: 10, end: 0),

                  const Spacer(),

                  // Album Art Display (Network Image or Icon)
                  Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E1C4E), Color(0xFF161032), Color(0xFF0F0F1A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.spotifyGreen.withOpacity(_isPlaying ? 0.35 : 0.15),
                            blurRadius: 30,
                            spreadRadius: _isPlaying ? 5 : 1,
                          )
                        ],
                        border: Border.all(
                          color: _isPlaying ? AppTheme.spotifyGreen : AppTheme.surfaceLight,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: _currentAlbumArtUrl.isNotEmpty
                            ? Stack(
                                children: [
                                  Image.network(
                                    _currentAlbumArtUrl,
                                    width: 240,
                                    height: 240,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildAlbumFallbackIcon(),
                                  ),
                                  Positioned(
                                    bottom: 12,
                                    left: 12,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isPlaying ? Icons.graphic_eq_rounded : Icons.pause_circle_outline,
                                            color: AppTheme.spotifyGreen,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _isPlaying ? 'BUFFER SYNCING' : 'PAUSED',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.spotifyGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : _buildAlbumFallbackIcon(),
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOut),

                  const Spacer(),

                  // Track Metadata Title & Artist
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentTrackTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Progress Scrubber Bar
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: AppTheme.spotifyGreen,
                          inactiveTrackColor: AppTheme.surfaceLight,
                          thumbColor: Colors.white,
                        ),
                        child: Slider(
                          value: _currentPosition.clamp(0.0, _totalDuration),
                          min: 0.0,
                          max: _totalDuration,
                          onChanged: (value) {
                            setState(() {
                              _currentPosition = value;
                            });
                          },
                          onChangeEnd: (value) async {
                            if (widget.isHost) {
                              final serverTime = ClockSyncService.instance.currentServerTimeMs;
                              final targetTimestamp = serverTime + 1500;
                              SocketService.instance.sendSeekCommand(
                                roomCode: _activeRoomCode,
                                positionMs: (value * 1000).toInt(),
                                targetTimestamp: targetTimestamp,
                              );
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(_currentPosition),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            Text(
                              _formatDuration(_totalDuration),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Playback Remote Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.shuffle_rounded, color: AppTheme.textSecondary),
                        onPressed: () {},
                      ),
                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_previous_rounded, color: AppTheme.textPrimary),
                        onPressed: _skipPrevious,
                      ),

                      // Play/Pause Button
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.spotifyGreen,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.spotifyGreen.withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 40,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      IconButton(
                        iconSize: 40,
                        icon: const Icon(Icons.skip_next_rounded, color: AppTheme.textPrimary),
                        onPressed: _skipTrack,
                      ),
                      IconButton(
                        iconSize: 32,
                        icon: const Icon(Icons.repeat_rounded, color: AppTheme.textSecondary),
                        onPressed: () {},
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Execution Timestamp Buffer Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.timer_outlined, color: AppTheme.accentNeon, size: 16),
                        SizedBox(width: 8),
                        Text(
                          '1.5s Execution Buffer Strategy Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentNeon,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumFallbackIcon() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.music_note_rounded,
          size: 80,
          color: _isPlaying ? AppTheme.spotifyGreen : AppTheme.textSecondary,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.background.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isPlaying ? Icons.graphic_eq_rounded : Icons.pause_circle_outline,
                color: AppTheme.spotifyGreen,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _isPlaying ? 'BUFFER SYNC PLAYBACK' : 'PAUSED',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.spotifyGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
