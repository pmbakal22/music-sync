import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/spotify_track.dart';
import '../services/spotify_service.dart';
import '../services/local_music_service.dart';

/// Modal bottom sheet providing a real-time search interface for Spotify tracks
/// AND local MP3 audio files from phone storage.
class SearchBottomSheet extends StatefulWidget {
  final Function(SpotifyTrack track) onTrackSelected;

  const SearchBottomSheet({
    super.key,
    required this.onTrackSelected,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  List<SpotifyTrack> _spotifyResults = [];
  List<SpotifyTrack> _localTracks = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounceTimer;

  // Demo fallback tracks for testing
  final List<SpotifyTrack> _demoTracks = [
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _spotifyResults = _demoTracks;
    _scanLocalAudio();
  }

  Future<void> _scanLocalAudio() async {
    final tracks = await LocalMusicService.instance.scanLocalAudioFiles();
    if (mounted) {
      setState(() {
        _localTracks = tracks;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _spotifyResults = _demoTracks;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await SpotifyService.instance.searchTracks(query);
      setState(() {
        _spotifyResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _saveTokenAndSearch() {
    final token = _tokenController.text.trim();
    if (token.isNotEmpty) {
      SpotifyService.instance.setAccessToken(token);
      _performSearch(_searchController.text);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header Title & Tab Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.spotifyGreen,
                ),
                labelColor: Colors.black,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(text: '🎵 Spotify Web API'),
                  Tab(text: '📁 Local MP3 Audio'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: Spotify Search
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        onChanged: _onSearchChanged,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: 'Search Spotify catalog (artist, song)...',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.send_rounded, color: AppTheme.spotifyGreen),
                            onPressed: () => _performSearch(_searchController.text),
                          ),
                          filled: true,
                          fillColor: AppTheme.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(fontSize: 11, color: Colors.white),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _tokenController,
                                      style: const TextStyle(fontSize: 11, color: Colors.white),
                                      decoration: const InputDecoration(
                                        hintText: 'Paste Web API Token to bypass',
                                        hintStyle: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _saveTokenAndSearch,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.spotifyGreen,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    ),
                                    child: const Text('Use Token', style: TextStyle(fontSize: 11, color: Colors.black)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: AppTheme.spotifyGreen))
                          : _buildTrackListView(_spotifyResults),
                    ),
                  ],
                ),

                // TAB 2: Local MP3 Audio Scanner
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Phone Storage Music Files',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _scanLocalAudio,
                            icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.accentNeon),
                            label: const Text('Scan Storage', style: TextStyle(fontSize: 12, color: AppTheme.accentNeon)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.accentNeon),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: _buildTrackListView(_localTracks),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackListView(List<SpotifyTrack> tracks) {
    if (tracks.isEmpty) {
      return const Center(
        child: Text(
          'No audio tracks found.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      itemCount: tracks.length,
      separatorBuilder: (context, index) => const Divider(
        color: AppTheme.surfaceLight,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isLocal = track.uri.startsWith('local:');

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppTheme.surfaceLight,
            ),
            child: track.albumArtUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      track.albumArtUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        isLocal ? Icons.sd_card_rounded : Icons.music_note_rounded,
                        color: isLocal ? AppTheme.accentNeon : AppTheme.spotifyGreen,
                      ),
                    ),
                  )
                : Icon(
                    isLocal ? Icons.sd_storage_rounded : Icons.music_note_rounded,
                    color: isLocal ? AppTheme.accentNeon : AppTheme.spotifyGreen,
                  ),
          ),
          title: Text(
            track.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            '${track.artist} • ${track.albumName}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isLocal ? AppTheme.accentNeon : AppTheme.spotifyGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.black,
              size: 18,
            ),
          ),
          onTap: () {
            widget.onTrackSelected(track);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}
