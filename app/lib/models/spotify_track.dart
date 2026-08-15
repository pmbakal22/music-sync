/// Model representing a Spotify Track item returned from the Spotify Web API.
class SpotifyTrack {
  final String id;
  final String name;
  final String artist;
  final String albumName;
  final String albumArtUrl;
  final String uri;
  final int durationMs;

  SpotifyTrack({
    required this.id,
    required this.name,
    required this.artist,
    required this.albumName,
    required this.albumArtUrl,
    required this.uri,
    required this.durationMs,
  });

  factory SpotifyTrack.fromJson(Map<String, dynamic> json) {
    final artistsList = json['artists'] as List?;
    final artistName = (artistsList != null && artistsList.isNotEmpty)
        ? (artistsList.map((a) => a['name']).join(', '))
        : 'Unknown Artist';

    final album = json['album'] as Map<String, dynamic>?;
    final albumName = album?['name']?.toString() ?? '';
    final images = album?['images'] as List?;

    String artUrl = '';
    if (images != null && images.isNotEmpty) {
      // Pick medium or first available image
      artUrl = images.length > 1
          ? (images[1]['url']?.toString() ?? images[0]['url']?.toString() ?? '')
          : (images[0]['url']?.toString() ?? '');
    }

    return SpotifyTrack(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Untitled',
      artist: artistName,
      albumName: albumName,
      albumArtUrl: artUrl,
      uri: json['uri']?.toString() ?? '',
      durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'albumName': albumName,
      'albumArtUrl': albumArtUrl,
      'uri': uri,
      'durationMs': durationMs,
    };
  }
}
