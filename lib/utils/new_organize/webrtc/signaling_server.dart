// lib/utils/webrtc/signaling_server.dart (Updated)
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../constants.dart';
import '../service/logging_service.dart';
import '../service/network_service.dart';



class SignalingServer with LoggerMixin {
  @override
  String get loggerContext => 'SignalingServer';

  // Services
  final NetworkService _networkService = NetworkService();

  // Server components
  HttpServer? _server;
  final List<String> _connectedReceivers = [];

  // Callbacks
  final VoidCallback? onStateChange;
  final Future<void> Function(RTCSessionDescription) onAnswer;
  final Future<void> Function(RTCIceCandidate) onCandidate;
  final RTCSessionDescription? Function() getOffer;
  final List<RTCIceCandidate> Function() getCandidates;

  SignalingServer({
    required this.onAnswer,
    required this.onCandidate,
    required this.getOffer,
    required this.getCandidates,
    this.onStateChange,
  });

  // Getters
  List<String> get connectedReceivers => List.unmodifiable(_connectedReceivers);

  Future<void> start() async {
    try {
      logInfo('Starting signaling server...');

      final handler = shelf.Pipeline().addHandler((request) async {
        return _handleHttpRequest(request);
      });

      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        AppConstants.signalingPort,
        shared: true,
      );

      logInfo('Signaling server started on port ${AppConstants.signalingPort}');
    } catch (e, stackTrace) {
      logError('Error starting signaling server: $e', stackTrace);
      rethrow;
    }
  }

  Future<shelf.Response> _handleHttpRequest(shelf.Request request) async {
    final clientIp = _getClientIp(request);
    logInfo('Received ${request.method} ${request.url.path} from $clientIp');

    try {
      if (request.method == 'GET' && request.url.path == 'offer') {
        return _handleOfferRequest(clientIp);
      } else if (request.method == 'POST' && request.url.path == 'answer') {
        return await _handleAnswerRequest(request, clientIp);
      } else if (request.method == 'POST' && request.url.path == 'candidate') {
        return await _handleCandidateRequest(request, clientIp);
      } else if (request.method == 'GET' && request.url.path == 'health') {
        return _handleHealthRequest();
      }

      return shelf.Response.notFound('Not found');
    } catch (e, stackTrace) {
      logError('Error handling HTTP request: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Internal server error');
    }
  }

  String _getClientIp(shelf.Request request) {
    final connectionInfo = request.context['shelf.io.connection_info'];
    if (connectionInfo is HttpConnectionInfo) {
      return connectionInfo.remoteAddress.address;
    }
    return 'unknown';
  }

  shelf.Response _handleOfferRequest(String clientIp) {
    try {
      final offer = getOffer();
      if (offer != null) {
        _addConnectedReceiver(clientIp);

        final response = {
          'sdp': offer.sdp,
          'type': offer.type,
        };

        logInfo('Sent offer to receiver: $clientIp');
        return shelf.Response.ok(jsonEncode(response));
      }

      logWarning('Offer not ready for $clientIp');
      return shelf.Response.internalServerError(body: 'Offer not ready');
    } catch (e, stackTrace) {
      logError('Error handling offer request: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error processing offer');
    }
  }

  Future<shelf.Response> _handleAnswerRequest(shelf.Request request, String clientIp) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return shelf.Response(400, body: 'Empty request body');
      }

      final data = jsonDecode(body);
      if (data['sdp'] == null || data['type'] == null) {
        return shelf.Response(400, body: 'Missing SDP or type in answer');
      }

      final answer = RTCSessionDescription(data['sdp'], data['type']);
      await onAnswer(answer);

      logInfo('Answer received and processed from $clientIp');
      _addConnectedReceiver(clientIp);

      // Return any pending ICE candidates
      final candidates = getCandidates().map((c) => c.toMap()).toList();
      final response = {
        'status': 'ok',
        'candidates': candidates,
      };

      return shelf.Response.ok(jsonEncode(response));
    } catch (e, stackTrace) {
      logError('Error processing answer from $clientIp: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error processing answer');
    }
  }

  Future<shelf.Response> _handleCandidateRequest(shelf.Request request, String clientIp) async {
    try {
      final body = await request.readAsString();
      if (body.isEmpty) {
        return shelf.Response(400, body: 'Empty request body');
      }

      final data = jsonDecode(body);
      final candidateData = data['candidate'];

      if (candidateData == null) {
        return shelf.Response(400, body: 'Missing candidate data');
      }

      final candidate = RTCIceCandidate(
        candidateData['candidate'],
        candidateData['sdpMid'],
        candidateData['sdpMLineIndex'],
      );

      await onCandidate(candidate);
      logInfo('ICE candidate received and processed from $clientIp');

      return shelf.Response.ok('Candidate processed');
    } catch (e, stackTrace) {
      logError('Error processing candidate from $clientIp: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error processing candidate');
    }
  }

  shelf.Response _handleHealthRequest() {
    try {
      final health = {
        'status': 'ok',
        'timestamp': DateTime.now().toIso8601String(),
        'connected_receivers': _connectedReceivers.length,
      };

      return shelf.Response.ok(jsonEncode(health));
    } catch (e, stackTrace) {
      logError('Error handling health request: $e', stackTrace);
      return shelf.Response.internalServerError(body: 'Error checking health');
    }
  }

  void _addConnectedReceiver(String clientIp) {
    if (!_connectedReceivers.contains(clientIp)) {
      _connectedReceivers.add(clientIp);
      logInfo('Receiver connected: $clientIp (total: ${_connectedReceivers.length})');
      onStateChange?.call();
    }
  }

  void removeConnectedReceiver(String clientIp) {
    if (_connectedReceivers.remove(clientIp)) {
      logInfo('Receiver disconnected: $clientIp (remaining: ${_connectedReceivers.length})');
      onStateChange?.call();
    }
  }

  void clearConnectedReceivers() {
    final count = _connectedReceivers.length;
    _connectedReceivers.clear();

    if (count > 0) {
      logInfo('Cleared $count connected receivers');
      onStateChange?.call();
    }
  }

  bool isReceiverConnected(String clientIp) {
    return _connectedReceivers.contains(clientIp);
  }

  Future<void> stop() async {
    try {
      logInfo('Stopping signaling server...');

      await _server?.close();
      _server = null;

      clearConnectedReceivers();

      logInfo('Signaling server stopped successfully');
    } catch (e, stackTrace) {
      logError('Error stopping signaling server: $e', stackTrace);
    }
  }

  Future<void> dispose() => stop();
}