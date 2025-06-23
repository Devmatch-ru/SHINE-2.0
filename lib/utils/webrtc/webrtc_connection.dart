// lib/utils/webrtc/webrtc_connection.dart (Updated)
import 'dart:async';
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:shine/utils/webrtc/types.dart';

import '../service/command_service.dart';
import '../service/logging_service.dart';
import '../service/media_service.dart';
import '../service/webrtc_service.dart';
class WebRTCConnection with LoggerMixin {
  @override
  String get loggerContext => 'WebRTCConnection';

  // Services
  final CommandService _commandService = CommandService();
  final WebRTCService _webrtcService = WebRTCService();
  final MediaService _mediaService = MediaService();

  // WebRTC state
  RTCPeerConnection? _pc;
  final List<RTCIceCandidate> _candidates = [];
  RTCSessionDescription? _offer;
  final List<RTCRtpSender> _senders = [];
  final Map<RTCPeerConnection, RTCDataChannel> _dataChannels = {};
  MediaStream? _remoteStream;

  // Connection stability and monitoring
  bool _isStable = false;
  DateTime _lastStableTime = DateTime.now();
  DateTime _lastDataChannelActivity = DateTime.now();
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 3;

  // Health monitoring
  Timer? _healthCheckTimer;
  Timer? _dataChannelPingTimer;
  final Map<String, int> _commandStats = {};
  final Map<String, DateTime> _lastCommandTimes = {};

  // Callbacks
  final VoidCallback? onStateChange;
  final VoidCallback? onCapturePhoto;
  final VoidCallback? onStartVideo;
  final VoidCallback? onStopVideo;
  final void Function(RTCIceCandidate)? onIceCandidate;
  final void Function()? onConnectionFailed;
  final void Function(MediaType type, String base64Data)? onMediaReceived;
  final void Function(MediaStream)? onRemoteStream;
  final void Function(String command)? onCommandReceived;
  final void Function(String quality)? onQualityChangeRequested;
  final void Function(String fileName, String mediaType, int sentChunks,
      int totalChunks, bool isCompleted)? onTransferProgress;

  WebRTCConnection({
    this.onStateChange,
    this.onCapturePhoto,
    this.onStartVideo,
    this.onStopVideo,
    this.onIceCandidate,
    this.onConnectionFailed,
    this.onMediaReceived,
    this.onRemoteStream,
    this.onCommandReceived,
    this.onQualityChangeRequested,
    this.onTransferProgress,
  });

  // Getters
  RTCSessionDescription? get offer => _offer;
  List<RTCIceCandidate> get candidates => _candidates;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected =>
      _pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          _isStable &&
          _hasActiveDataChannel();

  bool _hasActiveDataChannel() {
    return _dataChannels.values.any(
            (channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen
    );
  }

  Future<void> createConnection(MediaStream? localStream, {bool isBroadcaster = true}) async {
    try {
      logInfo('Creating WebRTC connection (isBroadcaster: $isBroadcaster)');

      _pc = await _webrtcService.createPeerConnection();
      _setupConnectionHandlers();

      if (isBroadcaster && localStream != null) {
        await _setupBroadcasterConnection(localStream);
      }

      // Start health monitoring
      _startHealthMonitoring();

      logInfo('WebRTC connection created successfully');
    } catch (e, stackTrace) {
      logError('Error creating connection: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _setupBroadcasterConnection(MediaStream localStream) async {
    try {
      logInfo('Setting up broadcaster connection...');

      // Add tracks to connection
      await _webrtcService.addStreamTracks(_pc!, localStream, _senders);

      // Create data channel for commands with enhanced configuration
      final dataChannel = await _webrtcService.createDataChannel(_pc!, 'commands');
      _dataChannels[_pc!] = dataChannel;
      _setupDataChannel(dataChannel);

      // Create optimized offer
      logInfo('Creating optimized offer...');
      _offer = await _pc!.createOffer(_webrtcService.defaultOfferConstraints);

      if (_offer != null) {
        // Modify SDP for high quality and stability
        final modifiedSdp = _webrtcService.modifySdpForHighQuality(_offer!.sdp!);
        _offer = RTCSessionDescription(modifiedSdp, _offer!.type);

        logInfo('Setting local description...');
        await _pc!.setLocalDescription(_offer!);
        logInfo('Local description set successfully');
      }
    } catch (e, stackTrace) {
      logError('Error setting up broadcaster connection: $e', stackTrace);
      rethrow;
    }
  }

  void _startHealthMonitoring() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _performHealthCheck();
    });

    _dataChannelPingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _sendDataChannelPing();
    });
  }

  void _performHealthCheck() {
    if (_pc == null) {
      _healthCheckTimer?.cancel();
      return;
    }

    final now = DateTime.now();

    // Check overall connection health
    final isConnectionHealthy = _pc!.connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected;

    final isIceHealthy = _pc!.iceConnectionState ==
        RTCIceConnectionState.RTCIceConnectionStateConnected ||
        _pc!.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateCompleted;

    // Check data channel activity
    final dataChannelStale = now.difference(_lastDataChannelActivity).inSeconds > 30;

    if (!isConnectionHealthy || !isIceHealthy) {
      logWarning('Connection health check failed - Connection: $isConnectionHealthy, ICE: $isIceHealthy');
      _handleConnectionDegradation();
    } else if (dataChannelStale && _hasActiveDataChannel()) {
      logWarning('Data channel appears stale, attempting to refresh');
      _refreshDataChannels();
    } else {
      _isStable = true;
      _lastStableTime = now;
    }
  }

  void _sendDataChannelPing() {
    try {
      final activeChannels = _dataChannels.values
          .where((channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);

      for (final channel in activeChannels) {
        final pingMessage = jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });

        channel.send(RTCDataChannelMessage(pingMessage));
        logDebug('Sent ping through data channel');
      }
    } catch (e) {
      logWarning('Failed to send data channel ping: $e');
    }
  }

  void _handleConnectionDegradation() {
    _isStable = false;

    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      logInfo('Attempting connection recovery (attempt $_reconnectAttempts/$maxReconnectAttempts)');

      Future.delayed(Duration(seconds: _reconnectAttempts * 2), () {
        _attemptConnectionRecovery();
      });
    } else {
      logError('Max recovery attempts reached, calling onConnectionFailed');
      onConnectionFailed?.call();
    }
  }

  Future<void> _attemptConnectionRecovery() async {
    try {
      logInfo('Attempting to recover connection...');

      // Try ICE restart first
      if (_pc?.connectionState != RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        await _pc?.restartIce();

        // Give some time for recovery
        await Future.delayed(const Duration(seconds: 3));

        if (_pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          logInfo('Connection recovery successful via ICE restart');
          _isStable = true;
          _lastStableTime = DateTime.now();
          _reconnectAttempts = 0;
          onStateChange?.call();
          return;
        }
      }

      // If ICE restart didn't work, try recreating data channels
      await _refreshDataChannels();

    } catch (e, stackTrace) {
      logError('Error during connection recovery: $e', stackTrace);
      _handleConnectionDegradation();
    }
  }

  Future<void> _refreshDataChannels() async {
    try {
      logInfo('Refreshing data channels...');

      // Close existing data channels
      for (final channel in _dataChannels.values) {
        await _webrtcService.closeDataChannel(channel);
      }
      _dataChannels.clear();

      // Create new data channel
      if (_pc != null && _pc!.connectionState ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {

        final newDataChannel = await _webrtcService.createDataChannel(_pc!, 'commands');
        _dataChannels[_pc!] = newDataChannel;
        _setupDataChannel(newDataChannel);

        logInfo('Data channels refreshed successfully');
      }
    } catch (e, stackTrace) {
      logError('Error refreshing data channels: $e', stackTrace);
    }
  }

  void _setupConnectionHandlers() {
    if (_pc == null) return;

    // Setup connection state handlers with improved stability
    _webrtcService.setupConnectionStateHandlers(
      _pc!,
      onConnected: () {
        logInfo('PeerConnection state: CONNECTED');
        _isStable = true;
        _lastStableTime = DateTime.now();
        _reconnectAttempts = 0;
        onStateChange?.call();
      },
      onDisconnected: () {
        logWarning('PeerConnection state: DISCONNECTED');
        _isStable = false;

        // Give a short grace period before considering it failed
        Future.delayed(const Duration(seconds: 2), () {
          if (_pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
            _handleConnectionDegradation();
          }
        });
      },
      onFailed: () {
        logError('PeerConnection state: FAILED');
        _isStable = false;
        _handleConnectionDegradation();
      },
    );

    // Setup ICE connection state handlers
    _webrtcService.setupIceConnectionStateHandlers(
      _pc!,
      onConnected: () {
        logInfo('ICE connection state: CONNECTED/COMPLETED');
        _isStable = true;
        _lastStableTime = DateTime.now();
      },
      onDisconnected: () {
        logWarning('ICE connection state: DISCONNECTED');
        _isStable = false;

        // ICE connections can recover, give more time
        Future.delayed(const Duration(seconds: 5), () {
          if (_pc?.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
              _pc?.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            _handleConnectionDegradation();
          }
        });
      },
      onFailed: () {
        logError('ICE connection state: FAILED');
        _isStable = false;
        _handleConnectionDegradation();
      },
    );

    // Setup ICE candidate handler
    _webrtcService.setupIceCandidateHandler(
      _pc!,
      onCandidate: (candidate) {
        _candidates.add(candidate);
        onIceCandidate?.call(candidate);
      },
      onGatheringComplete: () {
        logInfo('ICE gathering completed');
      },
    );

    // Setup track handler
    _webrtcService.setupTrackHandler(
      _pc!,
      onTrack: (track, streams) {
        logInfo('Track received: ${track.kind}');

        if (track.kind == 'video' && streams.isNotEmpty) {
          _remoteStream = streams[0];
          logInfo('Remote stream set with ID: ${_remoteStream!.id}');
          onRemoteStream?.call(_remoteStream!);
        }
      },
    );

    // Setup data channel handler
    _pc!.onDataChannel = (channel) {
      logInfo('Data channel received: ${channel.label}');
      _dataChannels[_pc!] = channel;
      _setupDataChannel(channel);
    };

    // Add direct state monitoring
    _pc!.onConnectionState = (state) {
      logInfo('Direct PeerConnection state: $state');
    };

    _pc!.onIceConnectionState = (state) {
      logInfo('Direct ICE connection state: $state');
    };
  }

  void _setupDataChannel(RTCDataChannel channel) {
    logInfo('Setting up data channel: ${channel.label}');

    channel.onDataChannelState = (state) {
      logInfo('Data channel state changed to: $state');

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        logInfo('Data channel is now OPEN and ready for communication');
        _lastDataChannelActivity = DateTime.now();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        logWarning('Data channel is now CLOSED');

        // Try to recreate data channel if main connection is still active
        if (_pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          Future.delayed(const Duration(seconds: 1), () {
            _refreshDataChannels();
          });
        }
      }
    };

    channel.onMessage = (message) {
      _lastDataChannelActivity = DateTime.now();
      _handleDataChannelMessage(message);
    };
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    if (message.type == MessageType.text) {
      try {
        logDebug('Received message: ${message.text}');

        final data = jsonDecode(message.text);
        final messageType = data['type'] as String?;

        switch (messageType) {
          case 'ping':
            _handlePingMessage(data);
            break;
          case 'pong':
            _handlePongMessage(data);
            break;
          case 'command':
            _handleCommandMessage(data);
            break;
          case 'quality_change':
            _handleQualityChangeMessage(data);
            break;
          case 'media':
            _handleMediaMessage(data);
            break;
          default:
            logWarning('Unknown message type: $messageType');
        }
      } catch (e, stackTrace) {
        logError('Error processing message: $e', stackTrace);
      }
    }
  }

  void _handlePingMessage(Map<String, dynamic> data) {
    try {
      // Respond to ping with pong
      final pongMessage = jsonEncode({
        'type': 'pong',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'original_timestamp': data['timestamp'],
      });

      final activeChannels = _dataChannels.values
          .where((channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);

      for (final channel in activeChannels) {
        channel.send(RTCDataChannelMessage(pongMessage));
      }

      logDebug('Responded to ping with pong');
    } catch (e) {
      logWarning('Failed to respond to ping: $e');
    }
  }

  void _handlePongMessage(Map<String, dynamic> data) {
    final originalTimestamp = data['original_timestamp'] as int?;
    if (originalTimestamp != null) {
      final latency = DateTime.now().millisecondsSinceEpoch - originalTimestamp;
      logDebug('Received pong - latency: ${latency}ms');
    }
  }

  void _handleCommandMessage(Map<String, dynamic> data) {
    final command = _commandService.parseCommand(jsonEncode(data));
    if (command != null) {
      _recordCommandStats(command.type.value);
      _handleCommand(command);
    }
  }

  void _handleQualityChangeMessage(Map<String, dynamic> data) {
    final qualityChange = _commandService.parseQualityChange(jsonEncode(data));
    if (qualityChange != null) {
      logInfo('Received quality change request: ${qualityChange.quality}');

      // Add delay for smooth quality transitions
      Future.delayed(const Duration(milliseconds: 200), () {
        onQualityChangeRequested?.call(qualityChange.quality);
      });
    }
  }

  void _handleMediaMessage(Map<String, dynamic> data) {
    final mediaType = data['mediaType'] as String?;
    final mediaData = data['data'] as String?;

    if (mediaType != null && mediaData != null) {
      final type = mediaType == 'photo' ? MediaType.photo : MediaType.video;
      onMediaReceived?.call(type, mediaData);
    }
  }

  void _recordCommandStats(String command) {
    _commandStats[command] = (_commandStats[command] ?? 0) + 1;
    _lastCommandTimes[command] = DateTime.now();
  }

  void _handleCommand(AppCommand command) {
    logInfo('Received command: ${command.type.value}');

    // Add command processing delay for stability
    Future.delayed(const Duration(milliseconds: 100), () {
      onCommandReceived?.call(command.type.value);

      switch (command.type) {
        case CommandType.photo:
          onCapturePhoto?.call();
          break;
        case CommandType.video:
        // Toggle video recording
          break;
        case CommandType.flashlight:
        // Toggle flashlight
          break;
        case CommandType.timer:
        // Start timer
          break;
        case CommandType.qualityChange:
          final quality = command.data['quality'] as String? ?? 'medium';
          onQualityChangeRequested?.call(quality);
          break;
      }
    });
  }

  Future<bool> sendMedia(MediaType type, XFile media) async {
    try {
      logInfo('Preparing to send ${type.name}...');

      // Wait for stable connection
      if (!_isStable) {
        logWarning('Connection not stable, waiting...');
        await _waitForStableConnection();
      }

      bool sentToAny = false;
      final activeChannels = _dataChannels.values
          .where((channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);

      for (final channel in activeChannels) {
        try {
          // Add delay between sends for stability
          await Future.delayed(const Duration(milliseconds: 200));

          final success = await _mediaService.sendMediaThroughDataChannel(
            channel,
            type,
            media,
            onProgress: onTransferProgress,
          );

          if (success) {
            logInfo('${type.name} sent successfully through data channel');
            sentToAny = true;
            break; // Send through one channel only
          }
        } catch (e) {
          logError('Error sending to channel: $e');
          continue;
        }
      }

      if (!sentToAny) {
        logWarning('No open data channels available for sending media');
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      logError('Error sending media: $e', stackTrace);
      return false;
    }
  }

  Future<void> _waitForStableConnection() async {
    int attempts = 0;
    while (!_isStable && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 200));
      attempts++;

      if (attempts % 15 == 0) {
        logInfo('Still waiting for stable connection... ${attempts * 200 / 1000} seconds passed');
      }
    }

    if (!_isStable) {
      logWarning('Connection did not stabilize within 10 seconds');
    }
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');

      logInfo('Setting remote description (answer)...');

      if (_pc!.signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        logWarning('Unexpected signaling state for answer: ${_pc!.signalingState}');
      }

      await _pc!.setRemoteDescription(answer);
      logInfo('Remote description set successfully');

      // Add pending ICE candidates with error handling
      for (final candidate in _candidates) {
        try {
          logDebug('Adding pending ICE candidate: ${candidate.candidate}');
          await _pc!.addCandidate(candidate);
        } catch (e) {
          logWarning('Failed to add ICE candidate: $e');
        }
      }
      _candidates.clear();
    } catch (e, stackTrace) {
      logError('Error handling answer: $e', stackTrace);
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_pc == null) throw Exception('PeerConnection not initialized');

    try {
      logInfo('Creating answer...');

      final answer = await _pc!.createAnswer(_webrtcService.defaultAnswerConstraints);
      if (answer == null) throw Exception('Failed to create answer');

      logInfo('Setting local description (answer)...');
      await _pc!.setLocalDescription(answer);

      return answer;
    } catch (e, stackTrace) {
      logError('Error creating answer: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');

      logInfo('Setting remote description...');
      await _pc!.setRemoteDescription(description);
      logInfo('Remote description set successfully');
    } catch (e, stackTrace) {
      logError('Error setting remote description: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');

      logInfo('Adding ICE candidate: ${candidate.candidate}');
      await _pc!.addCandidate(candidate);
      logInfo('ICE candidate added successfully');
    } catch (e, stackTrace) {
      logError('Error adding ICE candidate: $e', stackTrace);
      // Don't rethrow for ICE candidates as it's not critical
    }
  }

  Future<void> updateTrack(MediaStreamTrack newTrack) async {
    try {
      logInfo('Updating track: ${newTrack.kind}');

      final sender = _senders.firstWhereOrNull(
            (sender) => sender.track?.kind == newTrack.kind,
      );

      if (sender != null) {
        logInfo('Found existing sender for ${newTrack.kind}, replacing track...');

        // Optimize sender parameters
        await _webrtcService.optimizeSenderParameters(sender);

        // Replace track with stability check
        await sender.replaceTrack(newTrack);

        logInfo('Track replaced successfully: ${newTrack.kind}');
        logDebug('New track settings: ${newTrack.getSettings()}');
      } else {
        logWarning('No existing sender found for ${newTrack.kind}');
      }
    } catch (e, stackTrace) {
      logError('Error updating track: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> updateStream(MediaStream newStream) async {
    try {
      logInfo('Updating entire stream...');

      // Check connection stability
      if (!_isStable) {
        logWarning('Connection not stable, waiting before stream update...');
        await _waitForStableConnection();
      }

      final newTracks = newStream.getTracks();
      logInfo('New stream has ${newTracks.length} tracks');

      // Update tracks one by one with delays for stability
      for (final track in newTracks) {
        await updateTrack(track);
        await Future.delayed(const Duration(milliseconds: 200));
      }

      logInfo('Stream updated successfully');
    } catch (e, stackTrace) {
      logError('Error updating stream: $e', stackTrace);
      rethrow;
    }
  }

  Future<bool> sendCommand(String command, Map<String, dynamic> data) async {
    try {
      // Check connection stability
      if (!_isStable) {
        logWarning('Connection not stable, waiting before sending command...');
        await _waitForStableConnection();
      }

      final activeChannels = _dataChannels.values
          .where((channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);

      for (final channel in activeChannels) {
        try {
          final message = jsonEncode(data);
          await channel.send(RTCDataChannelMessage(message));
          logInfo('Sent command via data channel: $command');

          _recordCommandStats(command);
          return true;
        } catch (e) {
          logError('Error sending command through channel: $e');
          continue;
        }
      }

      logWarning('No open data channels available for sending command');
      return false;
    } catch (e, stackTrace) {
      logError('Error sending command via data channel: $e', stackTrace);
      return false;
    }
  }

  // Statistics and monitoring
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': isConnected,
      'isStable': _isStable,
      'lastStableTime': _lastStableTime.toIso8601String(),
      'reconnectAttempts': _reconnectAttempts,
      'commandStats': _commandStats,
      'lastCommandTimes': _lastCommandTimes.map(
              (key, value) => MapEntry(key, value.toIso8601String())
      ),
      'dataChannelCount': _dataChannels.length,
      'activeDataChannels': _dataChannels.values
          .where((channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen)
          .length,
      'lastDataChannelActivity': _lastDataChannelActivity.toIso8601String(),
    };
  }

  Future<void> close() async {
    try {
      logInfo('Closing WebRTC connection...');

      _isStable = false;

      // Cancel health monitoring
      _healthCheckTimer?.cancel();
      _dataChannelPingTimer?.cancel();

      // Close data channels
      for (final channel in _dataChannels.values) {
        await _webrtcService.closeDataChannel(channel);
      }
      _dataChannels.clear();

      // Clean up remote stream
      if (_remoteStream != null) {
        logInfo('Cleaning up remote stream');
        _remoteStream!.getTracks().forEach((track) {
          logDebug('Stopping track: ${track.kind}');
          track.stop();
        });
        _remoteStream = null;
      }

      // Close peer connection
      await _webrtcService.closeConnection(_pc);
      _pc = null;

      // Clear state
      _senders.clear();
      _candidates.clear();
      _offer = null;
      _reconnectAttempts = 0;
      _commandStats.clear();
      _lastCommandTimes.clear();

      logInfo('WebRTC connection closed successfully');
    } catch (e, stackTrace) {
      logError('Error closing WebRTC connection: $e', stackTrace);
    }
  }
}