// lib/utils/receiver_manager.dart (Updated)
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'constants.dart';
import 'service/logging_service.dart';
import 'service/logging_service.dart';
import 'service/command_service.dart';
import 'service/webrtc_service.dart';
import 'service/media_service.dart';
import 'service/network_service.dart';

enum StreamQuality { low, medium, high }

class BroadcasterConnection {
  final String id;
  final String url;
  final RTCPeerConnection peerConnection;
  final RTCDataChannel? dataChannel;
  final MediaStream? stream;
  final DateTime connectedAt;
  bool isActive;
  bool isPrimary;

  BroadcasterConnection({
    required this.id,
    required this.url,
    required this.peerConnection,
    this.dataChannel,
    this.stream,
    required this.connectedAt,
    this.isActive = true,
    this.isPrimary = false,
  });

  BroadcasterConnection copyWith({
    RTCDataChannel? dataChannel,
    MediaStream? stream,
    bool? isActive,
    bool? isPrimary,
  }) {
    return BroadcasterConnection(
      id: id,
      url: url,
      peerConnection: peerConnection,
      dataChannel: dataChannel ?? this.dataChannel,
      stream: stream ?? this.stream,
      connectedAt: connectedAt,
      isActive: isActive ?? this.isActive,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

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

  // WebRTC state - улучшенное управление соединениями
  final Map<String, BroadcasterConnection> _broadcasterConnections = {};
  String? _primaryBroadcasterId;
  bool _isDisposed = false;

  // Media transfer state
  final Map<String, Map<String, dynamic>> _pendingMediaMetadata = {};
  final Map<String, List<Uint8List>> _pendingChunks = {};

  // Command queue and state management
  final List<Map<String, dynamic>> _commandQueue = [];
  bool _processingCommand = false;
  Timer? _commandTimer;
  Timer? _healthCheckTimer;
  Timer? _stateUpdateTimer;

  // Callbacks
  VoidCallback? onStateChange;
  void Function(MediaStream?)? onStreamChanged;
  void Function(String error)? onError;
  void Function(List<String> broadcasters)? onBroadcastersChanged;
  void Function(String mediaType, String filePath)? onMediaReceived;
  void Function(String broadcasterUrl, Uint8List data)? onPhotoReceived;
  void Function(String broadcasterUrl, Uint8List data)? onVideoReceived;
  void Function(String broadcasterId, bool isConnected)? onBroadcasterConnectionChanged;

  ReceiverManager();

  // Getters
  MediaStream? get remoteStream => _primaryBroadcasterId != null
      ? _broadcasterConnections[_primaryBroadcasterId]?.stream
      : null;

  bool get isConnected => _broadcasterConnections.values.any((conn) =>
  conn.isActive && conn.stream != null && conn.dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen);

  String? get connectedBroadcaster => _primaryBroadcasterId;

  List<String> get connectedBroadcasters => _broadcasterConnections.values
      .where((conn) => conn.isActive)
      .map((conn) => conn.url)
      .toList();

  int get connectionCount => _broadcasterConnections.values.where((conn) => conn.isActive).length;
  List<String> get messages => _loggingService.messages;

  // Получение информации о соединениях
  List<BroadcasterConnection> get activeBroadcasters => _broadcasterConnections.values
      .where((conn) => conn.isActive)
      .toList();

  BroadcasterConnection? get primaryBroadcaster => _primaryBroadcasterId != null
      ? _broadcasterConnections[_primaryBroadcasterId]
      : null;

  Future<void> init() async {
    try {
      logInfo('Initializing receiver manager...');
      await startDiscoveryListener();
      await _startSignalServer();
      _startHealthChecks();
      _startCommandProcessor();
      _startStateUpdater();
      logInfo('Receiver manager initialized successfully');
    } catch (e, stackTrace) {
      logError('Error initializing receiver manager: $e', stackTrace);
      rethrow;
    }
  }

  void _startStateUpdater() {
    _stateUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateConnectionStates();
    });
  }

  void _updateConnectionStates() {
    bool hasChanges = false;
    final disconnectedIds = <String>[];

    for (final entry in _broadcasterConnections.entries) {
      final connection = entry.value;
      final pc = connection.peerConnection;

      // Проверяем состояние соединения
      final shouldBeActive = pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
          pc.iceConnectionState != RTCIceConnectionState.RTCIceConnectionStateFailed &&
          pc.iceConnectionState != RTCIceConnectionState.RTCIceConnectionStateClosed;

      if (connection.isActive != shouldBeActive) {
        hasChanges = true;
        if (shouldBeActive) {
          _broadcasterConnections[entry.key] = connection.copyWith(isActive: true);
          logInfo('Broadcaster ${connection.id} became active');
        } else {
          _broadcasterConnections[entry.key] = connection.copyWith(isActive: false);
          logInfo('Broadcaster ${connection.id} became inactive');
          disconnectedIds.add(entry.key);
        }
      }
    }

    // Очищаем отключенные соединения
    for (final id in disconnectedIds) {
      _cleanupBroadcasterConnection(id, immediate: true);
    }

    if (hasChanges) {
      _updatePrimaryBroadcaster();
      onStateChange?.call();
      onBroadcastersChanged?.call(connectedBroadcasters);
    }
  }

  void _startHealthChecks() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectionsHealth();
    });
  }

  void _checkConnectionsHealth() async {
    final disconnectedIds = <String>[];

    for (final entry in _broadcasterConnections.entries) {
      final connection = entry.value;
      try {
        final pc = connection.peerConnection;

        // Проверяем состояние peer connection
        if (pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
            pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            pc.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          disconnectedIds.add(entry.key);
          continue;
        }

        // Проверяем состояние ICE
        if (pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          disconnectedIds.add(entry.key);
          continue;
        }

        // Проверяем data channel
        final dataChannel = connection.dataChannel;
        if (dataChannel?.state == RTCDataChannelState.RTCDataChannelClosed) {
          logInfo('Data channel closed for ${connection.id}, attempting to recreate...');
          await _recreateDataChannel(entry.key);
        }

      } catch (e) {
        logError('Health check error for ${connection.id}: $e');
        disconnectedIds.add(entry.key);
      }
    }

    // Удаляем отключенные соединения
    for (final id in disconnectedIds) {
      logWarning('Removing unhealthy broadcaster: $id');
      _handleBroadcasterDisconnect(id);
    }
  }

  void _startCommandProcessor() {
    _commandTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      _processCommandQueue();
    });
  }

  Future<void> _processCommandQueue() async {
    if (_processingCommand || _commandQueue.isEmpty) return;

    _processingCommand = true;
    try {
      final command = _commandQueue.removeAt(0);
      await _executeCommand(command);

      // Небольшая задержка между командами для стабильности
      await Future.delayed(const Duration(milliseconds: 25));
    } catch (e, stackTrace) {
      logError('Error processing command: $e', stackTrace);
    } finally {
      _processingCommand = false;
    }
  }

  Future<void> _executeCommand(Map<String, dynamic> command) async {
    try {
      final action = command['action'] as String;
      final data = command['data'] as Map<String, dynamic>? ?? {};
      final targetId = command['targetId'] as String?;

      logInfo('Executing command: $action for target: ${targetId ?? 'all'}');

      if (targetId != null) {
        // Команда для конкретного broadcaster'а
        await _sendCommandToBroadcaster(targetId, action, data);
      } else {
        // Команда для всех broadcaster'ов
        await _sendCommandToAll(action, data);
      }

      logInfo('Command executed successfully: $action');
    } catch (e, stackTrace) {
      logError('Error executing command: $e', stackTrace);
    }
  }

  Future<void> _sendCommandToBroadcaster(String broadcasterId, String action, Map<String, dynamic> data) async {
    final connection = _broadcasterConnections[broadcasterId];
    if (connection == null || !connection.isActive) {
      throw Exception('Broadcaster $broadcasterId not found or inactive');
    }

    final dataChannel = connection.dataChannel;
    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel not open for broadcaster $broadcasterId');
    }

    AppCommand? appCommand;
    switch (action) {
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
      case 'quality':
        final quality = data['quality'] as String? ?? 'medium';
        await _commandService.sendQualityChange(dataChannel, quality);
        return;
    }

    if (appCommand != null) {
      await _commandService.sendCommand(dataChannel, appCommand);
    }
  }

  Future<void> _sendCommandToAll(String action, Map<String, dynamic> data) async {
    final activeConnections = _broadcasterConnections.values.where((conn) =>
    conn.isActive && conn.dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen);

    if (activeConnections.isEmpty) {
      throw Exception('No active broadcaster connections');
    }

    for (final connection in activeConnections) {
      try {
        await _sendCommandToBroadcaster(connection.id, action, data);
      } catch (e) {
        logError('Failed to send command to ${connection.id}: $e');
      }
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
    final clientIp = _getClientIp(request);
    logInfo('Received ${request.method} ${request.url.path} from $clientIp');

    try {
      if (request.method == 'POST' && request.url.path == 'offer') {
        return await _handleOfferRequest(request, clientIp);
      } else if (request.method == 'POST' && request.url.path == 'candidate') {
        return await _handleCandidateRequest(request, clientIp);
      } else if (request.method == 'GET' && request.url.path == 'health') {
        return _handleHealthRequest();
      }
      return shelf.Response.notFound('Not found');
    } catch (e, stackTrace) {
      logError('Error handling HTTP request: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Internal server error: $e');
    }
  }

  String _getClientIp(shelf.Request request) {
    final connectionInfo = request.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      return connectionInfo.remoteAddress.address;
    }
    return 'unknown';
  }

  shelf.Response _handleHealthRequest() {
    try {
      final health = {
        'status': 'ok',
        'timestamp': DateTime.now().toIso8601String(),
        'connected_broadcasters': connectionCount,
        'is_connected': isConnected,
        'active_connections': activeBroadcasters.map((conn) => {
          'id': conn.id,
          'url': conn.url,
          'connected_at': conn.connectedAt.toIso8601String(),
          'is_primary': conn.isPrimary,
          'has_stream': conn.stream != null,
          'data_channel_state': conn.dataChannel?.state.toString(),
        }).toList(),
      };

      return shelf.Response.ok(jsonEncode(health));
    } catch (e, stackTrace) {
      logError('Error handling health request: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error checking health');
    }
  }

  Future<shelf.Response> _handleOfferRequest(shelf.Request request, String clientIp) async {
    try {
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('application/json')) {
        return shelf.Response(400, body: 'Invalid content type');
      }

      final body = await request.readAsString();
      if (body.isEmpty) {
        return shelf.Response(400, body: 'Empty request body');
      }

      final data = jsonDecode(body);
      if (data['sdp'] == null || data['type'] == null || data['broadcasterUrl'] == null) {
        return shelf.Response(400, body: 'Missing required fields');
      }

      final offer = RTCSessionDescription(data['sdp'], data['type']);
      final broadcasterUrl = data['broadcasterUrl'] as String;

      // Создаем уникальный ID для broadcaster'а
      final broadcasterId = '${clientIp}_${DateTime.now().millisecondsSinceEpoch}';

      logInfo('Processing offer from $broadcasterUrl (ID: $broadcasterId)');

      // Проверяем лимит соединений
      if (_broadcasterConnections.length >= AppConstants.maxConnections) {
        return shelf.Response(503, body: 'Maximum connections reached');
      }

      // Создаем новое соединение
      final pc = await _webrtcService.createPeerConnection();
      _setupPeerConnectionHandlers(pc, broadcasterId, broadcasterUrl);

      // Обрабатываем offer
      await pc.setRemoteDescription(offer);
      logInfo('Remote description set successfully for $broadcasterId');

      final answer = await pc.createAnswer(_webrtcService.defaultAnswerConstraints);
      if (answer == null) {
        throw Exception('Failed to create answer');
      }

      await pc.setLocalDescription(answer);
      logInfo('Local description set successfully for $broadcasterId');

      // Создаем connection объект
      final connection = BroadcasterConnection(
        id: broadcasterId,
        url: broadcasterUrl,
        peerConnection: pc,
        connectedAt: DateTime.now(),
      );

      _broadcasterConnections[broadcasterId] = connection;

      // Устанавливаем как primary если это первое соединение
      if (_primaryBroadcasterId == null) {
        _primaryBroadcasterId = broadcasterId;
        _broadcasterConnections[broadcasterId] = connection.copyWith(isPrimary: true);
        logInfo('Set $broadcasterId as primary broadcaster');
      }

      // Отправляем ответ broadcaster'у
      bool answerSent = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final success = await _networkService.sendAnswerToBroadcaster(broadcasterUrl, answer);
          if (success) {
            answerSent = true;
            break;
          }
        } catch (e) {
          logWarning('Answer send attempt ${attempt + 1} failed: $e');
          if (attempt < 2) {
            await Future.delayed(Duration(seconds: attempt + 1));
          }
        }
      }

      if (!answerSent) {
        await _cleanupBroadcasterConnection(broadcasterId);
        return shelf.Response(500, body: 'Failed to send answer after retries');
      }

      onStateChange?.call();
      onBroadcastersChanged?.call(connectedBroadcasters);
      onBroadcasterConnectionChanged?.call(broadcasterId, true);

      return shelf.Response.ok(jsonEncode({
        'status': 'connected',
        'broadcaster_id': broadcasterId,
        'is_primary': _primaryBroadcasterId == broadcasterId,
      }));

    } catch (e, stackTrace) {
      logError('Error processing offer: $e', stackTrace);
      return shelf.Response(500, body: 'Connection setup failed: $e');
    }
  }

  Future<shelf.Response> _handleCandidateRequest(shelf.Request request, String clientIp) async {
    try {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      logInfo('Received ICE candidate from $clientIp: ${candidate.candidate}');

      // Находим соединение по IP
      final connection = _broadcasterConnections.values.firstWhere(
            (conn) => conn.url.contains(clientIp),
        orElse: () => throw Exception('Connection not found for $clientIp'),
      );

      await connection.peerConnection.addCandidate(candidate);
      logInfo('Added ICE candidate for ${connection.id}');

      return shelf.Response.ok('Candidate processed');
    } catch (e, stackTrace) {
      logError('Error processing candidate from $clientIp: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error: $e');
    }
  }

  void _setupPeerConnectionHandlers(RTCPeerConnection pc, String broadcasterId, String broadcasterUrl) {
    if (_isDisposed) return;

    // Setup connection state handlers
    _webrtcService.setupConnectionStateHandlers(
      pc,
      onConnected: () {
        logInfo('Connection established with $broadcasterId');
        final connection = _broadcasterConnections[broadcasterId];
        if (connection != null) {
          _broadcasterConnections[broadcasterId] = connection.copyWith(isActive: true);
          onStateChange?.call();
          onBroadcasterConnectionChanged?.call(broadcasterId, true);
        }
      },
      onDisconnected: () {
        logWarning('Connection disconnected with $broadcasterId');
        _handleBroadcasterDisconnect(broadcasterId);
      },
      onFailed: () {
        logError('Connection failed with $broadcasterId');
        _handleBroadcasterDisconnect(broadcasterId);
      },
    );

    // Setup ICE connection state handlers
    _webrtcService.setupIceConnectionStateHandlers(
      pc,
      onConnected: () {
        logInfo('ICE Connection established with $broadcasterId');
      },
      onDisconnected: () {
        logWarning('ICE Connection disconnected with $broadcasterId');
        Future.delayed(const Duration(seconds: 3), () {
          if (pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
              pc.iceConnectionState == RTCIceConnectionState.RTCIceConnectionStateFailed) {
            _handleBroadcasterDisconnect(broadcasterId);
          }
        });
      },
      onFailed: () {
        logError('ICE Connection failed with $broadcasterId');
        _handleBroadcasterDisconnect(broadcasterId);
      },
    );

    // Setup ICE candidate handler
    _webrtcService.setupIceCandidateHandler(
      pc,
      onCandidate: (candidate) async {
        try {
          await _networkService.sendIceCandidate(broadcasterUrl, candidate);
        } catch (e) {
          logError('Failed to send ICE candidate for $broadcasterId: $e');
        }
      },
      onGatheringComplete: () => logInfo('ICE gathering completed for $broadcasterId'),
    );

    // Setup track handler
    _webrtcService.setupTrackHandler(
      pc,
      onTrack: (track, streams) {
        if (_isDisposed) return;
        if (track.kind == 'video') {
          logInfo('Received video track: ${track.id} from $broadcasterId');
          if (streams.isNotEmpty) {
            final connection = _broadcasterConnections[broadcasterId];
            if (connection != null) {
              _broadcasterConnections[broadcasterId] = connection.copyWith(stream: streams[0]);

              // Обновляем отображаемый поток если это primary broadcaster
              if (broadcasterId == _primaryBroadcasterId) {
                onStreamChanged?.call(streams[0]);
              }

              onStateChange?.call();
            }
          }
        }
      },
    );

    // Setup data channel handler
    pc.onDataChannel = (channel) {
      logInfo('Received data channel: ${channel.label} from $broadcasterId');
      _setupDataChannel(channel, broadcasterId);
    };
  }

  void _setupDataChannel(RTCDataChannel channel, String broadcasterId) {
    // Обновляем connection с data channel
    final connection = _broadcasterConnections[broadcasterId];
    if (connection != null) {
      _broadcasterConnections[broadcasterId] = connection.copyWith(dataChannel: channel);
    }

    channel.onDataChannelState = (state) {
      logInfo('Data channel state for $broadcasterId: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        logInfo('Data channel is now OPEN for $broadcasterId');
        onStateChange?.call();
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        logInfo('Data channel is now CLOSED for $broadcasterId');
        Future.delayed(const Duration(seconds: 1), () {
          _recreateDataChannel(broadcasterId);
        });
      }
    };

    channel.onMessage = (message) {
      _handleDataChannelMessage(message, broadcasterId);
    };
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message, String broadcasterId) {
    if (message.type == MessageType.text) {
      try {
        final data = jsonDecode(message.text);
        final messageType = data['type'] as String;

        switch (messageType) {
          case 'media_metadata':
            _handleMediaMetadata(broadcasterId, data);
            break;
          case 'command':
          // Handle command responses if needed
            break;
          default:
            logInfo('Unknown message type: $messageType from $broadcasterId');
        }
      } catch (e, stackTrace) {
        logError('Error processing text message from $broadcasterId: $e', stackTrace);
      }
    } else if (message.type == MessageType.binary) {
      _handleBinaryData(broadcasterId, message.binary!);
    }
  }

  void _handleMediaMetadata(String broadcasterId, Map<String, dynamic> data) {
    logInfo('Received media metadata from $broadcasterId');

    _pendingMediaMetadata.remove(broadcasterId);
    _pendingChunks.remove(broadcasterId);

    _pendingMediaMetadata[broadcasterId] = data;
    _pendingChunks[broadcasterId] = [];

    logInfo('Expecting ${data['totalChunks']} chunks for ${data['fileName']} from $broadcasterId');
  }

  void _handleBinaryData(String broadcasterId, Uint8List binaryData) async {
    try {
      final metadata = _pendingMediaMetadata[broadcasterId];
      if (metadata == null) {
        logWarning('Received binary data without metadata from $broadcasterId');
        return;
      }

      _pendingChunks[broadcasterId]!.add(binaryData);
      logInfo('Received chunk ${_pendingChunks[broadcasterId]!.length}/${metadata['totalChunks']} from $broadcasterId');

      if (_pendingChunks[broadcasterId]!.length == metadata['totalChunks']) {
        logInfo('Received all chunks from $broadcasterId, assembling file...');

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
      logError('Error handling binary data from $broadcasterId: $e', stackTrace);
      _pendingMediaMetadata.remove(broadcasterId);
      _pendingChunks.remove(broadcasterId);
    }
  }

  Future<void> _recreateDataChannel(String broadcasterId) async {
    try {
      logInfo('Attempting to recreate data channel for $broadcasterId');

      final connection = _broadcasterConnections[broadcasterId];
      if (connection == null || !connection.isActive) {
        logWarning('Cannot recreate data channel - connection not found or inactive: $broadcasterId');
        return;
      }

      // Закрываем старый канал
      if (connection.dataChannel != null) {
        await _webrtcService.closeDataChannel(connection.dataChannel);
      }

      // Создаем новый канал
      final newChannel = await _webrtcService.createDataChannel(connection.peerConnection, 'commands');
      _broadcasterConnections[broadcasterId] = connection.copyWith(dataChannel: newChannel);
      _setupDataChannel(newChannel, broadcasterId);

      // Ждем открытия канала
      int attempts = 0;
      while (newChannel.state != RTCDataChannelState.RTCDataChannelOpen && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (newChannel.state == RTCDataChannelState.RTCDataChannelOpen) {
        logInfo('Data channel recreated successfully for $broadcasterId');
        onStateChange?.call();
      } else {
        logWarning('Data channel failed to open for $broadcasterId');
      }

    } catch (e, stackTrace) {
      logError('Error recreating data channel for $broadcasterId: $e', stackTrace);
    }
  }

  void _handleBroadcasterDisconnect(String broadcasterId) {
    if (_isDisposed) return;

    logInfo('Handling disconnect from broadcaster: $broadcasterId');

    // Немедленно обновляем состояние и очищаем поток
    _cleanupBroadcasterConnection(broadcasterId, immediate: true);

    // Обновляем primary broadcaster если нужно
    _updatePrimaryBroadcaster();

    // Немедленно уведомляем о изменениях
    onStateChange?.call();
    onBroadcastersChanged?.call(connectedBroadcasters);
    onBroadcasterConnectionChanged?.call(broadcasterId, false);

    // Если отключился primary broadcaster, обновляем поток
    if (_primaryBroadcasterId == broadcasterId) {
      final newPrimary = _broadcasterConnections.values
          .where((conn) => conn.isActive && conn.stream != null)
          .firstOrNull;

      if (newPrimary != null) {
        onStreamChanged?.call(newPrimary.stream);
      } else {
        onStreamChanged?.call(null); // Очищаем поток немедленно
      }
    }
  }

  Future<void> _cleanupBroadcasterConnection(String broadcasterId, {bool immediate = false}) async {
    final connection = _broadcasterConnections[broadcasterId];
    if (connection == null) return;

    logInfo('Cleaning up broadcaster connection: $broadcasterId');

    try {
      // Останавливаем и освобождаем stream немедленно
      if (connection.stream != null) {
        connection.stream!.getTracks().forEach((track) {
          track.stop();
        });
        await connection.stream!.dispose();
      }

      // Закрываем data channel
      if (connection.dataChannel != null) {
        await _webrtcService.closeDataChannel(connection.dataChannel);
      }

      // Закрываем peer connection
      await _webrtcService.closeConnection(connection.peerConnection);

      // Удаляем из карты соединений
      _broadcasterConnections.remove(broadcasterId);

      logInfo('Broadcaster connection cleaned up: $broadcasterId');
    } catch (e, stackTrace) {
      logError('Error cleaning up broadcaster connection $broadcasterId: $e', stackTrace);
    }
  }

  void _updatePrimaryBroadcaster() {
    // Сбрасываем флаг primary у всех
    for (final entry in _broadcasterConnections.entries) {
      if (entry.value.isPrimary) {
        _broadcasterConnections[entry.key] = entry.value.copyWith(isPrimary: false);
      }
    }

    // Если текущий primary broadcaster отключился, выбираем нового
    if (_primaryBroadcasterId == null ||
        !_broadcasterConnections.containsKey(_primaryBroadcasterId) ||
        !_broadcasterConnections[_primaryBroadcasterId]!.isActive) {

      // Находим первого активного broadcaster'а со стримом
      final activeBroadcaster = _broadcasterConnections.values
          .where((conn) => conn.isActive && conn.stream != null)
          .firstOrNull;

      if (activeBroadcaster != null) {
        _primaryBroadcasterId = activeBroadcaster.id;
        _broadcasterConnections[activeBroadcaster.id] = activeBroadcaster.copyWith(isPrimary: true);
        logInfo('New primary broadcaster: ${activeBroadcaster.id}');
      } else {
        _primaryBroadcasterId = null;
        logInfo('No active broadcasters available');
      }
    }
  }

  // Public API methods with improved targeting

  Future<void> sendCommand(String command, {String? targetBroadcasterId}) async {
    final commandData = {
      'action': command,
      'data': <String, dynamic>{},
      'targetId': targetBroadcasterId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _commandQueue.add(commandData);
    logInfo('Command queued: $command for target: ${targetBroadcasterId ?? 'all'}');
  }

  Future<void> sendCommandToAll(String command) async {
    await sendCommand(command); // Без targetId команда пойдет всем
  }

  Future<void> sendCommandToPrimary(String command) async {
    if (_primaryBroadcasterId != null) {
      await sendCommand(command, targetBroadcasterId: _primaryBroadcasterId);
    } else {
      throw Exception('No primary broadcaster available');
    }
  }

  Future<void> changeStreamQuality(dynamic quality, {String? targetBroadcasterId}) async {
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

    final commandData = {
      'action': 'quality',
      'data': {'quality': qualityString},
      'targetId': targetBroadcasterId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    _commandQueue.add(commandData);
    logInfo('Quality change queued: $qualityString for target: ${targetBroadcasterId ?? 'all'}');
  }

  void switchToPrimaryBroadcaster(String broadcasterId) {
    final connection = _broadcasterConnections[broadcasterId];
    if (connection != null && connection.isActive) {
      // Обновляем флаги primary
      for (final entry in _broadcasterConnections.entries) {
        _broadcasterConnections[entry.key] = entry.value.copyWith(
            isPrimary: entry.key == broadcasterId
        );
      }

      _primaryBroadcasterId = broadcasterId;
      onStreamChanged?.call(connection.stream);
      onStateChange?.call();

      logInfo('Switched to primary broadcaster: $broadcasterId');
    }
  }

  // Методы для управления множественными соединениями

  List<String> getActiveBroadcasterIds() {
    return _broadcasterConnections.values
        .where((conn) => conn.isActive)
        .map((conn) => conn.id)
        .toList();
  }

  BroadcasterConnection? getBroadcasterConnection(String broadcasterId) {
    return _broadcasterConnections[broadcasterId];
  }

  bool isBroadcasterActive(String broadcasterId) {
    return _broadcasterConnections[broadcasterId]?.isActive ?? false;
  }

  bool hasBroadcasterStream(String broadcasterId) {
    return _broadcasterConnections[broadcasterId]?.stream != null;
  }

  bool canSendCommandToBroadcaster(String broadcasterId) {
    final connection = _broadcasterConnections[broadcasterId];
    return connection != null &&
        connection.isActive &&
        connection.dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
  }

  // Методы для отключения конкретных broadcaster'ов

  Future<void> disconnectBroadcaster(String broadcasterId) async {
    logInfo('Manually disconnecting broadcaster: $broadcasterId');
    _handleBroadcasterDisconnect(broadcasterId);
  }

  Future<void> disconnectAllBroadcasters() async {
    logInfo('Manually disconnecting all broadcasters');
    final broadcasterIds = List.from(_broadcasterConnections.keys);
    for (final id in broadcasterIds) {
      _handleBroadcasterDisconnect(id);
    }
  }

  // Статистика и мониторинг

  Map<String, dynamic> getConnectionStats() {
    return {
      'total_connections': _broadcasterConnections.length,
      'active_connections': _broadcasterConnections.values.where((conn) => conn.isActive).length,
      'primary_broadcaster': _primaryBroadcasterId,
      'connections_with_streams': _broadcasterConnections.values.where((conn) => conn.stream != null).length,
      'connections_with_data_channels': _broadcasterConnections.values.where((conn) =>
      conn.dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen).length,
      'broadcasters': _broadcasterConnections.values.map((conn) => {
        'id': conn.id,
        'url': conn.url,
        'is_active': conn.isActive,
        'is_primary': conn.isPrimary,
        'has_stream': conn.stream != null,
        'data_channel_state': conn.dataChannel?.state.toString(),
        'peer_connection_state': conn.peerConnection.connectionState.toString(),
        'ice_connection_state': conn.peerConnection.iceConnectionState.toString(),
        'connected_at': conn.connectedAt.toIso8601String(),
      }).toList(),
    };
  }

  Future<void> dispose() async {
    _isDisposed = true;

    try {
      logInfo('Disposing receiver manager...');

      _healthCheckTimer?.cancel();
      _commandTimer?.cancel();
      _stateUpdateTimer?.cancel();

      // Очищаем все соединения
      final broadcasterIds = List.from(_broadcasterConnections.keys);
      for (final id in broadcasterIds) {
        await _cleanupBroadcasterConnection(id, immediate: true);
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
