/// Spotify configuration constants for the Spotify Sync App.
/// 
/// Register your app at https://developer.spotify.com/dashboard
/// and replace these values with your own credentials.
class SpotifyConfig {
  /// Your Spotify Application Client ID
  static const String clientId = '499a6261c052413d96eb612e79ce65c2';

  /// The redirect URI registered in the Spotify Developer Dashboard.
  /// For Android, this must match the scheme in AndroidManifest.xml.
  /// For iOS, this must match the CFBundleURLSchemes in Info.plist.
  static const String redirectUrl = 'spotify-sdk://auth';

  /// Spotify API scopes required for App Remote playback control.
  static const String scope =
      'app-remote-control,'
      'user-modify-playback-state,'
      'user-read-playback-state,'
      'user-read-currently-playing,'
      'playlist-read-private,'
      'playlist-read-collaborative';
}
