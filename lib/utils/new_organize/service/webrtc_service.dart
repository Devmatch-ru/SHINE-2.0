// lib/services/webrtc_service.dart
import 'dart:ui';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import '../../constants.dart';
import './logging_service.dart';

class WebRTCService with LoggerMixin {
  @override
  String get loggerContext => 'WebRTCService';

  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  Map<String, dynamic> get defaultPeerConnectionConfig => {
    'iceServers': AppConstants.iceServers,
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'iceCandidatePoolSize': 1,
    'enableDtlsSrtp': true,
    'enableRtpDataChannels': false,
  };

  Map<String, dynamic> get defaultOfferConstraints => {
    'offerToReceiveVideo': true,
    'offerToReceiveAudio': false,
    'voiceActivityDetection': false,
    'iceRestart': false,
    'enableDtlsSrtp': true,
  };

  Map<String, dynamic> get defaultAnswerConstraints => {
    'offerToReceiveVideo': true,
    'offerToReceiveAudio': false,
    'voiceActivityDetection': true,
  };

  rtc.RTCDataChannelInit get defaultDataChannelInit => rtc.RTCDataChannelInit()
    ..ordered = true
    ..maxRetransmits = 3
    ..protocol = 'sctp'
    ..negotiated = false;

  Future<rtc.RTCPeerConnection> createPeerConnection({
    Map<String, dynamic>? config,
  }) async {
    try {
      final finalConfig = config ?? defaultPeerConnectionConfig;
      logInfo('Creating peer connection with config: $finalConfig');

      final pc = await rtc.createPeerConnection(finalConfig);
      if (pc == null) {
        throw Exception('Failed to create peer connection');
      }

      logInfo('Peer connection created successfully');
      return pc;
    } catch (e, stackTrace) {
      logError('Error creating peer connection: $e', stackTrace);
      rethrow;
    }
  }

  Future<rtc.RTCDataChannel> createDataChannel(
      rtc.RTCPeerConnection pc,
      String label, {
        rtc.RTCDataChannelInit? init,
      }) async {
    try {
      logInfo('Creating data channel: $label');

      final dataChannel = await pc.createDataChannel(
        label,
        init ?? defaultDataChannelInit,
      );

      logInfo('Data channel created successfully: $label');
      return dataChannel;
    } catch (e, stackTrace) {
      logError('Error creating data channel: $e', stackTrace);
      rethrow;
    }
  }

  String modifySdpForHighQuality(String sdp) {
    logInfo('Modifying SDP for high quality');

    final lines = sdp.split('\r\n');
    final newLines = <String>[];

    for (final line in lines) {
      // Увеличенный битрейт для видео
      if (line.startsWith('b=AS:')) {
        newLines.add('b=AS:2500');
        continue;
      }

      // Высокий приоритет для видео
      if (line.startsWith('m=video')) {
        newLines.add(line);
        newLines.add('b=AS:2500');
        newLines.add('a=content:main');
        newLines.add('a=priority:high');
        continue;
      }

      // Оптимизация параметров кодека
      if (line.startsWith('a=fmtp:')) {
        if (line.contains('VP8')) {
          newLines.add('$line;max-fs=12288;max-fr=30');
          continue;
        } else if (line.contains('H264')) {
          newLines.add(
              '$line;profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1');
          continue;
        }
      }

      newLines.add(line);
    }

    final modifiedSdp = newLines.join('\r\n');
    logInfo('SDP modified successfully');
    return modifiedSdp;
  }

  Future<void> optimizeSenderParameters(rtc.RTCRtpSender sender) async {
    try {
      logInfo('Optimizing sender parameters');

      final params = sender.parameters;

      if (params.encodings != null && params.encodings!.isNotEmpty) {
        for (final encoding in params.encodings!) {
          encoding.maxBitrate = 2500000; // 2.5 Mbps
          encoding.minBitrate = 500000; // 500 Kbps минимум
          encoding.maxFramerate = 30;
          encoding.scaleResolutionDownBy = 1.0;
        }

        await sender.setParameters(params);
        logInfo('Sender parameters optimized successfully');
      }
    } catch (e, stackTrace) {
      logError('Error optimizing sender parameters: $e', stackTrace);
    }
  }

  void setupConnectionStateHandlers(
      rtc.RTCPeerConnection pc, {
        required VoidCallback? onConnected,
        required VoidCallback? onDisconnected,
        required VoidCallback? onFailed,
      }) {
    pc.onConnectionState = (state) {
      logInfo('Connection state changed to: $state');

      switch (state) {
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          logInfo('Successfully connected');
          onConnected?.call();
          break;
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          logError('Connection failed');
          onFailed?.call();
          break;
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          logWarning('Connection disconnected');
          onDisconnected?.call();
          break;
        default:
          break;
      }
    };
  }

  void setupIceConnectionStateHandlers(
      rtc.RTCPeerConnection pc, {
        required VoidCallback? onConnected,
        required VoidCallback? onDisconnected,
        required VoidCallback? onFailed,
      }) {
    pc.onIceConnectionState = (state) {
      logInfo('ICE connection state changed to: $state');

      switch (state) {
        case rtc.RTCIceConnectionState.RTCIceConnectionStateConnected:
          logInfo('ICE connection established');
          onConnected?.call();
          break;
        case rtc.RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          logWarning('ICE connection disconnected');
          onDisconnected?.call();
          break;
        case rtc.RTCIceConnectionState.RTCIceConnectionStateFailed:
          logError('ICE connection failed');
          onFailed?.call();
          break;
        default:
          break;
      }
    };
  }

  void setupIceCandidateHandler(
      rtc.RTCPeerConnection pc, {
        required Function(rtc.RTCIceCandidate) onCandidate,
        required VoidCallback? onGatheringComplete,
      }) {
    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        logInfo('New ICE candidate: ${candidate.candidate}');
        onCandidate(candidate);
      } else {
        logInfo('ICE gathering completed');
        onGatheringComplete?.call();
      }
    };
  }

  void setupTrackHandler(
      rtc.RTCPeerConnection pc, {
        required Function(rtc.MediaStreamTrack, List<rtc.MediaStream>) onTrack,
      }) {
    pc.onTrack = (event) {
      logInfo('Track received: ${event.track.kind}');
      logInfo('Track enabled: ${event.track.enabled}, muted: ${event.track.muted}');
      logInfo('Streams count: ${event.streams.length}');

      onTrack(event.track, event.streams);
    };
  }

  Future<void> addStreamTracks(
      rtc.RTCPeerConnection pc,
      rtc.MediaStream stream,
      List<rtc.RTCRtpSender> senders,
      ) async {
    try {
      logInfo('Adding tracks to connection...');
      final tracks = stream.getTracks();
      logInfo('Stream tracks: ${tracks.length}');

      for (final track in tracks) {
        logInfo('Adding track: ${track.kind}, enabled: ${track.enabled}');
        final rtpSender = await pc.addTrack(track, stream);
        if (rtpSender != null) {
          senders.add(rtpSender);
          await optimizeSenderParameters(rtpSender);
        }
      }

      logInfo('All tracks added successfully');
    } catch (e, stackTrace) {
      logError('Error adding stream tracks: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> closeConnection(rtc.RTCPeerConnection? pc) async {
    if (pc != null) {
      try {
        logInfo('Closing peer connection');
        await pc.close();
        logInfo('Peer connection closed successfully');
      } catch (e, stackTrace) {
        logError('Error closing peer connection: $e', stackTrace);
      }
    }
  }

  Future<void> closeDataChannel(rtc.RTCDataChannel? channel) async {
    if (channel != null) {
      try {
        logInfo('Closing data channel: ${channel.label}');
        await channel.close();
        logInfo('Data channel closed successfully');
      } catch (e, stackTrace) {
        logError('Error closing data channel: $e', stackTrace);
      }
    }
  }
}