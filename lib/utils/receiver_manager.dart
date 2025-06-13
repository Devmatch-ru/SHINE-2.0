import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import './webrtc/types.dart';
import './webrtc/webrtc_connection.dart';
import './webrtc/media_devices_manager.dart';
import 'package:http/http.dart' as http;

class ReceiverManager {
  HttpServer? _server;
  RawDatagramSocket? _udpSocket;
  final Map<String, WebRTCConnection> _connections = {};
  final ValueNotifier<List<String>> messagesNotifier = ValueNotifier([]);
  final _broadcastersController = StreamController<List<String>>.broadcast();
  final List<String> _connectedBroadcasters = [];

  // Callbacks
  final VoidCallback? onStateChange;
  final void Function(String)? onLog;
  final void Function(MediaType type, String path)? onMediaReceived;
  final void Function(MediaStream, String)? onBroadcasterConnected;

  ReceiverManager({
    this.onStateChange,
    this.onLog,
    this.onMediaReceived,
    this.onBroadcasterConnected,
  });

  Stream<List<String>> get connectedBroadcasters =>
      _broadcastersController.stream;
  List<String> get activeBroadcasters =>
      List.unmodifiable(_connectedBroadcasters);

  Future<void> init() async {
    try {
      await _startDiscoveryListener();
      await _startSignalServer();
      _broadcastersController.add(_connectedBroadcasters);
    } catch (e) {
      _addMessage('Error initializing: $e');
      rethrow;
    }
  }

  Future<void> _startDiscoveryListener() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP == null) {
        throw Exception('Could not determine Wi-Fi IP');
      }

      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 9000);
      final response = 'RECEIVER:$wifiIP:8080';

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null &&
              String.fromCharCodes(datagram.data) == 'DISCOVER') {
            _udpSocket!
                .send(response.codeUnits, datagram.address, datagram.port);
            _addMessage('Responded to discovery from ${datagram.address}');
          }
        }
      });

      _addMessage('Discovery listener started on port 9000');
    } catch (e) {
      _addMessage('Error starting discovery: $e');
      rethrow;
    }
  }

  Future<void> _startSignalServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);

      _server!.listen((request) async {
        if (request.method == 'POST') {
          final body = await utf8.decoder.bind(request).join();
          final data = jsonDecode(body);

          switch (request.uri.path) {
            case '/connect':
              await _handleBroadcasterConnect(data, request);
              break;
            case '/disconnect':
              await _handleBroadcasterDisconnect(data, request);
              break;
            case '/offer':
              await _handleOffer(data, request);
              break;
            case '/candidate':
              await _handleCandidate(data, request);
              break;
            default:
              await _sendResponse(request, 404, 'Not Found');
          }
        } else {
          await _sendResponse(request, 405, 'Method Not Allowed');
        }
      });

      _addMessage('Signal server started on port 8080');
    } catch (e) {
      _addMessage('Error starting signal server: $e');
      rethrow;
    }
  }

  Future<void> _handleBroadcasterConnect(
      Map<String, dynamic> data, HttpRequest request) async {
    final broadcasterId = data['broadcasterId'] as String;
    if (!_connections.containsKey(broadcasterId)) {
      final connection = WebRTCConnection(
        onLog: _addMessage,
        onStateChange: () {
          onStateChange?.call();
          _broadcastersController.add(_connectedBroadcasters);
        },
        onRemoteStream: (stream) {
          _addMessage('Remote stream received from $broadcasterId');
          onBroadcasterConnected?.call(stream, broadcasterId);
        },
      );

      _connections[broadcasterId] = connection;
      _connectedBroadcasters.add(broadcasterId);
      _broadcastersController.add(_connectedBroadcasters);

      await _sendResponse(request, 200, 'Connected');
    } else {
      await _sendResponse(request, 409, 'Already connected');
    }
  }

  Future<void> _handleBroadcasterDisconnect(
      Map<String, dynamic> data, HttpRequest request) async {
    final broadcasterId = data['broadcasterId'] as String;
    await _disconnectBroadcaster(broadcasterId);
    _broadcastersController.add(_connectedBroadcasters);
    await _sendResponse(request, 200, 'Disconnected');
  }

  Future<void> _handleOffer(
      Map<String, dynamic> data, HttpRequest request) async {
    final broadcasterId = data['broadcasterId'] as String;
    final connection = _connections[broadcasterId];

    if (connection != null) {
      try {
        // Close existing connection if any
        _addMessage('Closing existing connection for $broadcasterId');
        await connection.close();
        _connections.remove(broadcasterId);
        _connectedBroadcasters.remove(broadcasterId);
        _broadcastersController.add(_connectedBroadcasters);

        // Create new connection
        _addMessage('Creating new WebRTC connection for $broadcasterId');
        final newConnection = WebRTCConnection(
          onLog: (msg) {
            _addMessage('WebRTC($broadcasterId): $msg');
          },
          onStateChange: () {
            _addMessage('Connection state changed for $broadcasterId');
            onStateChange?.call();
            _broadcastersController.add(_connectedBroadcasters);
          },
          onRemoteStream: (stream) {
            _addMessage('Remote stream received from $broadcasterId:');
            _addMessage('- Stream ID: ${stream.id}');
            _addMessage('- Active: ${stream.active}');
            final tracks = stream.getTracks();
            _addMessage('- Tracks count: ${tracks.length}');
            for (var track in tracks) {
              _addMessage(
                  '  - Track: ${track.kind}, enabled: ${track.enabled}, muted: ${track.muted}');
              _addMessage('  - Track settings: ${track.getSettings()}');
            }
            onBroadcasterConnected?.call(stream, broadcasterId);
          },
          onIceCandidate: (candidate) async {
            _addMessage(
                'New ICE candidate for $broadcasterId: ${candidate.candidate}');
            try {
              final response = await http.post(
                Uri.parse('http://$broadcasterId:8081/candidate'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'candidate': candidate.candidate,
                  'sdpMid': candidate.sdpMid,
                  'sdpMLineIndex': candidate.sdpMLineIndex,
                }),
              );
              if (response.statusCode != 200) {
                _addMessage(
                    'Failed to send ICE candidate: ${response.statusCode}');
              }
            } catch (e) {
              _addMessage('Error sending ICE candidate: $e');
            }
          },
          onConnectionFailed: () {
            _addMessage('WebRTC connection failed for $broadcasterId');
            _disconnectBroadcaster(broadcasterId);
          },
        );

        // Initialize connection as receiver
        _addMessage('Initializing connection for $broadcasterId');
        final stream = await navigator.mediaDevices.getUserMedia({
          'audio': false,
          'video': false,
        });
        await newConnection.createConnection(stream, isBroadcaster: false);
        _connections[broadcasterId] = newConnection;
        _connectedBroadcasters.add(broadcasterId);

        // Set remote description (offer)
        _addMessage('Setting remote description (offer) for $broadcasterId');
        _addMessage('Offer SDP: ${data['sdp']}');
        final offer = RTCSessionDescription(data['sdp'], data['type']);
        await newConnection.setRemoteDescription(offer);

        // Create and set local description (answer)
        _addMessage('Creating answer for $broadcasterId');
        final answer = await newConnection.createAnswer();
        _addMessage('Answer SDP: ${answer.sdp}');

        // Send answer back
        await _sendResponse(
          request,
          200,
          jsonEncode({
            'sdp': answer.sdp,
            'type': answer.type,
          }),
        );
        _addMessage('Answer sent to $broadcasterId');

        _broadcastersController.add(_connectedBroadcasters);
      } catch (e) {
        _addMessage('Error handling offer from $broadcasterId: $e');
        await _sendResponse(request, 500, 'Error processing offer');
      }
    } else {
      _addMessage('Broadcaster not found: $broadcasterId');
      await _sendResponse(request, 404, 'Broadcaster not found');
    }
  }

  Future<void> _handleCandidate(
      Map<String, dynamic> data, HttpRequest request) async {
    final broadcasterId = data['broadcasterId'] as String;
    final connection = _connections[broadcasterId];

    if (connection != null) {
      try {
        _addMessage('Received ICE candidate from $broadcasterId:');
        _addMessage('- Candidate: ${data['candidate']}');
        _addMessage('- sdpMid: ${data['sdpMid']}');
        _addMessage('- sdpMLineIndex: ${data['sdpMLineIndex']}');

        final candidate = RTCIceCandidate(
          data['candidate'],
          data['sdpMid'],
          data['sdpMLineIndex'],
        );
        await connection.addIceCandidate(candidate);
        _addMessage('ICE candidate added successfully');
        await _sendResponse(request, 200, 'Candidate added');
      } catch (e) {
        _addMessage('Error adding ICE candidate from $broadcasterId: $e');
        await _sendResponse(request, 500, 'Error adding candidate');
      }
    } else {
      _addMessage(
          'Received ICE candidate for unknown broadcaster: $broadcasterId');
      await _sendResponse(request, 404, 'Broadcaster not found');
    }
  }

  Future<void> _sendResponse(
      HttpRequest request, int statusCode, String body) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(body);
    await request.response.close();
  }

  Future<void> _disconnectBroadcaster(String broadcasterId) async {
    _addMessage('Disconnecting broadcaster: $broadcasterId');
    final connection = _connections.remove(broadcasterId);
    if (connection != null) {
      _addMessage('Closing WebRTC connection');
      await connection.close();
      _connectedBroadcasters.remove(broadcasterId);
      _broadcastersController.add(_connectedBroadcasters);
      _addMessage('Broadcaster disconnected successfully');
    } else {
      _addMessage('No active connection found for broadcaster: $broadcasterId');
    }
  }

  Future<void> requestPhoto(String broadcasterId) async {
    final connection = _connections[broadcasterId];
    if (connection != null) {
      // Send photo capture command through data channel
      // Implementation depends on your data channel protocol
    }
  }

  Future<void> requestVideo(String broadcasterId) async {
    final connection = _connections[broadcasterId];
    if (connection != null) {
      // Send video capture command through data channel
      // Implementation depends on your data channel protocol
    }
  }

  void _addMessage(String message) {
    print('ReceiverManager: $message');
    messagesNotifier.value = [...messagesNotifier.value, message];
    onLog?.call(message);
  }

  Future<void> dispose() async {
    for (var broadcasterId in List.from(_connections.keys)) {
      await _disconnectBroadcaster(broadcasterId);
    }
    await _broadcastersController.close();
    await _server?.close();
    _udpSocket?.close();
  }
}
