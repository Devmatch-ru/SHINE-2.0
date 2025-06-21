// lib/utils/webrtc/discovery_manager.dart (Updated)
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../constants.dart';
import '../service/logging_service.dart';
import '../service/network_service.dart';


class DiscoveryManager with LoggerMixin {
  @override
  String get loggerContext => 'DiscoveryManager';

  // Services
  final NetworkService _networkService = NetworkService();

  // Network components
  RawDatagramSocket? _udpSocket;

  // Timers
  Timer? _discoveryTimer;
  Timer? _cleanupTimer;

  // State
  final Set<String> _receivers = {};
  final Map<String, DateTime> _lastSeenReceivers = {};
  bool _isInitialScan = true;

  // Callbacks
  final VoidCallback? onStateChange;

  DiscoveryManager({
    this.onStateChange,
  });

  // Getters
  Set<String> get receivers => Set.unmodifiable(_receivers);

  Future<void> startDiscoveryListener() async {
    try {
      logInfo('Starting discovery listener...');

      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
      );

      _udpSocket!.broadcastEnabled = true;

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          _handleUdpPacket();
        }
      });

      _startPeriodicDiscovery();
      _startCleanupTimer();

      logInfo('Discovery listener started on port ${AppConstants.discoveryPort}');
    } catch (e, stackTrace) {
      logError('Error starting discovery listener: $e', stackTrace);
      rethrow;
    }
  }

  void _handleUdpPacket() {
    try {
      final datagram = _udpSocket!.receive();
      if (datagram != null) {
        final message = String.fromCharCodes(datagram.data);
        if (_networkService.isReceiverResponse(message)) {
          _handleReceiverResponse(message);
        }
      }
    } catch (e, stackTrace) {
      logError('Error handling UDP packet: $e', stackTrace);
    }
  }

  void _handleReceiverResponse(String message) {
    try {
      if (_receivers.add(message)) {
        logInfo('Found new receiver: $message');
        onStateChange?.call();
      }
      _lastSeenReceivers[message] = DateTime.now();
    } catch (e, stackTrace) {
      logError('Error handling receiver response: $e', stackTrace);
    }
  }

  void _startPeriodicDiscovery() {
    _discoveryTimer?.cancel();
    _discoveryTimer = Timer.periodic(AppConstants.discoveryInterval, (_) => _performDiscovery());
    _performDiscovery(); // Initial discovery
  }

  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(AppConstants.cleanupInterval, (_) => _cleanupStaleReceivers());
  }

  Future<void> _performDiscovery() async {
    try {
      final wifiIP = await _networkService.getWifiIP();
      if (wifiIP == null) {
        logWarning('WiFi IP not available for discovery');
        return;
      }

      final parts = wifiIP.split('.');
      if (parts.length != 4) {
        logError('Invalid WiFi IP format: $wifiIP');
        return;
      }

      final baseIP = '${parts[0]}.${parts[1]}.${parts[2]}';

      if (_isInitialScan) {
        logInfo('Performing initial full network scan');
        _networkService.sendDiscoveryBroadcast(_udpSocket!, baseIP);
        _isInitialScan = false;
      } else {
        logInfo('Performing targeted discovery');
        _performTargetedDiscovery(baseIP);
      }
    } catch (e, stackTrace) {
      logError('Error during discovery: $e', stackTrace);
    }
  }

  void _performTargetedDiscovery(String baseIP) {
    try {
      // Get known IPs from receivers
      final knownIPs = _receivers
          .map((r) {
        try {
          final info = _networkService.parseReceiverInfo(r);
          return info['ip']!;
        } catch (e) {
          return null;
        }
      })
          .where((ip) => ip != null)
          .cast<String>()
          .toSet();

      _networkService.sendTargetedDiscovery(_udpSocket!, baseIP, knownIPs);
    } catch (e, stackTrace) {
      logError('Error in targeted discovery: $e', stackTrace);
    }
  }

  void _cleanupStaleReceivers() {
    try {
      final now = DateTime.now();
      final staleReceivers = _lastSeenReceivers.entries
          .where((entry) => now.difference(entry.value) > AppConstants.receiverTimeout)
          .map((entry) => entry.key)
          .toList();

      for (final receiver in staleReceivers) {
        _receivers.remove(receiver);
        _lastSeenReceivers.remove(receiver);
        logInfo('Removed stale receiver: $receiver');
        onStateChange?.call();
      }

      if (staleReceivers.isNotEmpty) {
        logInfo('Cleaned up ${staleReceivers.length} stale receivers');
      }
    } catch (e, stackTrace) {
      logError('Error cleaning up stale receivers: $e', stackTrace);
    }
  }

  Future<List<String>> discoverReceivers() async {
    try {
      logInfo('Starting manual receiver discovery...');

      _isInitialScan = true;
      await _performDiscovery();

      // Wait a bit for responses
      await Future.delayed(const Duration(seconds: 2));

      final receiverList = _receivers.toList();
      logInfo('Discovery completed. Found ${receiverList.length} receivers');

      return receiverList;
    } catch (e, stackTrace) {
      logError('Error in manual receiver discovery: $e', stackTrace);
      return [];
    }
  }

  Future<void> refreshReceivers() async {
    try {
      logInfo('Refreshing receiver list...');
      await _performDiscovery();
    } catch (e, stackTrace) {
      logError('Error refreshing receivers: $e', stackTrace);
    }
  }

  void forceFullScan() {
    logInfo('Forcing full network scan on next discovery');
    _isInitialScan = true;
  }

  void clearReceivers() {
    logInfo('Clearing all discovered receivers');
    _receivers.clear();
    _lastSeenReceivers.clear();
    onStateChange?.call();
  }

  Map<String, Map<String, String>> getParsedReceivers() {
    final parsed = <String, Map<String, String>>{};

    for (final receiver in _receivers) {
      try {
        final info = _networkService.parseReceiverInfo(receiver);
        parsed[receiver] = info;
      } catch (e) {
        logWarning('Could not parse receiver info: $receiver');
      }
    }

    return parsed;
  }

  Future<void> dispose() async {
    try {
      logInfo('Disposing discovery manager...');

      _discoveryTimer?.cancel();
      _cleanupTimer?.cancel();
      _udpSocket?.close();

      _udpSocket = null;
      _receivers.clear();
      _lastSeenReceivers.clear();

      logInfo('Discovery manager disposed successfully');
    } catch (e, stackTrace) {
      logError('Error disposing discovery manager: $e', stackTrace);
    }
  }
}