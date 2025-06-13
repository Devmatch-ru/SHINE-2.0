import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

class DiscoveryManager {
  RawDatagramSocket? _udpSocket;
  Timer? _discoveryTimer;
  final Set<String> _receivers = {};
  final void Function(String) _onLog;
  final VoidCallback? onStateChange;

  DiscoveryManager({
    required void Function(String) onLog,
    this.onStateChange,
  }) : _onLog = onLog;

  Set<String> get receivers => _receivers;

  Future<void> startDiscoveryListener() async {
    try {
      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            if (message.startsWith('RECEIVER:')) {
              _receivers.add(message);
              _onLog('Found receiver: $message');
              onStateChange?.call();
            }
          }
        }
      });

      // Периодическая отправка discovery-сообщений
      _discoveryTimer = Timer.periodic(Duration(seconds: 2), (_) async {
        final wifiIP = await NetworkInfo().getWifiIP();
        if (wifiIP != null) {
          final parts = wifiIP.split('.');
          if (parts.length == 4) {
            final baseIP = '${parts[0]}.${parts[1]}.${parts[2]}';
            for (int i = 1; i <= 254; i++) {
              final address = '$baseIP.$i';
              _udpSocket!
                  .send('DISCOVER'.codeUnits, InternetAddress(address), 9000);
            }
          }
        }
      });

      _onLog('UDP discovery listener started');
    } catch (e) {
      _onLog('Error starting discovery listener: $e');
    }
  }

  Future<List<String>> discoverReceivers() async {
    _receivers.clear();

    if (_udpSocket == null) {
      await startDiscoveryListener();
    }

    // Ждем 2 секунды, чтобы получить ответы от слушателей
    await Future.delayed(Duration(seconds: 2));

    _onLog('Discovered receivers: ${_receivers.toList()}');
    return _receivers.toList();
  }

  Future<void> dispose() async {
    _udpSocket?.close();
    _udpSocket = null;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _receivers.clear();
  }
}
