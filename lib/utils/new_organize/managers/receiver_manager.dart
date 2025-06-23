// lib/utils/receiver_manager.dart (Updated)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../../constants.dart';
import '../service/logging_service.dart';
import '../service/logging_service.dart';
import '../service/command_service.dart';
import '../service/webrtc_service.dart';
import '../service/media_service.dart';
import '../service/network_service.dart';

enum StreamQuality { low, medium, high }

class ReceiverManager with LoggerMixin {
  @override
  String get loggerContext => 'ReceiverManager';

  // Services
  final LoggingService _loggingService = LoggingService();
  final CommandService _commandService = CommandService();
  final WebRTCService _webrtcService = WebRTCService();
  final MediaService _mediaService = MediaService();
  final NetworkService _networkService = NetworkService();

  // Network components
  HttpServer? _server;
  RawDatagramSocket? _udpSocket;

  // WebRTC state
  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, MediaStream> _remoteStreams = {};

  // Media transfer state
  final Map<String, Map<String, dynamic>> _pendingMediaMetadata = {};
  final Map<String, List<Uint8List>> _pendingChunks = {};

  // Connection state
  String? _primaryBroadcaster;
  final List<String> _connectedBroadcasters = [];
  bool _isConnected = false;
  bool _isDisposed = false;

  // Callbacks
  VoidCallback? onStateChange;
  void Function(MediaStream?)? onStreamChanged;
  void Function(String error)? onError;
  void Function(List<String> broadcasters)? onBroadcastersChanged;
  void Function(String mediaType, String filePath)? onMediaReceived;
  void Function(String broadcasterUrl, Uint8List data)? onPhotoReceived;
  void Function(String broadcasterUrl, Uint8List data)? onVideoReceived;

  ReceiverManager();

  // Getters
  MediaStream? get remoteStream =>
      _primaryBroadcaster != null ? _remoteStreams[_primaryBroadcaster] : null;

  bool get isConnected {
    final hasConnection = _connections.isNotEmpty;
    final hasStream = _remoteStreams.isNotEmpty;
    final hasDataChannel = _dataChannels.values.any(
            (channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);
    return hasConnection && hasStream && hasDataChannel;
  }

  String? get connectedBroadcaster => _primaryBroadcaster;
  List<String> get connectedBroadcasters => List.from(_connectedBroadcasters);
  int get connectionCount => _connections.length;
  List<String> get messages => _loggingService.messages;

  Future<void> init() async {
    try {
      logInfo('Initializing receiver manager...');
      await startDiscoveryListener();
      await _startSignalServer();
      logInfo('Receiver manager initialized successfully');
    } catch (e, stackTrace) {
      logError('Error initializing receiver manager: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> startDiscoveryListener() async {
    try {
      final wifiIP = await _networkService.getWifiIP();
      if (wifiIP == null) {
        throw Exception('Could not determine Wi-Fi IP');
      }

      _udpSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
      );

      final response = _networkService.createReceiverResponse(wifiIP);

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null) {
            final message = String.fromCharCodes(datagram.data);
            if (_networkService.isDiscoveryMessage(message)) {
              _udpSocket!.send(
                response.codeUnits,
                datagram.address,
                datagram.port,
              );
              logInfo('Responded to discovery from ${datagram.address}');
            }
          }
        }
      });

      logInfo('Discovery listener started on port ${AppConstants.discoveryPort}');
    } catch (e, stackTrace) {
      logError('Error starting discovery listener: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _startSignalServer() async {
    try {
      final handler = shelf.Pipeline().addHandler((request) async {
        return _handleHttpRequest(request);
      });

      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        AppConstants.signalingPort,
        shared: true,
      );

      logInfo('Signal server started on port ${AppConstants.signalingPort}');
    } catch (e, stackTrace) {
      logError('Error starting signal server: $e', stackTrace);
      rethrow;
    }
  }

  Future<shelf.Response> _handleHttpRequest(shelf.Request request) async {
    logInfo('Received ${request.method} ${request.url.path}');

    try {
      if (request.method == 'POST' && request.url.path == 'offer') {
        return await _handleOfferRequest(request);
      } else if (request.method == 'POST' && request.url.path == 'candidate') {
        return await _handleCandidateRequest(request);
      }
      return shelf.Response.notFound('Not found');
    } catch (e, stackTrace) {
      logError('Error handling HTTP request: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Internal server error: $e');
    }
  }

  Future<shelf.Response> _handleOfferRequest(shelf.Request request) async {
    try {
      // Validate content type
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        return shelf.Response(400, body: 'Invalid content type');
      }

      // Parse request body
      final body = await request.readAsString();
      if (body.isEmpty) {
        return shelf.Response(400, body: 'Empty request body');
      }

      final data = jsonDecode(body);
      if (data['sdp'] == null || data['type'] == null || data['broadcasterUrl'] == null) {
        return shelf.Response(400, body: 'Missing required fields');
      }

      final offer = RTCSessionDescription(data['sdp'], data['type']);
      final broadcasterUrl = data['broadcasterUrl'];

      logInfo('Processing offer from $broadcasterUrl');

      // Check connection limit
      if (_connections.length >= AppConstants.maxConnections) {
        return shelf.Response(503, body: 'Maximum connections reached');
      }

      // Clean up existing connection if exists
      await _cleanupExistingConnection(broadcasterUrl);

      // Create new connection
      final pc = await _webrtcService.createPeerConnection();
      _setupPeerConnectionHandlers(pc, broadcasterUrl);
      _connections[broadcasterUrl] = pc;

      // Process the offer
      await pc.setRemoteDescription(offer);
      logInfo('Remote description set successfully');

      final answer = await pc.createAnswer(_webrtcService.defaultAnswerConstraints);
      if (answer == null) {
        throw Exception('Failed to create answer');
      }

      await pc.setLocalDescription(answer);
      logInfo('Local description set successfully');

      // Send answer back to broadcaster
      final success = await _networkService.sendAnswerToBroadcaster(broadcasterUrl, answer);
      if (!success) {
        await pc.close();
        _connections.remove(broadcasterUrl);
        return shelf.Response(500, body: 'Failed to send answer');
      }

      // Update connection state
      _primaryBroadcaster = broadcasterUrl;
      _isConnected = true;

      if (!_connectedBroadcasters.contains(broadcasterUrl)) {
        _connectedBroadcasters.add(broadcasterUrl);
      }

      onStateChange?.call();
      onBroadcastersChanged?.call(_connectedBroadcasters);

      return shelf.Response.ok('Connection established');
    } catch (e, stackTrace) {
      logError('Error processing offer: $e', stackTrace);
      return shelf.Response(500, body: 'Connection setup failed: $e');
    }
  }

  Future<shelf.Response> _handleCandidateRequest(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      logInfo('Received ICE candidate: ${candidate.candidate}');
      await _connections[_primaryBroadcaster]?.addCandidate(candidate);
      logInfo('Added ICE candidate');

      return shelf.Response.ok('Candidate processed');
    } catch (e, stackTrace) {
      logError('Error processing candidate: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error: $e');
    }
  }

  Future<void> _cleanupExistingConnection(String broadcasterUrl) async {
    if (_connections.containsKey(broadcasterUrl)) {
      logInfo('Cleaning up existing connection for $broadcasterUrl');

      await _connections[broadcasterUrl]?.close();
      _connections.remove(broadcasterUrl);
      _dataChannels.remove(broadcasterUrl);

      if (_remoteStreams.containsKey(broadcasterUrl)) {
        _remoteStreams[broadcasterUrl]?.getTracks().forEach((track) => track.stop());
        await _remoteStreams[broadcasterUrl]?.dispose();
        _remoteStreams.remove(broadcasterUrl);
      }

      onStreamChanged?.call(null);
    }
  }

  void _setupPeerConnectionHandlers(RTCPeerConnection pc, String broadcasterUrl) {
    if (_isDisposed) return;

    // Setup connection state handlers
    _webrtcService.setupConnectionStateHandlers(
      pc,
      onConnected: () {
        logInfo('Connection restored');
        _isConnected = true;
        onStateChange?.call();
      },
      onDisconnected: () {
        Future.delayed(const Duration(seconds: 5), () {
          if (pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
            _handleDisconnect(broadcasterUrl);
          }
        });
      },
      onFailed: () => _handleDisconnect(broadcasterUrl),
    );

    // Setup ICE connection state handlers
    _webrtcService.setupIceConnectionStateHandlers(
      pc,
      onConnected: () {
        logInfo('ICE Connection restored');
        _isConnected = true;
        onStateChange?.call();
      },
      onDisconnected: () {
        Future.delayed(const Duration(seconds: 5), () {
          if (pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            _handleDisconnect(broadcasterUrl);
          }
        });
      },
      onFailed: () => _handleDisconnect(broadcasterUrl),
    );

    // Setup ICE candidate handler
    _webrtcService.setupIceCandidateHandler(
      pc,
      onCandidate: (candidate) async {
        try {
          await _networkService.sendIceCandidate(broadcasterUrl, candidate);
        } catch (e) {
          logError('Failed to send ICE candidate: $e');
        }
      },
      onGatheringComplete: () => logInfo('ICE gathering completed'),
    );

    // Setup track handler
    _webrtcService.setupTrackHandler(
      pc,
      onTrack: (track, streams) {
        if (_isDisposed) return;
        if (track.kind == 'video') {
          logInfo('Received video track: ${track.id}');
          if (streams.isNotEmpty) {
            _remoteStreams[broadcasterUrl] = streams[0];
            onStreamChanged?.call(_remoteStreams[broadcasterUrl]);
            _verifyConnection(broadcasterUrl);
          }
        }
      },
    );

    // Setup data channel handler
    pc.onDataChannel = (channel) {
      logInfo('Received data channel: ${channel.label}');
      _dataChannels[broadcasterUrl] = channel;
      _setupDataChannel(channel, broadcasterUrl);
    };
  }

  void _setupDataChannel(RTCDataChannel channel, String broadcasterUrl) {
    channel.onDataChannelState = (state) {
      logInfo('Data channel state for $broadcasterUrl: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        logInfo('Data channel is now OPEN and ready for communication');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        logInfo('Data channel is now CLOSED');
        if (_connections[broadcasterUrl]?.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _handleDataChannelReconnect(broadcasterUrl);
        }
      }
    };

    channel.onMessage = (message) {
      _handleDataChannelMessage(message, broadcasterUrl);
    };
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message, String broadcasterUrl) {
    logInfo('Received message from $broadcasterUrl');

    if (message.type == MessageType.text) {
      try {
        final data = jsonDecode(message.text);
        final messageType = data['type'] as String;

        switch (messageType) {
          case 'media_metadata':
            _handleMediaMetadata(broadcasterUrl, data);
            break;
          case 'command':
          // Handle command responses if needed
            break;
          default:
            logInfo('Unknown message type: $messageType');
        }
      } catch (e, stackTrace) {
        logError('Error processing text message: $e', stackTrace);
      }
    } else if (message.type == MessageType.binary) {
      _handleBinaryData(broadcasterUrl, message.binary!);
    }
  }

  void _handleMediaMetadata(String broadcasterId, Map<String, dynamic> data) {
    logInfo('Received media metadata from $broadcasterId');

    _pendingMediaMetadata.remove(broadcasterId);
    _pendingChunks.remove(broadcasterId);

    _pendingMediaMetadata[broadcasterId] = data;
    _pendingChunks[broadcasterId] = [];

    logInfo('Expecting ${data['totalChunks']} chunks for ${data['fileName']}');
  }

  void _handleBinaryData(String broadcasterId, Uint8List binaryData) async {
    try {
      final metadata = _pendingMediaMetadata[broadcasterId];
      if (metadata == null) {
        logWarning('Received binary data without metadata from $broadcasterId');
        return;
      }

      _pendingChunks[broadcasterId]!.add(binaryData);
      logInfo('Received chunk ${_pendingChunks[broadcasterId]!.length}/${metadata['totalChunks']}');

      if (_pendingChunks[broadcasterId]!.length == metadata['totalChunks']) {
        logInfo('Received all chunks, assembling file...');

        final mediaMetadata = MediaMetadata.fromJson(metadata);
        final filePath = await _mediaService.assembleMediaFromChunks(
          _pendingChunks[broadcasterId]!,
          mediaMetadata,
        );

        // Trigger callbacks
        onMediaReceived?.call(mediaMetadata.mediaType, filePath);

        final fileBytes = await File(filePath).readAsBytes();
        if (mediaMetadata.mediaType == 'photo') {
          onPhotoReceived?.call(broadcasterId, fileBytes);
        } else if (mediaMetadata.mediaType == 'video') {
          onVideoReceived?.call(broadcasterId, fileBytes);
        }

        // Cleanup
        _pendingMediaMetadata.remove(broadcasterId);
        _pendingChunks.remove(broadcasterId);
      }
    } catch (e, stackTrace) {
      logError('Error handling binary data: $e', stackTrace);
      _pendingMediaMetadata.remove(broadcasterId);
      _pendingChunks.remove(broadcasterId);
    }
  }

  void _verifyConnection(String broadcasterUrl) {
    if (_isDisposed) return;

    final hasStream = _remoteStreams.containsKey(broadcasterUrl);
    final hasDataChannel = _dataChannels[broadcasterUrl]?.state ==
        RTCDataChannelState.RTCDataChannelOpen;

    logInfo('Verifying connection - Stream: $hasStream, DataChannel: $hasDataChannel');

    if (hasStream && !hasDataChannel) {
      logInfo('Stream exists but no data channel, attempting to create one...');
      _handleDataChannelReconnect(broadcasterUrl);
    }

    _isConnected = hasStream && hasDataChannel;
    onStateChange?.call();
  }

  Future<RTCDataChannel?> _handleDataChannelReconnect(String broadcasterUrl) async {
    logInfo('Attempting to reestablish data channel for $broadcasterUrl');

    try {
      final pc = _connections[broadcasterUrl];
      if (pc != null) {
        if (_dataChannels[broadcasterUrl] != null) {
          await _webrtcService.closeDataChannel(_dataChannels[broadcasterUrl]);
          _dataChannels.remove(broadcasterUrl);
        }

        int attempts = 0;
        const maxAttempts = 3;
        RTCDataChannel? newChannel;

        while (attempts < maxAttempts &&
            (newChannel == null || newChannel.state != RTCDataChannelState.RTCDataChannelOpen)) {
          try {
            newChannel = await _webrtcService.createDataChannel(pc, 'commands');
            _dataChannels[broadcasterUrl] = newChannel;
            _setupDataChannel(newChannel, broadcasterUrl);

            // Wait for channel to open
            int waitAttempts = 0;
            while (newChannel.state != RTCDataChannelState.RTCDataChannelOpen && waitAttempts < 50) {
              await Future.delayed(const Duration(milliseconds: 100));
              waitAttempts++;
            }

            if (newChannel.state == RTCDataChannelState.RTCDataChannelOpen) {
              logInfo('Data channel recreated and opened successfully');
              return newChannel;
            }
          } catch (e) {
            logWarning('Attempt ${attempts + 1} failed: $e');
          }

          attempts++;
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: attempts));
          }
        }
      }
    } catch (e, stackTrace) {
      logError('Error recreating data channel: $e', stackTrace);
    }
    return null;
  }

  void _handleDisconnect(String broadcasterUrl) {
    if (_isDisposed) return;

    logInfo('Handling disconnect from $broadcasterUrl');

    _connectedBroadcasters.remove(broadcasterUrl);
    _connections.remove(broadcasterUrl);
    _dataChannels.remove(broadcasterUrl);

    if (_remoteStreams.containsKey(broadcasterUrl)) {
      _remoteStreams[broadcasterUrl]?.getTracks().forEach((track) => track.stop());
      _remoteStreams[broadcasterUrl]?.dispose();
      _remoteStreams.remove(broadcasterUrl);
    }

    if (_primaryBroadcaster == broadcasterUrl) {
      if (_connectedBroadcasters.isNotEmpty) {
        _primaryBroadcaster = _connectedBroadcasters.first;
        onStreamChanged?.call(_remoteStreams[_primaryBroadcaster]);
      } else {
        _primaryBroadcaster = null;
        _isConnected = false;
        onStreamChanged?.call(null);
      }
    }

    onStateChange?.call();
    onBroadcastersChanged?.call(_connectedBroadcasters);

    if (!_isDisposed) {
      Future.delayed(const Duration(seconds: 3), () {
        _attemptReconnect(broadcasterUrl);
      });
    }
  }

  Future<void> _attemptReconnect(String broadcasterUrl) async {
    if (_isDisposed || _connectedBroadcasters.contains(broadcasterUrl)) return;

    logInfo('Attempting to reconnect to $broadcasterUrl');

    try {
      final isHealthy = await _networkService.checkReceiverHealth(broadcasterUrl);

      if (isHealthy) {
        logInfo('Broadcaster available, attempting reconnection...');
        await _initializeConnection(broadcasterUrl);
      } else {
        logInfo('Broadcaster not available, will retry later');
        Future.delayed(const Duration(seconds: 5), () {
          _attemptReconnect(broadcasterUrl);
        });
      }
    } catch (e, stackTrace) {
      logError('Reconnection attempt failed: $e', stackTrace);

      if (!_isDisposed) {
        Future.delayed(const Duration(seconds: 5), () {
          _attemptReconnect(broadcasterUrl);
        });
      }
    }
  }

  Future<void> _initializeConnection(String broadcasterUrl) async {
    try {
      final pc = await _webrtcService.createPeerConnection();
      _setupPeerConnectionHandlers(pc, broadcasterUrl);
      _connections[broadcasterUrl] = pc;

      if (!_connectedBroadcasters.contains(broadcasterUrl)) {
        _connectedBroadcasters.add(broadcasterUrl);
      }

      onStateChange?.call();
      onBroadcastersChanged?.call(_connectedBroadcasters);
    } catch (e, stackTrace) {
      logError('Failed to initialize connection: $e', stackTrace);
      throw Exception('Failed to initialize connection: $e');
    }
  }

  // Command methods
  Future<void> sendCommand(String command) async {
    if (_primaryBroadcaster == null) {
      throw Exception('No active connection');
    }

    final dataChannel = _dataChannels[_primaryBroadcaster];
    if (dataChannel == null) {
      logInfo('No data channel found, attempting to create one...');
      final newChannel = await _handleDataChannelReconnect(_primaryBroadcaster!);
      if (newChannel == null) {
        throw Exception('Failed to create data channel');
      }
    }

    // Wait for channel to be ready
    await _waitForDataChannelReady(_primaryBroadcaster!);

    AppCommand appCommand;
    switch (command) {
      case 'photo':
        appCommand = AppCommand.photo();
        break;
      case 'flashlight':
        appCommand = AppCommand.flashlight();
        break;
      case 'timer':
        appCommand = AppCommand.timer();
        break;
      case 'video':
        appCommand = AppCommand.video();
        break;
      case 'low':
      case 'medium':
      case 'high':
        await _commandService.sendQualityChange(_dataChannels[_primaryBroadcaster], command);
        logInfo('Quality change command sent: $command');
        return;
      default:
        throw Exception('Unknown command: $command');
    }

    final success = await _commandService.sendCommand(_dataChannels[_primaryBroadcaster], appCommand);
    if (!success) {
      throw Exception('Failed to send command: $command');
    }
  }

  Future<void> _waitForDataChannelReady(String broadcasterUrl) async {
    int attempts = 0;
    while (_dataChannels[broadcasterUrl]?.state != RTCDataChannelState.RTCDataChannelOpen &&
        attempts < 150) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;

      if (attempts % 30 == 0) {
        logInfo('Still waiting for data channel to open... ${attempts / 10} seconds passed');
      }
    }

    if (_dataChannels[broadcasterUrl]?.state != RTCDataChannelState.RTCDataChannelOpen) {
      logError('Data channel failed to open after 15 seconds');
      final newChannel = await _handleDataChannelReconnect(broadcasterUrl);
      if (newChannel == null || newChannel.state != RTCDataChannelState.RTCDataChannelOpen) {
        throw Exception('Data channel is not open after multiple attempts');
      }
    }
  }

  Future<void> sendCommandToAll(String command) async {
    if (_dataChannels.isEmpty) {
      throw Exception('No active connection or data channel');
    }

    AppCommand appCommand;
    switch (command) {
      case 'photo':
        appCommand = AppCommand.photo();
        break;
      case 'flashlight':
        appCommand = AppCommand.flashlight();
        break;
      case 'timer':
        appCommand = AppCommand.timer();
        break;
      case 'video':
        appCommand = AppCommand.video();
        break;
      default:
        throw Exception('Unknown command: $command');
    }

    await _commandService.sendCommandToMultipleChannels(_dataChannels, appCommand);
  }

  Future<void> changeStreamQuality(dynamic quality) async {
    String qualityString;
    switch (quality.toString()) {
      case 'StreamQuality.low':
        qualityString = 'low';
        break;
      case 'StreamQuality.medium':
        qualityString = 'medium';
        break;
      case 'StreamQuality.high':
        qualityString = 'high';
        break;
      default:
        qualityString = 'medium';
    }

    await sendCommand(qualityString);
  }

  void switchToPrimaryBroadcaster(String broadcasterUrl) {
    if (_connectedBroadcasters.contains(broadcasterUrl)) {
      _primaryBroadcaster = broadcasterUrl;
      onStreamChanged?.call(_remoteStreams[broadcasterUrl]);
      onStateChange?.call();
    }
  }

  Future<void> dispose() async {
    _isDisposed = true;

    try {
      logInfo('Disposing receiver manager...');

      for (final channel in _dataChannels.values) {
        await _webrtcService.closeDataChannel(channel);
      }

      for (final stream in _remoteStreams.values) {
        stream.getTracks().forEach((track) => track.stop());
        await stream.dispose();
      }

      for (final connection in _connections.values) {
        await _webrtcService.closeConnection(connection);
      }

      await _server?.close();
      _udpSocket?.close();

      logInfo('Receiver manager disposed successfully');
    } catch (e, stackTrace) {
      logError('Error during disposal: $e', stackTrace);
    }
  }

  Future<void> close() => dispose();
}