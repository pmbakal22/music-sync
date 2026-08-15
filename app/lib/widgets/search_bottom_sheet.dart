import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/spotify_track.dart';
import '../services/spotify_service.dart';

/// Modal bottom sheet providing a real-time search interface for Spotify tracks.
class SearchBottomSheet extends StatefulWidget {
  final Function(SpotifyTrack track) onTrackSelected;

  const SearchBottomSheet({
    super.key,
    required this.onTrackSelected,
  });

  @override
  State<SearchBottomSheet> createState() => _SearchBottomSheetState();
}

class _SearchBottomSheetState extends State<SearchBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  List<SpotifyTrack> _searchResults = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Demo fallback tracks for testing when API token is unavailable
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
    _searchResults = _demoTracks;
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = _demoTracks;
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
        _searchResults = results;
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
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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

          // Header Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              children: const [
                Icon(Icons.search_rounded, color: AppTheme.spotifyGreen, size: 24),
                SizedBox(width: 10),
                Text(
                  'Search Spotify Tracks',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              onSubmitted: _performSearch,
              decoration: InputDecoration(
                hintText: 'Search title, artist, or album...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Error / Token Missing Banner
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: Container(
                padding: const EdgeInsets.all(12),
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
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
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
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _saveTokenAndSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.spotifyGreen,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('Use Token', style: TextStyle(fontSize: 11, color: Colors.black)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Results List / Loader
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.spotifyGreen),
                  )
                : _searchResults.isEmpty
                    ? const Center(
                        child: Text(
                          'No tracks found. Try another search term.',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                        itemCount: _searchResults.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: AppTheme.surfaceLight,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final track = _searchResults[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                            leading: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: AppTheme.surfaceLight,
                              ),
                              child: track.albumArtUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        track.albumArtUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.music_note_rounded,
                                          color: AppTheme.spotifyGreen,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.music_note_rounded,
                                      color: AppTheme.spotifyGreen,
                                    ),
                            ),
                            title: Text(
                              track.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              '${track.artist} • ${track.albumName}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppTheme.spotifyGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 20,
                              ),
                            ),
                            onTap: () {
                              widget.onTrackSelected(track);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
