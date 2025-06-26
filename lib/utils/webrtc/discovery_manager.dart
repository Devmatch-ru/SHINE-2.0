import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'NetworkUtils.dart';

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
  String? _cachedLocalIP; // ИСПРАВЛЕНИЕ: Кэшируем найденный IP

  DiscoveryManager({
    required void Function(String) onLog,
    this.onStateChange,
  }) : _onLog = onLog;

  Set<String> get receivers => _receivers;

  Future<bool> _checkPermissions() async {
    if (Platform.isAndroid) {
      final status = await Permission.locationWhenInUse.request();
      _onLog('Location permission status: $status');
      return status.isGranted;
    }
    return true;
  }

  Future<void> startDiscoveryListener() async {
    try {
      if (!await _checkPermissions()) {
        _onLog('Location permission denied, discovery may fail');
      }

      // ИСПРАВЛЕНИЕ: Используем новую утилиту для получения IP
      final optimalIP = await NetworkUtils.getOptimalWiFiIP();
      if (optimalIP == null) {
        _onLog('Failed to get optimal WiFi IP address');

        // Показываем отладочную информацию
        final debugInfo = await NetworkUtils.getNetworkDebugInfo();
        _onLog('Network debug info: $debugInfo');

        throw Exception('No valid local IP address found');
      }

      _cachedLocalIP = optimalIP;
      _onLog('Using optimal WiFi IP: $optimalIP');

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
      _onLog('UDP discovery listener started on optimal network');
    } catch (e) {
      _onLog('Error starting discovery listener: $e');
      rethrow; // ИСПРАВЛЕНИЕ: Пробрасываем ошибку для обработки на верхнем уровне
    }
  }

  void _handleReceiverResponse(String message) {
    final parts = message.split(':');
    if (parts.length >= 2) {
      final ip = parts[1];

      // ИСПРАВЛЕНИЕ: Улучшенная фильтрация IP адресов
      if (!_isValidReceiverIP(ip)) {
        _onLog('Ignoring invalid receiver IP: $ip');
        return;
      }

      // ИСПРАВЛЕНИЕ: Проверяем, что IP в той же подсети
      if (_cachedLocalIP != null && !NetworkUtils.areInSameSubnet(_cachedLocalIP!, ip)) {
        _onLog('Ignoring receiver from different subnet: $ip (local: $_cachedLocalIP)');
        return;
      }

      if (_receivers.add(message)) {
        _onLog('Found new receiver: $message');
        onStateChange?.call();
      }
      _lastSeenReceivers[message] = DateTime.now();
    }
  }

  // ИСПРАВЛЕНИЕ: Улучшенная проверка валидности IP получателя
  bool _isValidReceiverIP(String ip) {
    // Используем NetworkUtils для проверки
    if (!_isValidIPv4(ip)) {
      _onLog('Invalid IPv4 format: $ip');
      return false;
    }

    if (_isAPIPAAddress(ip)) {
      _onLog('Ignoring APIPA address: $ip');
      return false;
    }

    if (_isLoopback(ip)) {
      _onLog('Ignoring loopback address: $ip');
      return false;
    }

    if (_isCarrierGradeNAT(ip)) {
      _onLog('Ignoring Carrier Grade NAT address: $ip');
      return false;
    }

    // Проверяем, что это локальная сеть
    if (!_isPrivateNetwork(ip)) {
      _onLog('Ignoring non-private network address: $ip');
      return false;
    }

    return true;
  }

  // Локальные методы для проверки IP (дублируем из NetworkUtils для доступности)
  bool _isValidIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  bool _isLoopback(String ip) => ip.startsWith('127.');
  bool _isAPIPAAddress(String ip) => ip.startsWith('169.254.');

  bool _isCarrierGradeNAT(String ip) {
    if (!ip.startsWith('100.')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final secondOctet = int.tryParse(parts[1]);
    if (secondOctet == null) return false;
    return secondOctet >= 64 && secondOctet <= 127;
  }

  bool _is192Network(String ip) => ip.startsWith('192.168.');
  bool _is10Network(String ip) => ip.startsWith('10.');

  bool _is172Network(String ip) {
    if (!ip.startsWith('172.')) return false;
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    final secondOctet = int.tryParse(parts[1]);
    if (secondOctet == null) return false;
    return secondOctet >= 16 && secondOctet <= 31;
  }

  bool _isPrivateNetwork(String ip) {
    return _is192Network(ip) || _is10Network(ip) || _is172Network(ip);
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
      // ИСПРАВЛЕНИЕ: Используем кэшированный IP или получаем новый
      String? localIP = _cachedLocalIP;
      if (localIP == null) {
        localIP = await NetworkUtils.getOptimalWiFiIP();
        if (localIP == null) {
          _onLog('No valid local IP for discovery');
          return;
        }
        _cachedLocalIP = localIP;
      }

      _onLog('Performing discovery from IP: $localIP');

      final parts = localIP.split('.');
      if (parts.length == 4) {
        final baseIP = '${parts[0]}.${parts[1]}.${parts[2]}';

        if (_isInitialScan) {
          // ИСПРАВЛЕНИЕ: Умное сканирование - сначала популярные адреса
          await _performSmartInitialScan(baseIP);
          _isInitialScan = false;
        } else {
          // ИСПРАВЛЕНИЕ: Быстрое сканирование известных адресов
          await _performQuickScan(baseIP);
        }
      }
    } catch (e) {
      _onLog('Error during discovery: $e');
    }
  }

  // ИСПРАВЛЕНИЕ: Умное начальное сканирование
  Future<void> _performSmartInitialScan(String baseIP) async {
    _onLog('Starting smart initial scan for $baseIP.x');

    // Сначала сканируем популярные адреса роутеров и устройств
    final priorityAddresses = [
      1, 254, 100, 101, 102, 103, 104, 105, // Роутеры и серверы
      10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, // Популярные DHCP адреса
      50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60,
      150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160,
    ];

    for (final addr in priorityAddresses) {
      final address = '$baseIP.$addr';
      _sendDiscoveryTo(address);

      // Небольшая задержка между отправками для избежания перегрузки сети
      if (addr % 10 == 0) {
        await Future.delayed(Duration(milliseconds: 50));
      }
    }

    // Затем сканируем остальные адреса
    for (int i = 1; i <= 254; i++) {
      if (!priorityAddresses.contains(i)) {
        final address = '$baseIP.$i';
        _sendDiscoveryTo(address);

        if (i % 20 == 0) {
          await Future.delayed(Duration(milliseconds: 100));
        }
      }
    }

    _onLog('Smart initial scan completed');
  }

  // ИСПРАВЛЕНИЕ: Быстрое сканирование для поддержания соединений
  Future<void> _performQuickScan(String baseIP) async {
    // Сканируем известные адреса получателей
    final knownIPs = _receivers.map((r) {
      final parts = r.split(':');
      return parts.length > 1 ? parts[1] : null;
    }).where((ip) => ip != null).cast<String>().toSet();

    for (final ip in knownIPs) {
      _sendDiscoveryTo(ip);

      // Также сканируем соседние адреса
      final parts = ip.split('.');
      if (parts.length == 4) {
        final lastOctet = int.tryParse(parts[3]) ?? 0;
        for (int i = -3; i <= 3; i++) {
          final newLastOctet = lastOctet + i;
          if (newLastOctet > 0 && newLastOctet < 255) {
            final neighborIP = '${parts[0]}.${parts[1]}.${parts[2]}.$newLastOctet';
            _sendDiscoveryTo(neighborIP);
          }
        }
      }
    }

    // Сканируем случайные адреса для обнаружения новых устройств
    final random = List.generate(20,
            (i) => (DateTime.now().millisecondsSinceEpoch + i) % 254 + 1);
    for (final i in random) {
      final address = '$baseIP.$i';
      _sendDiscoveryTo(address);
    }

    _onLog('Quick scan completed');
  }

  void _sendDiscoveryTo(String address) {
    try {
      _udpSocket!.send('DISCOVER'.codeUnits, InternetAddress(address), 9000);
      // _onLog('Sent discovery to: $address:9000'); // Закомментировано для уменьшения спама в логах
    } catch (e) {
      // Игнорируем ошибки отправки на отдельные адреса
      // _onLog('Failed to send discovery to $address: $e');
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
    _onLog('Starting manual receiver discovery');
    _isInitialScan = true;
    _cachedLocalIP = null; // Сбрасываем кэш для получения актуального IP

    await _performDiscovery();
    await Future.delayed(const Duration(seconds: 3)); // Увеличиваем время ожидания

    final receiversList = _receivers.toList();
    _onLog('Manual discovery completed. Found ${receiversList.length} receivers');

    return receiversList;
  }

  // ИСПРАВЛЕНИЕ: Метод для получения информации о сети для отладки
  Future<Map<String, dynamic>> getNetworkInfo() async {
    final info = <String, dynamic>{
      'cachedLocalIP': _cachedLocalIP,
      'optimalIP': await NetworkUtils.getOptimalWiFiIP(),
      'receivers': _receivers.toList(),
      'lastSeenReceivers': _lastSeenReceivers.map(
              (key, value) => MapEntry(key, value.toIso8601String())
      ),
      'networkDebugInfo': await NetworkUtils.getNetworkDebugInfo(),
    };

    return info;
  }

  // ИСПРАВЛЕНИЕ: Принудительное обновление локального IP
  Future<void> refreshLocalIP() async {
    _onLog('Refreshing local IP address');
    _cachedLocalIP = null;

    final newIP = await NetworkUtils.getOptimalWiFiIP();
    if (newIP != null) {
      _cachedLocalIP = newIP;
      _onLog('Local IP refreshed to: $newIP');
    } else {
      _onLog('Failed to refresh local IP');
    }
  }

  Future<void> dispose() async {
    _discoveryTimer?.cancel();
    _cleanupTimer?.cancel();
    _udpSocket?.close();
    _udpSocket = null;
    _receivers.clear();
    _lastSeenReceivers.clear();
    _cachedLocalIP = null;
    _onLog('Discovery manager disposed');
  }
}