import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Data class representing a synchronized play execution command.
class ExecutePlayPayload {
  final String roomCode;
  final String spotifyUri;
  final int positionMs;
  final int targetTimestamp;

  ExecutePlayPayload({
    required this.roomCode,
    required this.spotifyUri,
    required this.positionMs,
    required this.targetTimestamp,
  });

  factory ExecutePlayPayload.fromMap(Map<String, dynamic> map) {
    return ExecutePlayPayload(
      roomCode: map['roomCode']?.toString() ?? '',
      spotifyUri: map['spotifyUri']?.toString() ?? '',
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      targetTimestamp: (map['targetTimestamp'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Service managing the Socket.IO WebSocket connection to the Node.js server.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  String? get socketId => _socket?.id;

  // Event Streams / Callbacks
  final _roomCreatedController = StreamController<String>.broadcast();
  final _roomJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _executePlayController = StreamController<ExecutePlayPayload>.broadcast();
  final _executePauseController = StreamController<Map<String, dynamic>>.broadcast();
  final _executeSeekController = StreamController<Map<String, dynamic>>.broadcast();
  final _executeSkipController = StreamController<Map<String, dynamic>>.broadcast();
  final _ntpPongController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  Stream<String> get onRoomCreated => _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onRoomJoined => _roomJoinedController.stream;
  Stream<ExecutePlayPayload> get onExecutePlay => _executePlayController.stream;
  Stream<Map<String, dynamic>> get onExecutePause => _executePauseController.stream;
  Stream<Map<String, dynamic>> get onExecuteSeek => _executeSeekController.stream;
  Stream<Map<String, dynamic>> get onExecuteSkip => _executeSkipController.stream;
  Stream<Map<String, dynamic>> get onNtpPong => _ntpPongController.stream;
  Stream<String> get onError => _errorController.stream;

  /// Connect to the Node.js Socket.IO server at [serverUrl].
  void connect({String serverUrl = 'https://music-sync-server-sxbq.onrender.com'}) {
    if (_socket != null && _socket!.connected) {
      debugPrint('⚡ Socket already connected');
      return;
    }

    debugPrint('🔌 Connecting Socket.IO to $serverUrl ...');

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ Socket connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((reason) {
      _isConnected = false;
      debugPrint('❌ Socket disconnected: $reason');
    });

    _socket!.onConnectError((data) {
      debugPrint('⚠️ Socket connect error: $data');
    });

    // ── Server Events Listeners ──

    _socket!.on('room_created', (data) {
      debugPrint('🏠 Event room_created: $data');
      if (data is Map && data.containsKey('roomCode')) {
        _roomCreatedController.add(data['roomCode'].toString());
      }
    });

    _socket!.on('room_joined', (data) {
      debugPrint('👋 Event room_joined: $data');
      if (data is Map) {
        _roomJoinedController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('execute_play', (data) {
      debugPrint('▶️ Event execute_play received: $data');
      if (data is Map) {
        final payload = ExecutePlayPayload.fromMap(Map<String, dynamic>.from(data));
        _executePlayController.add(payload);
      }
    });

    _socket!.on('execute_pause', (data) {
      debugPrint('⏸️ Event execute_pause received: $data');
      if (data is Map) {
        _executePauseController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('execute_seek', (data) {
      debugPrint('⏩ Event execute_seek received: $data');
      if (data is Map) {
        _executeSeekController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('execute_skip', (data) {
      debugPrint('⏭️ Event execute_skip received: $data');
      if (data is Map) {
        _executeSkipController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('ntp_pong', (data) {
      if (data is Map) {
        _ntpPongController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('error_message', (data) {
      debugPrint('❌ Server error_message: $data');
      if (data is Map && data.containsKey('message')) {
        _errorController.add(data['message'].toString());
      }
    });

    _socket!.connect();
  }

  /// Request room creation from server.
  void createRoom() {
    _socket?.emit('create_room');
  }

  /// Join an existing room by code.
  void joinRoom(String roomCode) {
    _socket?.emit('join_room', {'roomCode': roomCode});
  }

  /// Leave current room.
  void leaveRoom() {
    _socket?.emit('leave_room');
  }

  /// Send `ntp_ping` with client timestamp for server clock alignment.
  void sendNtpPing(int clientSendTime) {
    _socket?.emit('ntp_ping', {'clientSendTime': clientSendTime});
  }

  /// Send `play_command` with Spotify Track URI and target execution timestamp (Buffer Strategy).
  void sendPlayCommand({
    required String roomCode,
    required String spotifyUri,
    required int targetTimestamp,
    int positionMs = 0,
  }) {
    debugPrint(
      '📡 Emitting play_command -> room: $roomCode, uri: $spotifyUri, target: $targetTimestamp',
    );
    _socket?.emit('play_command', {
      'roomCode': roomCode,
      'spotifyUri': spotifyUri,
      'positionMs': positionMs,
      'targetTimestamp': targetTimestamp,
    });
  }

  /// Send `pause_command`.
  void sendPauseCommand({
    required String roomCode,
    required int targetTimestamp,
  }) {
    _socket?.emit('pause_command', {
      'roomCode': roomCode,
      'targetTimestamp': targetTimestamp,
    });
  }

  /// Send `seek_command`.
  void sendSeekCommand({
    required String roomCode,
    required int positionMs,
    required int targetTimestamp,
  }) {
    _socket?.emit('seek_command', {
      'roomCode': roomCode,
      'positionMs': positionMs,
      'targetTimestamp': targetTimestamp,
    });
  }

  /// Disconnect socket.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
