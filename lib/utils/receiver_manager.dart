import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import './webrtc/types.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

class ReceiverManager {
  HttpServer? _server;
  RawDatagramSocket? _udpSocket;
  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, RTCDataChannel> _dataChannels = {};
  final Map<String, MediaStream> _remoteStreams = {};
  String? _primaryBroadcaster;
  final List<String> _connectedBroadcasters = [];
  bool _isConnected = false;
  bool _isDisposed = false;
  final int maxConnections = 7;
  final ValueNotifier<List<String>> messagesNotifier = ValueNotifier([]);
  final Map<String, List<Map<String, dynamic>>> _earlyRemoteCandidates = {};

  VoidCallback? onStateChange;
  void Function(MediaStream?)? onStreamChanged;
  void Function(String error)? onError;
  void Function(List<String> broadcasters)? onBroadcastersChanged;
  void Function(String mediaType, String filePath)? onMediaReceived;
  void Function(String broadcasterUrl, Uint8List data)? onPhotoReceived;
  void Function(String broadcasterUrl, Uint8List data)? onVideoReceived;

  ReceiverManager();

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
  List<String> get messages => messagesNotifier.value;

  Future<void> init() async {
    try {
      await startDiscoveryListener();
    } catch (e) {
      _addMessage('Error initializing: $e');
      rethrow;
    }
  }

  Future<void> startDiscoveryListener() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP == null) {
        throw Exception('Could not determine Wi-Fi IP');
      }

      _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 9000,
          reuseAddress: true);
      final response = 'RECEIVER:$wifiIP:8080';

      _udpSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _udpSocket!.receive();
          if (datagram != null &&
              String.fromCharCodes(datagram.data) == 'DISCOVER') {
            _udpSocket!.send(
              response.codeUnits,
              datagram.address,
              datagram.port,
            );
            _addMessage('Responded to discovery from ${datagram.address}');
          }
        }
      });

      await _startSignalServer();
      _addMessage('Discovery listener started on port 9000');
    } catch (e) {
      _addMessage('Error starting discovery: $e');
      rethrow;
    }
  }

  Future<void> _startSignalServer() async {
    try {
      final handler = shelf.Pipeline().addHandler((request) async {
        _addMessage('Received ${request.method} ${request.url.path}');

        if (request.method == 'POST' && request.url.path == 'offer') {
          try {
            final contentType = request.headers['content-type'];
            if (contentType == null ||
                !contentType.contains('application/json')) {
              return shelf.Response(400, body: 'Invalid content type');
            }

            final body = await request.readAsString();
            if (body.isEmpty) {
              return shelf.Response(400, body: 'Empty request body');
            }

            Map<String, dynamic> data;
            try {
              data = jsonDecode(body);
            } catch (e) {
              return shelf.Response(400, body: 'Invalid JSON format: $e');
            }

            if (data['sdp'] == null ||
                data['type'] == null ||
                data['broadcasterUrl'] == null) {
              return shelf.Response(400, body: 'Missing required fields');
            }

            final offer = RTCSessionDescription(data['sdp'], data['type']);
            final broadcasterUrl = data['broadcasterUrl'];

            _addMessage('Processing offer from $broadcasterUrl');

            if (_connections.containsKey(broadcasterUrl)) {
              await _connections[broadcasterUrl]?.close();
              _connections.remove(broadcasterUrl);
              _dataChannels.remove(broadcasterUrl);
              if (_remoteStreams.containsKey(broadcasterUrl)) {
                _remoteStreams[broadcasterUrl]
                    ?.getTracks()
                    .forEach((track) => track.stop());
                await _remoteStreams[broadcasterUrl]?.dispose();
                _remoteStreams.remove(broadcasterUrl);
              }
              _connectedBroadcasters.remove(broadcasterUrl);
              onBroadcastersChanged?.call(_connectedBroadcasters);
            }

            if (_connections.length >= maxConnections) {
              return shelf.Response(503, body: 'Maximum connections reached');
            }

            final pc = await createPeerConnection({
              'iceServers': [
                {
                  'urls': ['stun:stun1.l.google.com:19302']
                },
              ],
              'sdpSemantics': 'unified-plan',
              'bundlePolicy': 'max-bundle',
              'rtcpMuxPolicy': 'require',
              'iceTransportPolicy': 'all',
              'offerToReceiveVideo': true,
              'offerToReceiveAudio': false,
            });

            if (pc == null) {
              throw Exception('Failed to create peer connection');
            }

            pc.onIceCandidate = (candidate) {
              _addMessage('New ICE candidate: ${candidate.candidate}');
              _sendIceCandidate(candidate, broadcasterUrl);
            };

            pc.onDataChannel = (channel) {
              _addMessage('Received data channel: ${channel.label}');
              _dataChannels[broadcasterUrl] = channel;
              _setupDataChannel(channel, broadcasterUrl);
            };

            pc.onIceConnectionState = (state) {
              _addMessage('ICE connection state: $state');
              if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
                if (!_connectedBroadcasters.contains(broadcasterUrl)) {
                  _connectedBroadcasters.add(broadcasterUrl);
                  onBroadcastersChanged?.call(_connectedBroadcasters);
                }
              } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
                  state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
                _handleDisconnection(broadcasterUrl);
              }
            };

            pc.onTrack = (event) {
              _addMessage('Received track: ${event.track.kind}, enabled: ${event.track.enabled}');
              if (event.track.kind == 'video') {
                _remoteStreams[broadcasterUrl] = event.streams[0];
                final videoTracks = event.streams[0].getVideoTracks();
                _addMessage('Video tracks: ${videoTracks.length}, enabled: ${videoTracks.isNotEmpty ? videoTracks[0].enabled : 'N/A'}');
                if (_primaryBroadcaster == null) {
                  _primaryBroadcaster = broadcasterUrl;
                }
                onStreamChanged?.call(_remoteStreams[_primaryBroadcaster]);
                onStateChange?.call();
              }
            };

            await pc.setRemoteDescription(offer);
            final answer = await pc.createAnswer();
            await pc.setLocalDescription(answer);

            if (_earlyRemoteCandidates.containsKey(broadcasterUrl)) {
              for (final cand in _earlyRemoteCandidates[broadcasterUrl]!) {
                try {
                  await pc.addCandidate(RTCIceCandidate(
                    cand['candidate'],
                    cand['sdpMid'],
                    cand['sdpMLineIndex'],
                  ));
                } catch (e) {
                  _addMessage('Failed to add buffered candidate: $e');
                }
              }
              _earlyRemoteCandidates.remove(broadcasterUrl);
            }

            _connections[broadcasterUrl] = pc;
            _addMessage('Connection established with $broadcasterUrl');

            return shelf.Response.ok(
              jsonEncode({'sdp': answer.sdp, 'type': answer.type}),
              headers: {'Content-Type': 'application/json'},
            );
          } catch (e) {
            _addMessage('Error processing offer: $e');
            return shelf.Response.internalServerError(body: 'Error: $e');
          }
        }

        if (request.method == 'POST' && request.url.path == 'candidate') {
          try {
            final body = await request.readAsString();
            if (body.isEmpty) {
              return shelf.Response(400, body: 'Empty request body');
            }

            Map<String, dynamic> data;
            try {
              data = jsonDecode(body);
            } catch (e) {
              return shelf.Response(400, body: 'Invalid JSON: $e');
            }

            final candidateMap =
                data.containsKey('candidate') ? data['candidate'] : data;

            final connectionInfo = request.context['shelf.io.connection_info']
                as HttpConnectionInfo;
            final remoteIp = connectionInfo.remoteAddress.address;
            final broadcasterUrl = 'http://$remoteIp:8080';

            if (!_connections.containsKey(broadcasterUrl)) {
              _earlyRemoteCandidates
                  .putIfAbsent(broadcasterUrl, () => [])
                  .add(candidateMap);
              _addMessage('Buffered ICE candidate for $broadcasterUrl');
              return shelf.Response.ok('Buffered');
            }

            final candidate = RTCIceCandidate(
              candidateMap['candidate'],
              candidateMap['sdpMid'],
              candidateMap['sdpMLineIndex'],
            );

            await _connections[broadcasterUrl]!.addCandidate(candidate);
            _addMessage('Added ICE candidate from $broadcasterUrl');

            return shelf.Response.ok('OK');
          } catch (e) {
            _addMessage('Error processing candidate: $e');
            return shelf.Response.internalServerError(body: 'Error: $e');
          }
        }

        return shelf.Response.notFound('Not found');
      });

      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        8080,
        shared: true,
      );
      _addMessage('Signal server started on port 8080');
    } catch (e) {
      _addMessage('Error starting signal server: $e');
      rethrow;
    }
  }

  void _handleDisconnection(String broadcasterUrl) {
    _addMessage('Handling disconnection from $broadcasterUrl');
    _connections.remove(broadcasterUrl);
    _dataChannels.remove(broadcasterUrl);
    if (_remoteStreams.containsKey(broadcasterUrl)) {
      _remoteStreams[broadcasterUrl]
          ?.getTracks()
          .forEach((track) => track.stop());
      _remoteStreams[broadcasterUrl]?.dispose();
      _remoteStreams.remove(broadcasterUrl);
    }
    _connectedBroadcasters.remove(broadcasterUrl);

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

  Future<void> _sendIceCandidate(
      RTCIceCandidate candidate, String receiverUrl) async {
    try {
      String formattedUrl = receiverUrl;
      if (!formattedUrl.startsWith('http://') &&
          !formattedUrl.startsWith('https://')) {
        formattedUrl = 'http://$receiverUrl';
      }
      formattedUrl = formattedUrl
          .replaceFirst('http://http://', 'http://')
          .replaceFirst('http://http//', 'http://');
      final response = await http.post(
        Uri.parse('$formattedUrl/candidate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'candidate': candidate.toMap()}),
      );
      if (response.statusCode != 200) {
        _addMessage('Failed to send ICE candidate: ${response.statusCode}');
      }
    } catch (e) {
      _addMessage('Error sending ICE candidate: $e');
    }
  }

  void _setupPeerConnectionHandlers(
      RTCPeerConnection pc, String broadcasterUrl) {
    if (_isDisposed) return;
    pc.onTrack = (event) {
      if (_isDisposed) return;
      if (event.track.kind == 'video') {
        _addMessage('Received video track: ${event.track.id}, enabled: ${event.track.enabled}');
        _remoteStreams[broadcasterUrl] = event.streams[0];
        final videoTracks = event.streams[0].getVideoTracks();
        _addMessage('Video tracks: ${videoTracks.length}, enabled: ${videoTracks.isNotEmpty ? videoTracks[0].enabled : 'N/A'}');
        if (_primaryBroadcaster == null) {
          _primaryBroadcaster = broadcasterUrl;
        }
        onStreamChanged?.call(_remoteStreams[_primaryBroadcaster]);
        _verifyConnection(broadcasterUrl);
      }
    };

    pc.onIceCandidate = (candidate) async {
      if (_isDisposed) return;
      if (candidate == null) {
        _addMessage('ICE gathering completed');
        return;
      }
      _addMessage('Generated ICE candidate: ${candidate.candidate}');

      try {
        await http.post(
          Uri.parse('$broadcasterUrl/candidate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'candidate': candidate.toMap()}),
        );
        _addMessage('Sent ICE candidate to broadcaster');
      } catch (e) {
        _addMessage('Failed to send ICE candidate: $e');
      }
    };

    pc.onDataChannel = (channel) {
      _addMessage('Received data channel: ${channel.label}');
      _dataChannels[broadcasterUrl] = channel;
      _setupDataChannel(channel, broadcasterUrl);
    };

    pc.onIceConnectionState = (state) {
      if (_isDisposed) return;
      _addMessage('ICE connection state changed to: $state');

      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        Future.delayed(Duration(seconds: 5), () {
          if (pc.iceConnectionState ==
              RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
            _handleDisconnect(broadcasterUrl);
          }
        });
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _handleDisconnect(broadcasterUrl);
      } else if (state ==
          RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _addMessage('ICE Connection restored');
        _isConnected = true;
        onStateChange?.call();
      }
    };

    pc.onConnectionState = (state) {
      if (_isDisposed) return;
      _addMessage('Connection State: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        Future.delayed(Duration(seconds: 5), () {
          if (pc.connectionState ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
            _handleDisconnect(broadcasterUrl);
          }
        });
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _handleDisconnect(broadcasterUrl);
      } else if (state ==
          RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _addMessage('Connection restored');
        _isConnected = true;
        onStateChange?.call();
      }
    };
  }

  void _setupDataChannel(RTCDataChannel channel, String broadcasterUrl) {
    channel.onDataChannelState = (state) {
      _addMessage('Data channel state for $broadcasterUrl: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _addMessage('Data channel is now OPEN and ready for communication');
        _verifyConnection(broadcasterUrl);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _addMessage('Data channel is now CLOSED');
        if (_connections[broadcasterUrl]?.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _handleDataChannelReconnect(broadcasterUrl);
        }
        _verifyConnection(broadcasterUrl);
      }
    };

    channel.onMessage = (message) {
      _addMessage('Received message from $broadcasterUrl');
      if (message.type == MessageType.text) {
        try {
          final data = jsonDecode(message.text);
          final messageType = data['type'] as String;

          switch (messageType) {
            case 'media_metadata':
              _handleMediaMetadata(broadcasterUrl, data);
              break;
            case 'command':
              break;
            default:
              _addMessage('Unknown message type: $messageType');
          }
        } catch (e) {
          _addMessage('Error processing message: $e');
        }
      } else if (message.type == MessageType.binary) {
        _handleBinaryData(broadcasterUrl, message.binary!);
      }
    };
  }

  void _verifyConnection(String broadcasterUrl) {
    if (_isDisposed) return;

    final hasStream = _remoteStreams.containsKey(broadcasterUrl);
    final hasDataChannel = _dataChannels[broadcasterUrl]?.state ==
        RTCDataChannelState.RTCDataChannelOpen;

    _addMessage(
        'Verifying connection - Stream: $hasStream, DataChannel: $hasDataChannel');

    if (hasStream && !hasDataChannel) {
      _addMessage(
          'Stream exists but no data channel, attempting to create one...');
      _handleDataChannelReconnect(broadcasterUrl);
    }

    _isConnected = hasStream && hasDataChannel;
    onStateChange?.call();
  }

  Future<RTCDataChannel?> _handleDataChannelReconnect(
      String broadcasterUrl) async {
    _addMessage('Attempting to reestablish data channel for $broadcasterUrl');

    try {
      final pc = _connections[broadcasterUrl];
      if (pc != null) {
        if (_dataChannels[broadcasterUrl] != null) {
          await _dataChannels[broadcasterUrl]!.close();
          _dataChannels.remove(broadcasterUrl);
        }

        int attempts = 0;
        const maxAttempts = 3;
        RTCDataChannel? newChannel;

        while (attempts < maxAttempts &&
            (newChannel == null ||
                newChannel.state != RTCDataChannelState.RTCDataChannelOpen)) {
          try {
            newChannel = await pc.createDataChannel(
              'commands',
              RTCDataChannelInit()
                ..ordered = true
                ..maxRetransmits = 3
                ..protocol = 'sctp'
                ..negotiated = false,
            );

            _dataChannels[broadcasterUrl] = newChannel;
            _setupDataChannel(newChannel, broadcasterUrl);

            int waitAttempts = 0;
            while (newChannel.state != RTCDataChannelState.RTCDataChannelOpen &&
                waitAttempts < 50) {
              await Future.delayed(const Duration(milliseconds: 100));
              waitAttempts++;
            }

            if (newChannel.state == RTCDataChannelState.RTCDataChannelOpen) {
              _addMessage('Data channel recreated and opened successfully');
              return newChannel;
            }
          } catch (e) {
            _addMessage('Attempt ${attempts + 1} failed: $e');
          }

          attempts++;
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: attempts));
          }
        }
      }
    } catch (e) {
      _addMessage('Error recreating data channel: $e');
    }
    return null;
  }

  void _handleDisconnect(String broadcasterUrl) {
    if (_isDisposed) return;

    _addMessage('Handling disconnect from $broadcasterUrl');

    _connectedBroadcasters.remove(broadcasterUrl);
    _connections.remove(broadcasterUrl);
    _dataChannels.remove(broadcasterUrl);

    if (_remoteStreams.containsKey(broadcasterUrl)) {
      _remoteStreams[broadcasterUrl]
          ?.getTracks()
          .forEach((track) => track.stop());
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

    _addMessage('Attempting to reconnect to $broadcasterUrl');

    try {
      final response = await http
          .get(Uri.parse('$broadcasterUrl/health'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _addMessage('Broadcaster available, attempting reconnection...');
        await _initializeConnection(broadcasterUrl);
      } else {
        _addMessage(
            'Broadcaster not available (status: ${response.statusCode})');

        Future.delayed(const Duration(seconds: 5), () {
          _attemptReconnect(broadcasterUrl);
        });
      }
    } catch (e) {
      _addMessage('Reconnection attempt failed: $e');

      if (!_isDisposed) {
        Future.delayed(const Duration(seconds: 5), () {
          _attemptReconnect(broadcasterUrl);
        });
      }
    }
  }

  Future<void> _initializeConnection(String broadcasterUrl) async {
    try {
      final pc = await createPeerConnection({
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
      });

      _setupPeerConnectionHandlers(pc, broadcasterUrl);
      _connections[broadcasterUrl] = pc;

      if (!_connectedBroadcasters.contains(broadcasterUrl)) {
        _connectedBroadcasters.add(broadcasterUrl);
      }

      onStateChange?.call();
      onBroadcastersChanged?.call(_connectedBroadcasters);
    } catch (e) {
      _addMessage('Failed to initialize connection: $e');
      throw Exception('Failed to initialize connection: $e');
    }
  }

  void switchToPrimaryBroadcaster(String broadcasterUrl) {
    if (_connectedBroadcasters.contains(broadcasterUrl)) {
      _primaryBroadcaster = broadcasterUrl;
      onStreamChanged?.call(_remoteStreams[broadcasterUrl]);
      onStateChange?.call();
    }
  }

  Future<void> sendCommandToAll(String command) async {
    if (_dataChannels.isEmpty) {
      throw Exception('No active connection or data channel');
    }

    final message = jsonEncode({
      'type': 'command',
      'action': command,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    var sentToAny = false;
    var errors = <String>[];

    for (var entry in _dataChannels.entries) {
      try {
        if (entry.value.state == RTCDataChannelState.RTCDataChannelOpen) {
          await entry.value.send(RTCDataChannelMessage(message));
          _addMessage('Command sent to ${entry.key}: $command');
          sentToAny = true;
        } else {
          errors.add('Data channel not open for ${entry.key}');
        }
      } catch (e) {
        errors.add('Error sending to ${entry.key}: $e');
      }
    }

    if (!sentToAny) {
      final errorMessage = 'Failed to send command: ${errors.join(", ")}';
      _addMessage(errorMessage);
      throw Exception(errorMessage);
    }
  }

  Future<void> sendCommand(String command) async {
    if (_connections[_primaryBroadcaster] == null) {
      _addMessage('No active connection found');
      throw Exception('No active connection');
    }

    if (_dataChannels[_primaryBroadcaster] == null) {
      _addMessage('No data channel found, attempting to create one...');
      final newChannel =
          await _handleDataChannelReconnect(_primaryBroadcaster!);
      if (newChannel == null) {
        throw Exception('Failed to create data channel');
      }
    }

    int attempts = 0;
    while (_dataChannels[_primaryBroadcaster]?.state !=
            RTCDataChannelState.RTCDataChannelOpen &&
        attempts < 150) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      if (attempts % 30 == 0) {
        _addMessage(
            'Still waiting for data channel to open... ${attempts / 10} seconds passed');
      }
    }

    if (_dataChannels[_primaryBroadcaster]?.state !=
        RTCDataChannelState.RTCDataChannelOpen) {
      _addMessage('Data channel failed to open after 15 seconds');
      final newChannel =
          await _handleDataChannelReconnect(_primaryBroadcaster!);
      if (newChannel == null ||
          newChannel.state != RTCDataChannelState.RTCDataChannelOpen) {
        throw Exception('Data channel is not open after multiple attempts');
      }
    }

    final commandData = jsonEncode({
      'type': 'command',
      'action': command,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });

    try {
      await _dataChannels[_primaryBroadcaster]!
          .send(RTCDataChannelMessage(commandData));
      _addMessage('Successfully sent command: $command');
    } catch (e) {
      _addMessage('Error sending command: $e');
      final newChannel =
          await _handleDataChannelReconnect(_primaryBroadcaster!);
      if (newChannel == null) {
        throw Exception('Failed to recreate data channel after send error');
      }
      throw Exception('Failed to send command: $e');
    }
  }

  Future<void> changeStreamQuality(dynamic quality) async {
    if (_connections[_primaryBroadcaster] == null ||
        _dataChannels[_primaryBroadcaster] == null) {
      throw Exception('No active connection or data channel');
    }

    int attempts = 0;
    while (_dataChannels[_primaryBroadcaster]!.state !=
            RTCDataChannelState.RTCDataChannelOpen &&
        attempts < 100) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }

    if (_dataChannels[_primaryBroadcaster]!.state !=
        RTCDataChannelState.RTCDataChannelOpen) {
      throw Exception('Data channel is not open after waiting');
    }

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

    final qualityData = jsonEncode({
      'type': 'quality_change',
      'quality': qualityString,
    });

    try {
      await _dataChannels[_primaryBroadcaster]!
          .send(RTCDataChannelMessage(qualityData));
      _addMessage('Successfully changed stream quality to: $qualityString');
    } catch (e) {
      _addMessage('Error changing quality: $e');
      throw Exception('Failed to change quality: $e');
    }
  }

  void _addMessage(String message) {
    if (_isDisposed) return;
    final currentMessages = List<String>.from(messagesNotifier.value);
    currentMessages
        .add('${DateTime.now().toString().split('.').first}: $message');
    messagesNotifier.value = currentMessages;
  }

  Future<void> dispose() async {
    _isDisposed = true;
    try {
      for (var channel in _dataChannels.values) {
        await channel.close();
      }
      for (var stream in _remoteStreams.values) {
        stream.getTracks().forEach((track) => track.stop());
        await stream.dispose();
      }
      for (var connection in _connections.values) {
        await connection.close();
      }
      await _server?.close();
      _udpSocket?.close();
      messagesNotifier.dispose();
    } catch (e) {
      print('Error during disposal: $e');
    }
  }

  Map<String, Map<String, dynamic>> _pendingMediaMetadata = {};
  Map<String, List<Uint8List>> _pendingChunks = {};

  void _handleMediaMetadata(String broadcasterId, Map<String, dynamic> data) {
    _addMessage('Received media metadata from $broadcasterId');
    _pendingMediaMetadata.remove(broadcasterId);
    _pendingChunks.remove(broadcasterId);

    _pendingMediaMetadata[broadcasterId] = data;
    _pendingChunks[broadcasterId] = [];
    _addMessage(
        'Expecting ${data['totalChunks']} chunks for ${data['fileName']}');
  }

  void _handleMediaData(String broadcasterUrl, Map<String, dynamic> data) {
    _addMessage('Handling media data from $broadcasterUrl');
    try {
      final mediaType = data['mediaType'];
      final mediaData = data['data'];
      final timestamp =
          data['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
      final fileName = data['fileName'] ?? '${timestamp}_${mediaType}';

      _saveMediaToDevice(
          broadcasterUrl, mediaType, mediaData, fileName, timestamp);
    } catch (e) {
      _addMessage('Error handling media data: $e');
    }
  }

  void _handleBinaryData(String broadcasterId, Uint8List binaryData) async {
    try {
      final metadata = _pendingMediaMetadata[broadcasterId];
      if (metadata == null) {
        _addMessage(
            'Received binary data without metadata from $broadcasterId');
        return;
      }

      _pendingChunks[broadcasterId]!.add(binaryData);
      _addMessage(
          'Received chunk ${_pendingChunks[broadcasterId]!.length}/${metadata['totalChunks']}');

      if (_pendingChunks[broadcasterId]!.length == metadata['totalChunks']) {
        _addMessage('Received all chunks, assembling file...');

        final allBytes = Uint8List(metadata['fileSize']);
        var offset = 0;
        for (var chunk in _pendingChunks[broadcasterId]!) {
          allBytes.setRange(offset, offset + chunk.length, chunk);
          offset += chunk.length;
        }

        final fileName = metadata['fileName'] as String;
        final mediaType = metadata['mediaType'] as String;
        final timestamp = metadata['timestamp'] as int;

        await _saveMediaToDevice(
            broadcasterId, mediaType, allBytes, fileName, timestamp);

        _pendingMediaMetadata.remove(broadcasterId);
        _pendingChunks.remove(broadcasterId);
      }
    } catch (e) {
      _addMessage('Error handling binary data: $e');
      _pendingMediaMetadata.remove(broadcasterId);
      _pendingChunks.remove(broadcasterId);
    }
  }

  Future<void> _saveMediaToDevice(String broadcasterUrl, String mediaType,
      Uint8List binaryData, String fileName, int timestamp) async {
    try {
      _addMessage('Saving $mediaType to device: $fileName');

      final directory = await getTemporaryDirectory();
      final mediaDir = Directory('${directory.path}/received_media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final filePath = '${mediaDir.path}/${timestamp}_$fileName';
      final file = File(filePath);

      await file.writeAsBytes(binaryData);
      _addMessage('File saved to: $filePath');

      if (mediaType == 'photo') {
        await GallerySaver.saveImage(
          filePath,
          albumName: 'Shine',
        );
        _addMessage('Photo saved to gallery');
        onPhotoReceived?.call(broadcasterUrl, binaryData);
      } else if (mediaType == 'video') {
        await GallerySaver.saveVideo(
          filePath,
          albumName: 'Shine',
        );
        _addMessage('Video saved to gallery');
        onVideoReceived?.call(broadcasterUrl, binaryData);
      }

      onMediaReceived?.call(mediaType, filePath);
    } catch (e) {
      _addMessage('Error saving media to device: $e');
    }
  }
}