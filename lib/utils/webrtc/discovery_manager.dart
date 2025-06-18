import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DiscoveryManager {
  RawDatagramSocket? _udpSocket;
  Timer? _discoveryTimer;
  Timer? _cleanupTimer;
  final Set<String> _receivers = {};
  final void Function(String) _onLog;
  final VoidCallback? onStateChange;

  final Map<String, DateTime> _lastSeenReceivers = {};
  static const Duration _receiverTimeout = Duration(seconds: 30);
  static const Duration _discoveryInterval = Duration(seconds: 5);
  static const Duration _cleanupInterval = Duration(seconds: 10);
  bool _isInitialScan = true;

  DiscoveryManager({
    required void Function(String) onLog,
    this.onStateChange,
  }) : _onLog = onLog;

  Set<String> get receivers => _receivers;

  Future<void> startDiscoveryListener() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 9000,
          reuseAddress: true);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            if (message.startsWith('RECEIVER:')) {
              _handleReceiverResponse(message);
            }
          }
        }
      });

      _startPeriodicDiscovery();

      _startCleanupTimer();

      _onLog('UDP discovery listener started');
    } catch (e) {
      _onLog('Error starting discovery listener: $e');
    }
  }

  void _handleReceiverResponse(String message) {
    if (_receivers.add(message)) {
      _onLog('Found new receiver: $message');
      onStateChange?.call();
    }
    _lastSeenReceivers[message] = DateTime.now();
  }

  void _startPeriodicDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer =
        Timer.periodic(_discoveryInterval, (_) => _performDiscovery());
    _performDiscovery();
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer =
        Timer.periodic(_cleanupInterval, (_) => _cleanupStaleReceivers());
  }

  Future<void> _performDiscovery() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP != null) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          final baseIP = '${parts[0]}.${parts[1]}.${parts[2]}';

          if (_isInitialScan) {
            for (int i = 1; i <= 254; i++) {
              final address = '$baseIP.$i';
              _udpSocket!
                  .send('DISCOVER'.codeUnits, InternetAddress(address), 9000);
            }
            _isInitialScan = false;
          } else {
            final knownIPs = _receivers.map((r) {
              final parts = r.split(':');
              return parts[1];
            }).toSet();

            for (final ip in knownIPs) {
              final lastPart = int.tryParse(ip.split('.').last) ?? 0;
              for (int i = -5; i <= 5; i++) {
                final newLast = lastPart + i;
                if (newLast > 0 && newLast < 255) {
                  final address = '$baseIP.$newLast';
                  _udpSocket!.send(
                      'DISCOVER'.codeUnits, InternetAddress(address), 9000);
                }
              }
            }

            final random = List.generate(10,
                (i) => (DateTime.now().millisecondsSinceEpoch + i) % 254 + 1);
            for (final i in random) {
              final address = '$baseIP.$i';
              _udpSocket!
                  .send('DISCOVER'.codeUnits, InternetAddress(address), 9000);
            }
          }
        }
      }
    } catch (e) {
      _onLog('Error during discovery: $e');
    }
  }

  void _cleanupStaleReceivers() {
    final now = DateTime.now();
    final staleReceivers = _lastSeenReceivers.entries
        .where((entry) => now.difference(entry.value) > _receiverTimeout)
        .map((entry) => entry.key)
        .toList();

    for (final receiver in staleReceivers) {
      _receivers.remove(receiver);
      _lastSeenReceivers.remove(receiver);
      _onLog('Removed stale receiver: $receiver');
      onStateChange?.call();
    }
  }

  Future<List<String>> discoverReceivers() async {
    _isInitialScan = true;
    await _performDiscovery();
    await Future.delayed(const Duration(seconds: 2));
    return _receivers.toList();
  }

  Future<void> dispose() async {
    _discoveryTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    _receivers.clear();
    _lastSeenReceivers.clear();
  }
}
