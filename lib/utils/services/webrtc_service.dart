import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

import '../core/error_handler.dart';
import '../core/logger.dart';

class WebRTCService {
  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  final Logger _logger = Logger();
  final ErrorHandler _errorHandler = ErrorHandler();

  static const Map<String, dynamic> _defaultPeerConnectionConfig = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ],
      }
    ],
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
  };

  Future<rtc.RTCPeerConnection> createPeerConnection({
    Map<String, dynamic>? config,
    bool offerToReceiveVideo = false,
    bool offerToReceiveAudio = false,
  }) async {
    try {
      _logger.log('WebRTCService', 'Creating peer connection...');

      final configuration = {
        ..._defaultPeerConnectionConfig,
        ...?config,
        if (offerToReceiveVideo) 'offerToReceiveVideo': true,
        if (offerToReceiveAudio) 'offerToReceiveAudio': true,
      };

      final pc = await rtc.createPeerConnection(configuration);
      if (pc == null) {
        throw Exception('Failed to create peer connection');
      }

      _logger.log('WebRTCService', 'Peer connection created successfully');
      return pc;
    } catch (e) {
      _errorHandler.handleError('WebRTCService.createPeerConnection', e);
      rethrow;
    }
  }

  Future<rtc.RTCDataChannel> createDataChannel(
      rtc.RTCPeerConnection pc,
      String label, {
        bool ordered = true,
        int? maxRetransmits = 3,
        String protocol = 'sctp',
        bool negotiated = false,
      }) async {
    try {
      _logger.log('WebRTCService', 'Creating data channel: $label');

      final dataChannel = await pc.createDataChannel(
        label,
        rtc.RTCDataChannelInit()
          ..ordered = ordered
          ..maxRetransmits = maxRetransmits ?? 3
          ..protocol = protocol
          ..negotiated = negotiated,
      );

      _logger.log('WebRTCService', 'Data channel created: $label');
      return dataChannel;
    } catch (e) {
      _errorHandler.handleError('WebRTCService.createDataChannel', e);
      rethrow;
    }
  }

  Future<bool> waitForDataChannelOpen(
      rtc.RTCDataChannel channel, {
        Duration timeout = const Duration(seconds: 15),
      }) async {
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    Timer? timeoutTimer;

    void cleanup() {
      subscription.cancel();
      timeoutTimer?.cancel();
    }

    subscription = Stream.periodic(const Duration(milliseconds: 100))
        .listen((_) {
      if (channel.state == rtc.RTCDataChannelState.RTCDataChannelOpen) {
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    timeoutTimer = Timer(timeout, () {
      cleanup();
      if (!completer.isCompleted) {
        completer.complete(false);
      }
    });

    if (channel.state == rtc.RTCDataChannelState.RTCDataChannelOpen) {
      cleanup();
      return true;
    }

    return completer.future;
  }

  Future<void> sendDataChannelMessage(
      rtc.RTCDataChannel channel,
      Map<String, dynamic> data, {
        int maxRetries = 3,
      }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (channel.state != rtc.RTCDataChannelState.RTCDataChannelOpen) {
          if (attempt == maxRetries - 1) {
            throw Exception('Data channel not open after $maxRetries attempts');
          }
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        }

        final message = jsonEncode(data);
        await channel.send(rtc.RTCDataChannelMessage(message));
        _logger.log('WebRTCService', 'Message sent via data channel');
        return;
      } catch (e) {
        if (attempt == maxRetries - 1) {
          _errorHandler.handleError('WebRTCService.sendDataChannelMessage', e);
          rethrow;
        }
        await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
      }
    }
  }

  Map<String, dynamic> createMediaConstraints({
    required int width,
    required int height,
    required int frameRate,
    bool audio = false,
    String facingMode = 'environment',
    double aspectRatio = 16.0 / 9.0,
  }) {
    return {
      'audio': audio,
      'video': {
        'facingMode': facingMode,
        'width': width,
        'height': height,
        'frameRate': frameRate,
        'aspectRatio': aspectRatio,
        'advanced': [
          {
            'width': {'min': width, 'ideal': width},
            'height': {'min': height, 'ideal': height},
            'frameRate': {'min': frameRate, 'ideal': frameRate},
          },
          {
            'exposureMode': 'continuous',
            'focusMode': 'continuous',
            'whiteBalanceMode': 'continuous',
          }
        ]
      },
    };
  }

  Future<void> safeCloseConnection(rtc.RTCPeerConnection? connection) async {
    if (connection == null) return;

    try {
      _logger.log('WebRTCService', 'Closing peer connection...');
      await connection.close();
      _logger.log('WebRTCService', 'Peer connection closed');
    } catch (e) {
      _errorHandler.handleError('WebRTCService.safeCloseConnection', e);
    }
  }

  Future<void> safeCloseDataChannel(rtc.RTCDataChannel? channel) async {
    if (channel == null) return;

    try {
      _logger.log('WebRTCService', 'Closing data channel...');
      await channel.close();
      _logger.log('WebRTCService', 'Data channel closed');
    } catch (e) {
      _errorHandler.handleError('WebRTCService.safeCloseDataChannel', e);
    }
  }

  Future<void> safeDisposeStream(rtc.MediaStream? stream) async {
    if (stream == null) return;

    try {
      _logger.log('WebRTCService', 'Disposing media stream...');
      stream.getTracks().forEach((track) => track.stop());
      await stream.dispose();
      _logger.log('WebRTCService', 'Media stream disposed');
    } catch (e) {
      _errorHandler.handleError('WebRTCService.safeDisposeStream', e);
    }
  }
}