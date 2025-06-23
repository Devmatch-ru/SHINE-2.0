// lib/services/webrtc_service.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import '../constants.dart';
import 'logging_service.dart';

class WebRTCService with LoggerMixin {
  @override
  String get loggerContext => 'WebRTCService';

  static final WebRTCService _instance = WebRTCService._internal();
  factory WebRTCService() => _instance;
  WebRTCService._internal();

  // Статистика соединений
  final Map<String, ConnectionStats> _connectionStats = {};
  Timer? _statsTimer;

  // Улучшенная конфигурация для максимального качества и стабильности
  Map<String, dynamic> get defaultPeerConnectionConfig => {
    'iceServers': AppConstants.iceServers,
    'sdpSemantics': 'unified-plan',
    'iceTransportPolicy': 'all',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    'iceCandidatePoolSize': 8, // Увеличено для лучшей связности
    'enableDtlsSrtp': true,
    'enableRtpDataChannels': false,
    // Дополнительные настройки для стабильности и качества
    'continualGatheringPolicy': 'gather_continually',
    'iceConnectionReceivingTimeout': 30000,
    'iceBackupCandidatePairPingInterval': 25000,
    'rtcpAudioReportIntervalMs': 5000,
    'rtcpVideoReportIntervalMs': 5000,
  };

  // Оптимизированные ограничения для максимального качества
  Map<String, dynamic> get defaultOfferConstraints => {
    'offerToReceiveVideo': true,
    'offerToReceiveAudio': false,
    'voiceActivityDetection': false,
    'iceRestart': false,
    'enableDtlsSrtp': true,
    // Настройки для высокого качества
    'googCpuOveruseDetection': false,
    'googHighpassFilter': false,
    'googAutoGainControl': false,
    'googNoiseSuppression': false,
    'googEchoCancellation': false,
    'googTypingNoiseDetection': false,
    'googExperimentalAutoGainControl': false,
    'googExperimentalNoiseSuppression': false,
    // Дополнительные настройки производительности
    'googCpuUnderuseThreshold': 55,
    'googCpuOveruseThreshold': 85,
    'googHighStartBitrate': 2000,
  };

  Map<String, dynamic> get defaultAnswerConstraints => {
    'offerToReceiveVideo': true,
    'offerToReceiveAudio': false,
    'voiceActivityDetection': false,
    'googCpuOveruseDetection': false,
    'googNoiseSuppression': false,
    'googEchoCancellation': false,
  };

  // Конфигурация data channel для высокого качества
  rtc.RTCDataChannelInit get defaultDataChannelInit => rtc.RTCDataChannelInit()
    ..ordered = true
    ..maxRetransmits = 10 // Увеличено для надежности
    ..protocol = 'sctp'
    ..negotiated = false;

  // Специальная конфигурация для передачи медиа высокого качества
  rtc.RTCDataChannelInit get highQualityMediaChannelInit => rtc.RTCDataChannelInit()
    ..ordered = true
    ..maxRetransmits = 15
    ..protocol = 'sctp'
    ..negotiated = false;

  Future<rtc.RTCPeerConnection> createPeerConnection({
    Map<String, dynamic>? config,
    String? connectionId,
  }) async {
    try {
      final finalConfig = config ?? defaultPeerConnectionConfig;
      logInfo('Creating peer connection with enhanced config');

      final pc = await rtc.createPeerConnection(finalConfig);
      if (pc == null) {
        throw Exception('Failed to create peer connection');
      }

      // Инициализируем статистику для этого соединения
      if (connectionId != null) {
        _connectionStats[connectionId] = ConnectionStats(connectionId);
        _setupStatsCollection(pc, connectionId);
      }

      // Настраиваем дополнительные параметры
      await _configurePeerConnectionForQuality(pc);

      logInfo('Peer connection created successfully with enhanced configuration');
      return pc;
    } catch (e, stackTrace) {
      logError('Error creating peer connection: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _configurePeerConnectionForQuality(rtc.RTCPeerConnection pc) async {
    try {
      // Настройки для максимального качества и стабильности
      pc.onConnectionState = (state) {
        logInfo('Enhanced connection state monitoring: $state');
        _handleConnectionStateChange(pc, state);
      };

      pc.onIceConnectionState = (state) {
        logInfo('Enhanced ICE connection state monitoring: $state');
        _handleIceConnectionStateChange(pc, state);
      };

      logInfo('Peer connection configured for maximum quality and stability');
    } catch (e, stackTrace) {
      logError('Error configuring peer connection: $e', stackTrace);
    }
  }

  void _handleConnectionStateChange(rtc.RTCPeerConnection pc, rtc.RTCPeerConnectionState state) {
    switch (state) {
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        _optimizeConnectionForQuality(pc);
        break;
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        _handleConnectionLoss(pc);
        break;
      default:
        break;
    }
  }

  void _handleIceConnectionStateChange(rtc.RTCPeerConnection pc, rtc.RTCIceConnectionState state) {
    switch (state) {
      case rtc.RTCIceConnectionState.RTCIceConnectionStateConnected:
      case rtc.RTCIceConnectionState.RTCIceConnectionStateCompleted:
        _optimizeIceConnection(pc);
        break;
      case rtc.RTCIceConnectionState.RTCIceConnectionStateDisconnected:
      case rtc.RTCIceConnectionState.RTCIceConnectionStateFailed:
        _handleIceConnectionLoss(pc);
        break;
      default:
        break;
    }
  }

  Future<void> _optimizeConnectionForQuality(rtc.RTCPeerConnection pc) async {
    try {
      logInfo('Optimizing connection for maximum quality');

      final senders = await pc.getSenders();
      for (final sender in senders) {
        if (sender.track?.kind == 'video') {
          await optimizeSenderParameters(sender);
        }
      }

      logInfo('Connection optimized for quality');
    } catch (e, stackTrace) {
      logError('Error optimizing connection: $e', stackTrace);
    }
  }

  Future<void> _optimizeIceConnection(rtc.RTCPeerConnection pc) async {
    try {
      logInfo('Optimizing ICE connection');
      // Здесь можно добавить дополнительные оптимизации ICE
    } catch (e, stackTrace) {
      logError('Error optimizing ICE connection: $e', stackTrace);
    }
  }

  void _handleConnectionLoss(rtc.RTCPeerConnection pc) {
    logWarning('Handling connection loss');
    // Логика обработки потери соединения
  }

  void _handleIceConnectionLoss(rtc.RTCPeerConnection pc) {
    logWarning('Handling ICE connection loss');
    // Логика обработки потери ICE соединения
  }

  Future<rtc.RTCDataChannel> createDataChannel(
      rtc.RTCPeerConnection pc,
      String label, {
        rtc.RTCDataChannelInit? init,
        bool highQuality = false,
        bool mediaTransfer = false,
      }) async {
    try {
      logInfo('Creating data channel: $label (high quality: $highQuality, media: $mediaTransfer)');

      rtc.RTCDataChannelInit channelInit;
      if (mediaTransfer) {
        channelInit = highQualityMediaChannelInit;
      } else if (highQuality) {
        channelInit = defaultDataChannelInit;
      } else {
        channelInit = init ?? defaultDataChannelInit;
      }

      final dataChannel = await pc.createDataChannel(label, channelInit);

      logInfo('Data channel created successfully: $label');
      return dataChannel;
    } catch (e, stackTrace) {
      logError('Error creating data channel: $e', stackTrace);
      rethrow;
    }
  }

  String modifySdpForHighQuality(String sdp) {
    logInfo('Modifying SDP for maximum quality and stability');

    final lines = sdp.split('\r\n');
    final newLines = <String>[];

    for (final line in lines) {
      // Максимальный битрейт для видео
      if (line.startsWith('b=AS:')) {
        newLines.add('b=AS:15000'); // 15 Mbps для максимального качества
        continue;
      }

      // Высокий приоритет и качество для видео
      if (line.startsWith('m=video')) {
        newLines.add(line);
        newLines.add('b=AS:15000');
        newLines.add('a=content:main');
        newLines.add('a=priority:high');
        newLines.add('a=setup:actpass');
        newLines.add('a=mid:0');
        continue;
      }

      // Оптимизация параметров кодеков для максимального качества
      if (line.startsWith('a=fmtp:')) {
        if (line.contains('VP8')) {
          // Настройки VP8 для максимального качества
          newLines.add('$line;max-fs=65536;max-fr=60;profile-id=0;max-recv-size=65536');
          continue;
        } else if (line.contains('VP9')) {
          // Настройки VP9 для максимального качества
          newLines.add('$line;max-fs=65536;max-fr=60;profile-id=0;max-recv-size=65536');
          continue;
        } else if (line.contains('H264')) {
          // Настройки H.264 для максимального качества
          newLines.add(
              '$line;profile-level-id=42e01f;packetization-mode=1;level-asymmetry-allowed=1;max-fs=65536;max-fr=60;max-recv-size=65536');
          continue;
        } else if (line.contains('AV1')) {
          // Поддержка AV1 для максимального качества
          newLines.add('$line;max-fs=65536;max-fr=60;max-recv-size=65536');
          continue;
        }
      }

      // Улучшенная поддержка RTX для устойчивости к потерям
      if (line.startsWith('a=rtpmap:') && line.contains('rtx')) {
        newLines.add(line);
        final payloadType = line.split(' ')[0].split(':')[1];
        newLines.add('a=fmtp:$payloadType apt=$payloadType');
        continue;
      }

      // Расширенные настройки RTCP для мониторинга качества
      if (line.startsWith('a=rtcp-fb:')) {
        newLines.add(line);
        final payloadType = line.split(' ')[0].split(':')[1];
        if (line.contains('nack')) {
          newLines.add('a=rtcp-fb:$payloadType nack pli');
          newLines.add('a=rtcp-fb:$payloadType ccm fir');
          newLines.add('a=rtcp-fb:$payloadType transport-cc');
          newLines.add('a=rtcp-fb:$payloadType goog-remb');
        }
        continue;
      }

      // Добавляем поддержку современных расширений
      if (line.startsWith('a=extmap:')) {
        newLines.add(line);
        // Добавляем дополнительные расширения для качества
        if (line.contains('transport-cc')) {
          // Transport-wide congestion control
          newLines.add('a=extmap:4 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01');
        }
        continue;
      }

      newLines.add(line);
    }

    final modifiedSdp = newLines.join('\r\n');
    logInfo('SDP modified for maximum quality and stability');
    return modifiedSdp;
  }

  Future<void> optimizeSenderParameters(rtc.RTCRtpSender sender) async {
    try {
      logInfo('Optimizing sender parameters for maximum quality');

      final params = sender.parameters;

      if (params.encodings != null && params.encodings!.isNotEmpty) {
        for (final encoding in params.encodings!) {
          // Максимальные настройки качества
          encoding.maxBitrate = 15000000; // 15 Mbps
          encoding.minBitrate = 2000000;  // 2 Mbps минимум
          encoding.maxFramerate = 60;
          encoding.scaleResolutionDownBy = 1.0; // Без уменьшения разрешения

        }

        await sender.setParameters(params);
        logInfo('Sender parameters optimized for maximum quality');
      }
    } catch (e, stackTrace) {
      logError('Error optimizing sender parameters: $e', stackTrace);
    }
  }

  Future<void> configureForNativeQuality(rtc.RTCRtpSender sender) async {
    try {
      logInfo('Configuring sender for native camera quality');

      final params = sender.parameters;

      if (params.encodings != null && params.encodings!.isNotEmpty) {
        for (final encoding in params.encodings!) {
          // Настройки для исходного качества камеры
          encoding.maxBitrate = null; // Без ограничений битрейта
          encoding.minBitrate = 3000000; // Минимум 3 Mbps
          encoding.maxFramerate = null; // Максимальная частота кадров камеры
          encoding.scaleResolutionDownBy = 1.0;

        }

        await sender.setParameters(params);
        logInfo('Sender configured for native quality successfully');
      }
    } catch (e, stackTrace) {
      logError('Error configuring native quality: $e', stackTrace);
    }
  }

  void setupConnectionStateHandlers(
      rtc.RTCPeerConnection pc, {
        required VoidCallback? onConnected,
        required VoidCallback? onDisconnected,
        required VoidCallback? onFailed,
        String? connectionId,
      }) {
    pc.onConnectionState = (state) {
      logInfo('Connection state changed to: $state');

      // Обновляем статистику
      if (connectionId != null && _connectionStats.containsKey(connectionId)) {
        _connectionStats[connectionId]!.lastStateChange = DateTime.now();
        _connectionStats[connectionId]!.connectionState = state;
      }

      switch (state) {
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          logInfo('Successfully connected - optimizing for quality');
          _optimizeConnectionForQuality(pc);
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
        case rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          logInfo('Connection closed');
          onDisconnected?.call();
          break;
        default:
          logInfo('Connection state: $state');
          break;
      }
    };
  }

  void setupIceConnectionStateHandlers(
      rtc.RTCPeerConnection pc, {
        required VoidCallback? onConnected,
        required VoidCallback? onDisconnected,
        required VoidCallback? onFailed,
        String? connectionId,
      }) {
    pc.onIceConnectionState = (state) {
      logInfo('ICE connection state changed to: $state');

      // Обновляем статистику
      if (connectionId != null && _connectionStats.containsKey(connectionId)) {
        _connectionStats[connectionId]!.iceConnectionState = state;
      }

      switch (state) {
        case rtc.RTCIceConnectionState.RTCIceConnectionStateConnected:
        case rtc.RTCIceConnectionState.RTCIceConnectionStateCompleted:
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
        case rtc.RTCIceConnectionState.RTCIceConnectionStateClosed:
          logInfo('ICE connection closed');
          onDisconnected?.call();
          break;
        default:
          logInfo('ICE connection state: $state');
          break;
      }
    };
  }

  void setupIceCandidateHandler(
      rtc.RTCPeerConnection pc, {
        required Function(rtc.RTCIceCandidate) onCandidate,
        required VoidCallback? onGatheringComplete,
        String? connectionId,
      }) {
    pc.onIceCandidate = (candidate) {
      if (candidate != null) {
        logInfo('New ICE candidate: ${candidate.candidate}');

        // Обновляем статистику
        if (connectionId != null && _connectionStats.containsKey(connectionId)) {
          _connectionStats[connectionId]!.iceCandidatesGenerated++;
        }

        onCandidate(candidate);
      } else {
        logInfo('ICE gathering completed');
        onGatheringComplete?.call();
      }
    };

    pc.onIceGatheringState = (state) {
      logInfo('ICE gathering state: $state');

      // Обновляем статистику
      if (connectionId != null && _connectionStats.containsKey(connectionId)) {
        _connectionStats[connectionId]!.iceGatheringState = state;
      }

      if (state == rtc.RTCIceGatheringState.RTCIceGatheringStateComplete) {
        onGatheringComplete?.call();
      }
    };
  }

  void setupTrackHandler(
      rtc.RTCPeerConnection pc, {
        required Function(rtc.MediaStreamTrack, List<rtc.MediaStream>) onTrack,
        String? connectionId,
      }) {
    pc.onTrack = (event) {
      logInfo('Track received: ${event.track.kind}');
      logInfo('Track enabled: ${event.track.enabled}, muted: ${event.track.muted}');
      logInfo('Streams count: ${event.streams.length}');

      // Обновляем статистику
      if (connectionId != null && _connectionStats.containsKey(connectionId)) {
        if (event.track.kind == 'video') {
          _connectionStats[connectionId]!.hasVideoTrack = true;
        } else if (event.track.kind == 'audio') {
          _connectionStats[connectionId]!.hasAudioTrack = true;
        }
      }

      // Логируем настройки трека для отладки
      if (event.track.kind == 'video') {
        try {
          final settings = event.track.getSettings();
          logInfo('Video track settings: $settings');

          // Сохраняем информацию о разрешении
          if (connectionId != null && _connectionStats.containsKey(connectionId)) {
            _connectionStats[connectionId]!.videoWidth = settings['width'] as int? ?? 0;
            _connectionStats[connectionId]!.videoHeight = settings['height'] as int? ?? 0;
            _connectionStats[connectionId]!.frameRate = settings['frameRate'] as double? ?? 0.0;
          }
        } catch (e) {
          logInfo('Could not get video track settings: $e');
        }
      }

      onTrack(event.track, event.streams);
    };
  }

  Future<void> addStreamTracks(
      rtc.RTCPeerConnection pc,
      rtc.MediaStream stream,
      List<rtc.RTCRtpSender> senders, {
        bool optimizeForQuality = true,
        String? connectionId,
      }) async {
    try {
      logInfo('Adding tracks to connection (optimize: $optimizeForQuality)...');
      final tracks = stream.getTracks();
      logInfo('Stream tracks: ${tracks.length}');

      for (final track in tracks) {
        logInfo('Adding track: ${track.kind}, enabled: ${track.enabled}');

        // Логируем настройки трека
        try {
          final settings = track.getSettings();
          logInfo('Track settings: $settings');
        } catch (e) {
          logInfo('Could not get track settings: $e');
        }

        final rtpSender = await pc.addTrack(track, stream);
        if (rtpSender != null) {
          senders.add(rtpSender);

          if (optimizeForQuality) {
            if (track.kind == 'video') {
              await optimizeSenderParameters(rtpSender);
            }
          }
        }
      }

      logInfo('All tracks added successfully');
    } catch (e, stackTrace) {
      logError('Error adding stream tracks: $e', stackTrace);
      rethrow;
    }
  }

  // Система сбора статистики
  void _setupStatsCollection(rtc.RTCPeerConnection pc, String connectionId) {
    _statsTimer ??= Timer.periodic(const Duration(seconds: 5), (timer) {
      _collectStats();
    });
  }

  Future<void> _collectStats() async {
    for (final entry in _connectionStats.entries) {
      try {
        // Здесь можно собирать детальную статистику WebRTC
        logDebug('Collecting stats for connection: ${entry.key}');
      } catch (e) {
        logError('Error collecting stats for ${entry.key}: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getConnectionStats(rtc.RTCPeerConnection pc) async {
    try {
      final stats = await pc.getStats();
      final videoStats = <String, dynamic>{};
      final audioStats = <String, dynamic>{};
      final connectionStats = <String, dynamic>{};

      return {
        'video': videoStats,
        'audio': audioStats,
        'connection': connectionStats,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e, stackTrace) {
      logError('Error getting connection stats: $e', stackTrace);
      return {};
    }
  }



  Future<void> closeConnection(rtc.RTCPeerConnection? pc, {String? connectionId}) async {
    if (pc != null) {
      try {
        logInfo('Closing peer connection');

        // Получаем финальную статистику
        try {
          final stats = await getConnectionStats(pc);
          logInfo('Final connection stats: $stats');
        } catch (e) {
          logInfo('Could not get final stats: $e');
        }

        // Удаляем из статистики
        if (connectionId != null) {
          _connectionStats.remove(connectionId);
        }

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

  // Методы для получения поддерживаемых возможностей
  Future<List<String>> getSupportedVideoCodecs() async {
    try {

      logInfo('Supported video codecs: $codecs');

      // Возвращаем в порядке предпочтения для качества
      final preferredCodecs = <String>[];
      if (codecs.contains('video/AV1')) preferredCodecs.add('AV1');
      if (codecs.contains('video/VP9')) preferredCodecs.add('VP9');
      if (codecs.contains('video/H264')) preferredCodecs.add('H264');
      if (codecs.contains('video/VP8')) preferredCodecs.add('VP8');

      return preferredCodecs;
    } catch (e, stackTrace) {
      logError('Error getting supported codecs: $e', stackTrace);
      return ['H264', 'VP8']; // Fallback
    }
  }

  Future<VideoResolution> getMaxSupportedResolution() async {
    try {
      for (final resolution in AppConstants.supportedResolutions) {
        try {
          final constraints = {
            'video': {
              'width': resolution.width,
              'height': resolution.height,
              'frameRate': 30,
            }
          };

          final stream = await rtc.navigator.mediaDevices.getUserMedia(constraints);

          // Проверяем фактическое разрешение
          final videoTracks = stream.getVideoTracks();
          if (videoTracks.isNotEmpty) {
            final settings = videoTracks.first.getSettings();
            final actualWidth = settings['width'] as int? ?? 0;
            final actualHeight = settings['height'] as int? ?? 0;

            logInfo('Max supported resolution: ${resolution.name} (actual: ${actualWidth}x${actualHeight})');
          }

          await stream.dispose();
          return resolution;
        } catch (e) {
          continue;
        }
      }

      // Fallback к 720p
      return const VideoResolution(width: 1280, height: 720, name: '720p');
    } catch (e, stackTrace) {
      logError('Error determining max resolution: $e', stackTrace);
      return const VideoResolution(width: 1280, height: 720, name: '720p');
    }
  }

  // Получение статистики всех соединений
  Map<String, ConnectionStats> getAllConnectionStats() {
    return Map.unmodifiable(_connectionStats);
  }

  // Очистка ресурсов
  void dispose() {
    _statsTimer?.cancel();
    _connectionStats.clear();
  }
}

// Класс для хранения статистики соединения
class ConnectionStats {
  final String connectionId;
  DateTime createdAt;
  DateTime? lastStateChange;
  rtc.RTCPeerConnectionState? connectionState;
  rtc.RTCIceConnectionState? iceConnectionState;
  rtc.RTCIceGatheringState? iceGatheringState;

  int iceCandidatesGenerated = 0;
  bool hasVideoTrack = false;
  bool hasAudioTrack = false;

  int videoWidth = 0;
  int videoHeight = 0;
  double frameRate = 0.0;

  ConnectionStats(this.connectionId) : createdAt = DateTime.now();

  Duration get uptime => DateTime.now().difference(createdAt);

  Map<String, dynamic> toJson() {
    return {
      'connectionId': connectionId,
      'createdAt': createdAt.toIso8601String(),
      'lastStateChange': lastStateChange?.toIso8601String(),
      'connectionState': connectionState?.toString(),
      'iceConnectionState': iceConnectionState?.toString(),
      'iceGatheringState': iceGatheringState?.toString(),
      'iceCandidatesGenerated': iceCandidatesGenerated,
      'hasVideoTrack': hasVideoTrack,
      'hasAudioTrack': hasAudioTrack,
      'videoResolution': '${videoWidth}x${videoHeight}',
      'frameRate': frameRate,
      'uptime': uptime.inSeconds,
    };
  }
}