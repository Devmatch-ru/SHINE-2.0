// lib/services/network_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../constants.dart';
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
      String broadcasterUrl,
      ) async {
    final maxAttempts = 15;
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxAttempts) {
      try {
        logInfo('Attempt ${attempt + 1} to send offer to receiver: $receiverUrl');

        final response = await http
            .post(
          Uri.parse('$receiverUrl/offer'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'sdp': offer.sdp,
            'type': offer.type,
            'broadcasterUrl': broadcasterUrl,
          }),
        )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          logInfo('Offer sent successfully to $receiverUrl');
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

      attempt++;
      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    final error = lastError ?? Exception('Failed to send offer after $maxAttempts attempts');
    logError(error.toString());
    throw error;
  }

  Future<bool> sendAnswerToBroadcaster(
      String broadcasterUrl,
      RTCSessionDescription answer,
      ) async {
    try {
      logInfo('Sending answer to broadcaster: $broadcasterUrl');

      final response = await http
          .post(
        Uri.parse('$broadcasterUrl/answer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sdp': answer.sdp,
          'type': answer.type,
        }),
      )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        logInfo('Answer sent successfully to broadcaster');
        return true;
      } else {
        logError('Failed to send answer: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e, stackTrace) {
      logError('Error sending answer: $e', stackTrace);
      return false;
    }
  }

  Future<bool> sendIceCandidate(
      String targetUrl,
      RTCIceCandidate candidate,
      ) async {
    try {
      logInfo('Sending ICE candidate to: $targetUrl');

      final response = await http
          .post(
        Uri.parse('$targetUrl/candidate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'candidate': candidate.toMap(),
        }),
      )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        logInfo('ICE candidate sent successfully');
        return true;
      } else {
        logWarning('Failed to send ICE candidate: ${response.statusCode}');
        return false;
      }
    } catch (e, stackTrace) {
      logError('Error sending ICE candidate: $e', stackTrace);
      return false;
    }
  }

  Future<bool> checkReceiverHealth(String receiverUrl) async {
    try {
      logInfo('Checking receiver health: $receiverUrl');

      final response = await http
          .get(Uri.parse('$receiverUrl/health'))
          .timeout(const Duration(seconds: 5));

      final isHealthy = response.statusCode == 200;
      logInfo('Receiver health check result: $isHealthy');
      return isHealthy;
    } catch (e, stackTrace) {
      logError('Error checking receiver health: $e', stackTrace);
      return false;
    }
  }

  void sendDiscoveryBroadcast(RawDatagramSocket socket, String baseIP) {
    try {
      logInfo('Sending discovery broadcast to network: $baseIP.x');

      for (int i = 1; i <= 254; i++) {
        final address = '$baseIP.$i';
        socket.send(
          AppConstants.discoveryMessage.codeUnits,
          InternetAddress(address),
          AppConstants.discoveryPort,
        );
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

      // Send to known IPs and their neighbors
      for (final ip in knownIPs) {
        final lastPart = int.tryParse(ip.split('.').last) ?? 0;
        for (int i = -5; i <= 5; i++) {
          final newLast = lastPart + i;
          if (newLast > 0 && newLast < 255) {
            final address = '$baseIP.$newLast';
            socket.send(
              AppConstants.discoveryMessage.codeUnits,
              InternetAddress(address),
              AppConstants.discoveryPort,
            );
          }
        }
      }

      // Send to some random addresses
      final random = List.generate(
        10,
            (i) => (DateTime.now().millisecondsSinceEpoch + i) % 254 + 1,
      );

      for (final i in random) {
        final address = '$baseIP.$i';
        socket.send(
          AppConstants.discoveryMessage.codeUnits,
          InternetAddress(address),
          AppConstants.discoveryPort,
        );
      }

      logInfo('Targeted discovery sent');
    } catch (e, stackTrace) {
      logError('Error sending targeted discovery: $e', stackTrace);
    }
  }

  String createReceiverResponse(String wifiIP) {
    return '${AppConstants.receiverPrefix}$wifiIP:${AppConstants.signalingPort}';
  }

  bool isDiscoveryMessage(String message) {
    return message == AppConstants.discoveryMessage;
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

      final parts = receiverMessage.split(':');
      if (parts.length != 3) {
        throw ArgumentError('Invalid receiver message format');
      }

      return {
        'ip': parts[1],
        'port': parts[2],
        'url': 'http://${parts[1]}:${parts[2]}',
      };
    } catch (e, stackTrace) {
      logError('Error parsing receiver info: $e', stackTrace);
      rethrow;
    }
  }
}