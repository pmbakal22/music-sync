import 'dart:async';
import 'package:flutter/foundation.dart';
import 'socket_service.dart';

/// Clock Synchronization Service (NTP Ping/Pong)
///
/// Measures network round-trip time (RTT) and calculates the exact clock offset
/// between the local phone device and the central Node.js Sync Server.
///
/// Offset formula:
///   Offset = ServerTime - (ClientSendTime + RTT / 2)
///
/// Estimated Server Time:
///   EstimatedServerTime = LocalTime + ClockOffset
class ClockSyncService {
  ClockSyncService._();
  static final ClockSyncService instance = ClockSyncService._();

  int _clockOffsetMs = 0;
  int get clockOffsetMs => _clockOffsetMs;

  bool _isSynced = false;
  bool get isSynced => _isSynced;

  StreamSubscription<Map<String, dynamic>>? _ntpPongSub;

  /// Returns current estimated Server Time in milliseconds.
  int get currentServerTimeMs {
    return DateTime.now().millisecondsSinceEpoch + _clockOffsetMs;
  }

  /// Perform NTP Clock Synchronization with 5 sample pings.
  Future<void> syncClock() async {
    debugPrint('⏱️ Starting NTP Clock Sync with server...');
    final List<int> measuredOffsets = [];

    _ntpPongSub?.cancel();
    _ntpPongSub = SocketService.instance.onNtpPong.listen((data) {
      final clientSendTime = (data['clientSendTime'] as num).toInt();
      final serverTime = (data['serverTime'] as num).toInt();
      final now = DateTime.now().millisecondsSinceEpoch;

      final rtt = now - clientSendTime;
      final estimatedServerTimeAtSend = serverTime - (rtt ~/ 2);
      final offset = estimatedServerTimeAtSend - clientSendTime;

      measuredOffsets.add(offset);
      debugPrint('⏱️ NTP Sample #${measuredOffsets.length}: RTT = ${rtt}ms, Offset = ${offset}ms');
    });

    // Send 5 sample pings separated by 150ms
    for (int i = 0; i < 5; i++) {
      if (!SocketService.instance.isConnected) break;
      final sendTime = DateTime.now().millisecondsSinceEpoch;
      SocketService.instance.sendNtpPing(sendTime);
      await Future.delayed(const Duration(milliseconds: 150));
    }

    // Process median offset to eliminate network jitter outliers
    if (measuredOffsets.isNotEmpty) {
      measuredOffsets.sort();
      _clockOffsetMs = measuredOffsets[measuredOffsets.length ~/ 2];
      _isSynced = true;
      debugPrint('✅ NTP Clock Sync complete! Median Offset = ${_clockOffsetMs}ms');
    } else {
      debugPrint('⚠️ NTP Clock Sync failed (no pongs received). Defaulting offset to 0ms.');
    }
  }

  void dispose() {
    _ntpPongSub?.cancel();
  }
}
