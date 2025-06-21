import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../core/error_handler.dart';
import '../core/logger.dart';
import '../services/webrtc_service.dart';

class ConnectionManager {
  final Logger _logger = Logger();
  final ErrorHandler _errorHandler = ErrorHandler();
  final WebRTCService _webrtcService = WebRTCService();

  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, MediaStream> _streams = {};
  final Map<String, ConnectionState> _connectionStates = {};

  bool _isDisposed = false;

  // Callbacks
  void Function(String id, RTCIceCandidate candidate)? onIceCandidate;
  void Function(String id, MediaStream stream)? onStreamAdded;
  void Function(String id, RTCDataChannelMessage message)? onDataChannelMessage;
  void Function(String id, ConnectionState state)? onConnectionStateChanged;

  Map<String, RTCPeerConnection> get connections =>
      Map.unmodifiable(_connections);
  Map<String, RTCDataChannel> get dataChannels =>
      Map.unmodifiable(_dataChannels);
  Map<String, MediaStream> get streams => Map.unmodifiable(_streams);

  Future<RTCPeerConnection> createConnection(
    String id, {
    Map<String, dynamic>? config,
    bool createDataChannel = true,
    String dataChannelLabel = 'commands',
  }) async {
    if (_isDisposed) throw Exception('ConnectionManager is disposed');

    try {
      // Close existing connection if any
      await removeConnection(id);

      _logger.log('ConnectionManager', 'Creating connection: $id');

      final pc = await _webrtcService.createPeerConnection(config: config);
      _connections[id] = pc;
      _connectionStates[id] = ConnectionState.connecting;

      _setupConnectionHandlers(id, pc);

      if (createDataChannel) {
        final dataChannel =
            await _webrtcService.createDataChannel(pc, dataChannelLabel);
        _dataChannels[id] = dataChannel;
        _setupDataChannelHandlers(id, dataChannel);
      }

      onConnectionStateChanged?.call(id, ConnectionState.connecting);
      return pc;
    } catch (e) {
      _errorHandler.handleError('ConnectionManager.createConnection', e);
      await removeConnection(id);
      rethrow;
    }
  }

  void _setupConnectionHandlers(String id, RTCPeerConnection pc) {
    pc.onIceCandidate = (candidate) {
      if (_isDisposed) return;
      if (candidate != null) {
        _logger.log('ConnectionManager',
            'ICE candidate for $id: ${candidate.candidate}');
        onIceCandidate?.call(id, candidate);
      }
    };

    pc.onTrack = (event) {
      if (_isDisposed) return;
      if (event.track.kind == 'video') {
        _logger.log('ConnectionManager', 'Video track received for $id');
        _streams[id] = event.streams[0];
        onStreamAdded?.call(id, event.streams[0]);
      }
    };

    pc.onDataChannel = (channel) {
      if (_isDisposed) return;
      _logger.log('ConnectionManager',
          'Data channel received for $id: ${channel.label}');
      _dataChannels[id] = channel;
      _setupDataChannelHandlers(id, channel);
    };

    pc.onIceConnectionState = (state) {
      if (_isDisposed) return;
      _logger.log('ConnectionManager', 'ICE connection state for $id: $state');
      _updateConnectionState(id, state);
    };

    pc.onConnectionState = (state) {
      if (_isDisposed) return;
      _logger.log('ConnectionManager', 'Connection state for $id: $state');
      _updateConnectionState(id, null, connectionState: state);
    };
  }

  void _setupDataChannelHandlers(String id, RTCDataChannel channel) {
    channel.onDataChannelState = (state) {
      if (_isDisposed) return;
      _logger.log('ConnectionManager', 'Data channel state for $id: $state');
    };

    channel.onMessage = (message) {
      if (_isDisposed) return;
      _logger.log('ConnectionManager', 'Data channel message received for $id');
      onDataChannelMessage?.call(id, message);
    };
  }

  void _updateConnectionState(
    String id,
    RTCIceConnectionState? iceState, {
    RTCPeerConnectionState? connectionState,
  }) {
    ConnectionState newState = ConnectionState.connecting;

    if (iceState != null) {
      switch (iceState) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          newState = ConnectionState.connected;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          newState = ConnectionState.disconnected;
          break;
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          newState = ConnectionState.failed;
          break;
        default:
          newState = ConnectionState.connecting;
      }
    }

    if (connectionState != null) {
      switch (connectionState) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          newState = ConnectionState.connected;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          newState = ConnectionState.disconnected;
          break;
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
          newState = ConnectionState.failed;
          break;
        default:
          break;
      }
    }

    if (_connectionStates[id] != newState) {
      _connectionStates[id] = newState;
      onConnectionStateChanged?.call(id, newState);
    }
  }

  Future<void> sendDataChannelMessage(
      String id, Map<String, dynamic> data) async {
    final channel = _dataChannels[id];
    if (channel == null) {
      throw Exception('No data channel found for connection: $id');
    }

    await _webrtcService.sendDataChannelMessage(channel, data);
  }

  Future<void> removeConnection(String id) async {
    _logger.log('ConnectionManager', 'Removing connection: $id');

    await _webrtcService.safeCloseDataChannel(_dataChannels[id]);
    await _webrtcService.safeDisposeStream(_streams[id]);
    await _webrtcService.safeCloseConnection(_connections[id]);

    _connections.remove(id);
    _dataChannels.remove(id);
    _streams.remove(id);
    _connectionStates.remove(id);

    onConnectionStateChanged?.call(id, ConnectionState.disconnected);
  }

  ConnectionState? getConnectionState(String id) => _connectionStates[id];

  /// Returns the underlying RTCPeerConnection for a connection id, if any.
  RTCPeerConnection? getPeerConnection(String id) => _connections[id];

  /// Returns the remote MediaStream associated with a connection id, if any.
  MediaStream? getRemoteStream(String id) => _streams[id];

  bool isConnected(String id) =>
      _connectionStates[id] == ConnectionState.connected;

  List<String> get connectedIds => _connectionStates.entries
      .where((entry) => entry.value == ConnectionState.connected)
      .map((entry) => entry.key)
      .toList();

  Future<void> dispose() async {
    _isDisposed = true;
    _logger.log('ConnectionManager', 'Disposing connection manager...');

    final futures = _connections.keys.map((id) => removeConnection(id));
    await Future.wait(futures);

    _logger.log('ConnectionManager', 'Connection manager disposed');
  }
}

enum ConnectionState {
  connecting,
  connected,
  disconnected,
  failed,
}
