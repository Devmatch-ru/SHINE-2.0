// lib/services/network_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../constants.dart';
import './logging_service.dart';

class NetworkService with LoggerMixin {
  @override
  String get loggerContext => 'NetworkService';

  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  Future<String?> getWifiIP() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP != null) {
        logInfo('WiFi IP obtained: $wifiIP');
      } else {
        logWarning('WiFi IP not available');
      }
      return wifiIP;
    } catch (e, stackTrace) {
      logError('Error getting WiFi IP: $e', stackTrace);
      return null;
    }
  }

  Future<bool> sendOfferToReceiver(
      String receiverUrl,
      RTCSessionDescription offer,
      String broadcasterUrl, {
        String? broadcasterId,
        int maxAttempts = 15,
      }) async {
    Exception? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        logInfo('Attempt ${attempt + 1} to send offer to receiver: $receiverUrl');

        final requestBody = {
          'sdp': offer.sdp,
          'type': offer.type,
          'broadcasterUrl': broadcasterUrl,
        };

        // Добавляем broadcasterId если предоставлен
        if (broadcasterId != null) {
          requestBody['broadcasterId'] = broadcasterId;
          requestBody['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
        }

        final response = await http
            .post(
          Uri.parse('$receiverUrl/offer'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent': 'Shine-Broadcaster/${broadcasterId ?? 'unknown'}',
          },
          body: jsonEncode(requestBody),
        )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          logInfo('Offer sent successfully to $receiverUrl');

          // Парсим ответ для получения дополнительной информации
          try {
            final responseData = jsonDecode(response.body);
            if (responseData is Map<String, dynamic>) {
              final assignedId = responseData['broadcaster_id'] as String?;
              final isPrimary = responseData['is_primary'] as bool?;

              if (assignedId != null) {
                logInfo('Assigned broadcaster ID: $assignedId, isPrimary: $isPrimary');
              }
            }
          } catch (e) {
            logWarning('Could not parse offer response: $e');
          }

          return true;
        } else {
          lastError = Exception(
              'Failed to send offer: ${response.statusCode} - ${response.body}');
          logWarning('Offer failed with status ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        lastError = Exception('Error sending offer: $e');
        logWarning('Attempt ${attempt + 1} failed: $e');
      }

      // Прогрессивная задержка между попытками
      if (attempt < maxAttempts - 1) {
        final delay = Duration(seconds: (attempt + 1).clamp(1, 5));
        await Future.delayed(delay);
      }
    }

    final error = lastError ?? Exception('Failed to send offer after $maxAttempts attempts');
    logError(error.toString());
    throw error;
  }

  Future<bool> sendAnswerToBroadcaster(
      String broadcasterUrl,
      RTCSessionDescription answer, {
        String? broadcasterId,
        int maxAttempts = 3,
      }) async {
    Exception? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        logInfo('Sending answer to broadcaster: $broadcasterUrl (attempt ${attempt + 1})');

        final requestBody = {
          'sdp': answer.sdp,
          'type': answer.type,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Добавляем broadcasterId если предоставлен
        if (broadcasterId != null) {
          requestBody['broadcasterId'] = broadcasterId;
        }

        final response = await http
            .post(
          Uri.parse('$broadcasterUrl/answer'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Shine-Receiver',
          },
          body: jsonEncode(requestBody),
        )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          logInfo('Answer sent successfully to broadcaster');
          return true;
        } else {
          lastError = Exception('Failed to send answer: ${response.statusCode} - ${response.body}');
          logError('Failed to send answer: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        lastError = Exception('Error sending answer: $e');
        logWarning('Answer send attempt ${attempt + 1} failed: $e');
      }

      // Короткая задержка между попытками
      if (attempt < maxAttempts - 1) {
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }

    logError('Failed to send answer after $maxAttempts attempts: $lastError');
    return false;
  }

  Future<bool> sendIceCandidate(
      String targetUrl,
      RTCIceCandidate candidate, {
        String? broadcasterId,
        int maxAttempts = 3,
      }) async {
    Exception? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        logDebug('Sending ICE candidate to: $targetUrl (attempt ${attempt + 1})');

        final requestBody = {
          'candidate': candidate.toMap(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };

        // Добавляем broadcasterId если предоставлен
        if (broadcasterId != null) {
          requestBody['broadcasterId'] = broadcasterId;
        }

        final response = await http
            .post(
          Uri.parse('$targetUrl/candidate'),
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'Shine-${broadcasterId != null ? 'Broadcaster' : 'Receiver'}',
          },
          body: jsonEncode(requestBody),
        )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          logDebug('ICE candidate sent successfully');
          return true;
        } else {
          lastError = Exception('Failed to send ICE candidate: ${response.statusCode}');
          logWarning('Failed to send ICE candidate: ${response.statusCode}');
        }
      } catch (e) {
        lastError = Exception('Error sending ICE candidate: $e');
        logWarning('ICE candidate send attempt ${attempt + 1} failed: $e');
      }

      // Очень короткая задержка для ICE candidates
      if (attempt < maxAttempts - 1) {
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }

    // Для ICE candidates не логируем как ошибку, т.к. это нормально
    logWarning('Could not send ICE candidate after $maxAttempts attempts');
    return false;
  }

  Future<bool> checkReceiverHealth(String receiverUrl, {String? broadcasterId}) async {
    try {
      logDebug('Checking receiver health: $receiverUrl');

      final uri = Uri.parse('$receiverUrl/health');
      final headers = <String, String>{
        'User-Agent': 'Shine-Broadcaster/${broadcasterId ?? 'unknown'}',
      };

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        // Парсим ответ для получения детальной информации
        try {
          final healthData = jsonDecode(response.body);
          if (healthData is Map<String, dynamic>) {
            final status = healthData['status'] as String?;
            final connectedBroadcasters = healthData['connected_broadcasters'] as int?;
            final isConnected = healthData['is_connected'] as bool?;

            logDebug('Receiver health: status=$status, broadcasters=$connectedBroadcasters, connected=$isConnected');

            return status == 'ok';
          }
        } catch (e) {
          logWarning('Could not parse health response: $e');
        }

        return true;
      } else {
        logDebug('Receiver health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      logDebug('Receiver health check error: $e');
      return false;
    }
  }

  Future<bool> checkBroadcasterHealth(String broadcasterUrl) async {
    try {
      logDebug('Checking broadcaster health: $broadcasterUrl');

      final response = await http
          .get(Uri.parse('$broadcasterUrl/health'))
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      logDebug('Broadcaster health check error: $e');
      return false;
    }
  }

  void sendDiscoveryBroadcast(RawDatagramSocket socket, String baseIP) {
    try {
      logInfo('Sending discovery broadcast to network: $baseIP.x');

      // Отправляем discovery сообщения по всей подсети
      for (int i = 1; i <= 254; i++) {
        final address = '$baseIP.$i';
        try {
          socket.send(
            AppConstants.discoveryMessage.codeUnits,
            InternetAddress(address),
            AppConstants.discoveryPort,
          );
        } catch (e) {
          // Игнорируем ошибки отправки на конкретные адреса
        }
      }

      logInfo('Discovery broadcast sent to 254 addresses');
    } catch (e, stackTrace) {
      logError('Error sending discovery broadcast: $e', stackTrace);
    }
  }

  void sendTargetedDiscovery(
      RawDatagramSocket socket,
      String baseIP,
      Set<String> knownIPs,
      ) {
    try {
      logInfo('Sending targeted discovery to known IPs');

      final addressesToScan = <String>{};

      // Добавляем известные IP адреса и их соседей
      for (final ip in knownIPs) {
        try {
          final lastPart = int.tryParse(ip.split('.').last) ?? 0;
          // Сканируем диапазон ±10 от известного IP
          for (int i = -10; i <= 10; i++) {
            final newLast = lastPart + i;
            if (newLast > 0 && newLast < 255) {
              addressesToScan.add('$baseIP.$newLast');
            }
          }
        } catch (e) {
          logWarning('Error processing known IP $ip: $e');
        }
      }

      // Добавляем некоторые случайные адреса для обнаружения новых устройств
      final random = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 20; i++) {
        final randomLast = ((random + i) % 254) + 1;
        addressesToScan.add('$baseIP.$randomLast');
      }

      // Отправляем discovery сообщения
      for (final address in addressesToScan) {
        try {
          socket.send(
            AppConstants.discoveryMessage.codeUnits,
            InternetAddress(address),
            AppConstants.discoveryPort,
          );
        } catch (e) {
          // Игнорируем ошибки отправки на конкретные адреса
        }
      }

      logInfo('Targeted discovery sent to ${addressesToScan.length} addresses');
    } catch (e, stackTrace) {
      logError('Error sending targeted discovery: $e', stackTrace);
    }
  }

  String createReceiverResponse(String wifiIP, {Map<String, dynamic>? additionalInfo}) {
    final baseResponse = '${AppConstants.receiverPrefix}$wifiIP:${AppConstants.signalingPort}';

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      final infoString = additionalInfo.entries
          .map((e) => '${e.key}=${e.value}')
          .join('&');
      return '$baseResponse?$infoString';
    }

    return baseResponse;
  }

  bool isDiscoveryMessage(String message) {
    return message.trim() == AppConstants.discoveryMessage;
  }

  bool isReceiverResponse(String message) {
    return message.startsWith(AppConstants.receiverPrefix);
  }

  Uri? validateReceiverUrl(String receiverUrl) {
    try {
      final uri = Uri.parse(receiverUrl);
      if (!uri.hasScheme || !uri.hasAuthority) {
        logError('Invalid receiver URL format: $receiverUrl');
        return null;
      }

      // Проверяем что это HTTP/HTTPS
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        logError('Invalid URL scheme: ${uri.scheme}');
        return null;
      }

      logInfo('Receiver URL validated: $receiverUrl');
      return uri;
    } catch (e, stackTrace) {
      logError('Error validating receiver URL: $e', stackTrace);
      return null;
    }
  }

  Map<String, String> parseReceiverInfo(String receiverMessage) {
    try {
      if (!isReceiverResponse(receiverMessage)) {
        throw ArgumentError('Not a receiver response message');
      }

      // Убираем префикс
      final withoutPrefix = receiverMessage.substring(AppConstants.receiverPrefix.length);

      // Разделяем на основную часть и query параметры
      final parts = withoutPrefix.split('?');
      final mainPart = parts[0];

      // Парсим IP:PORT
      final ipPortParts = mainPart.split(':');
      if (ipPortParts.length != 2) {
        throw ArgumentError('Invalid receiver message format');
      }

      final result = {
        'ip': ipPortParts[0],
        'port': ipPortParts[1],
        'url': 'http://${ipPortParts[0]}:${ipPortParts[1]}',
      };

      // Парсим дополнительные параметры если есть
      if (parts.length > 1 && parts[1].isNotEmpty) {
        final queryParams = parts[1].split('&');
        for (final param in queryParams) {
          final keyValue = param.split('=');
          if (keyValue.length == 2 && keyValue[0].isNotEmpty && keyValue[1].isNotEmpty) {
            result[keyValue[0]] = keyValue[1];
          }
        }
      }

      return result;
    } catch (e, stackTrace) {
      logError('Error parsing receiver info: $e', stackTrace);
      rethrow;
    }
  }

  // Utility methods for network diagnostics
  Future<Map<String, dynamic>> performNetworkDiagnostics() async {
    final diagnostics = <String, dynamic>{};

    try {
      // Получаем WiFi IP
      final wifiIP = await getWifiIP();
      diagnostics['wifi_ip'] = wifiIP;
      diagnostics['has_wifi'] = wifiIP != null;

      // Проверяем доступность портов
      diagnostics['discovery_port_available'] = await _checkPortAvailability(AppConstants.discoveryPort);
      diagnostics['signaling_port_available'] = await _checkPortAvailability(AppConstants.signalingPort);

      // Информация о сети
      if (wifiIP != null) {
        final parts = wifiIP.split('.');
        if (parts.length == 4) {
          diagnostics['network_class'] = _getNetworkClass(parts[0]);
          diagnostics['subnet'] = '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
        }
      }

      diagnostics['timestamp'] = DateTime.now().toIso8601String();
      diagnostics['status'] = 'completed';

    } catch (e, stackTrace) {
      logError('Error during network diagnostics: $e', stackTrace);
      diagnostics['error'] = e.toString();
      diagnostics['status'] = 'failed';
    }

    return diagnostics;
  }

  Future<bool> _checkPortAvailability(int port) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  String _getNetworkClass(String firstOctet) {
    final first = int.tryParse(firstOctet) ?? 0;

    if (first >= 1 && first <= 126) {
      return 'Class A';
    } else if (first >= 128 && first <= 191) {
      return 'Class B';
    } else if (first >= 192 && first <= 223) {
      return 'Class C';
    } else if (first >= 224 && first <= 239) {
      return 'Class D (Multicast)';
    } else if (first >= 240 && first <= 255) {
      return 'Class E (Reserved)';
    }

    return 'Unknown';
  }
}