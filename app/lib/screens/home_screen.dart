import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/spotify_service.dart';
import '../services/socket_service.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSpotifyConnected = false;
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    // Connect to local Socket.IO server on port 3000
    SocketService.instance.connect(serverUrl: 'http://localhost:3000');
  }

  Future<void> _loginWithSpotify() async {
    setState(() => _isConnecting = true);

    final success = await SpotifyService.instance.connectToSpotify();

    setState(() {
      _isSpotifyConnected = success;
      _isConnecting = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: success ? AppTheme.spotifyGreen : Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(success
                ? 'Connected to Spotify!'
                : 'Failed to connect. Is Spotify app installed?'),
          ],
        ),
        backgroundColor: AppTheme.surfaceLight,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createRoom() {
    final random = Random();
    final roomCode = '${random.nextInt(9000) + 1000}'; // 4-digit code
    SocketService.instance.createRoom();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          roomCode: roomCode,
          isHost: true,
        ),
      ),
    );
  }

  void _joinRoom() {
    if (_formKey.currentState!.validate()) {
      final roomCode = _roomCodeController.text.trim();
      SocketService.instance.joinRoom(roomCode);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            roomCode: roomCode,
            isHost: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.spotifyGreen.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.spotifyGreen.withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentNeon.withOpacity(0.12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentNeon.withOpacity(0.12),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo & Header
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.surfaceLight,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.spotifyGreen.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                )
                              ],
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              size: 56,
                              color: AppTheme.spotifyGreen,
                            ),
                          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Music Sync',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms).moveY(begin: 15, end: 0),
                        const SizedBox(height: 6),
                        Text(
                          'Universal Remote Playback Synchronizer',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 15,
                              ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 36),

                        // Login with Spotify Button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: _isSpotifyConnected
                                ? AppTheme.surfaceLight
                                : const Color(0xFF191414),
                            border: Border.all(
                              color: _isSpotifyConnected
                                  ? AppTheme.spotifyGreen
                                  : const Color(0xFF282828),
                              width: 1.5,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _isConnecting
                                ? null
                                : (_isSpotifyConnected ? null : _loginWithSpotify),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              disabledBackgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isConnecting
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.spotifyGreen,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Connecting to Spotify...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isSpotifyConnected
                                            ? Icons.check_circle_rounded
                                            : Icons.music_note_rounded,
                                        color: AppTheme.spotifyGreen,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        _isSpotifyConnected
                                            ? 'Spotify Connected ✓'
                                            : 'Login with Spotify',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: _isSpotifyConnected
                                              ? AppTheme.spotifyGreen
                                              : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ).animate().fadeIn(delay: 350.ms).moveY(begin: 15, end: 0),

                        const SizedBox(height: 28),

                        // Create Room Card Button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [AppTheme.spotifyGreen, Color(0xFF169C44)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.spotifyGreen.withOpacity(0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _createRoom,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'Create Sync Room',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 400.ms).moveY(begin: 20, end: 0),

                        const SizedBox(height: 28),

                        // OR Divider
                        Row(
                          children: const [
                            Expanded(child: Divider(color: AppTheme.surfaceLight, thickness: 1.5)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Text(
                                'OR JOIN ROOM',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: AppTheme.surfaceLight, thickness: 1.5)),
                          ],
                        ).animate().fadeIn(delay: 500.ms),

                        const SizedBox(height: 28),

                        // Join Room Input Box
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.surfaceLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _roomCodeController,
                                keyboardType: TextInputType.number,
                                maxLength: 4,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: 'Enter 4-Digit Room Code (e.g. 1234)',
                                  hintStyle: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.normal,
                                    letterSpacing: 0,
                                    color: AppTheme.textSecondary,
                                  ),
                                  prefixIcon: const Icon(Icons.meeting_room_outlined, color: AppTheme.accentNeon),
                                  filled: true,
                                  fillColor: AppTheme.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a 4-digit room code';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton(
                                onPressed: _joinRoom,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: AppTheme.accentNeon, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.login_rounded, color: AppTheme.accentNeon),
                                    SizedBox(width: 8),
                                    Text(
                                      'Join Room',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.accentNeon,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 600.ms).moveY(begin: 25, end: 0),

                        const SizedBox(height: 32),

                        // System Constraint Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.info_outline_rounded, color: AppTheme.textSecondary, size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Universal Remote Mode: Socket.IO Server @ localhost:3000 • Buffer Strategy 1.5s Active.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 700.ms),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
