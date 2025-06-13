import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingServer {
  HttpServer? _server;
  final List<String> _connectedReceivers = [];
  final void Function(String) _onLog;
  final VoidCallback? onStateChange;
  final Future<void> Function(RTCSessionDescription) onAnswer;
  final Future<void> Function(RTCIceCandidate) onCandidate;
  final RTCSessionDescription? Function() getOffer;
  final List<RTCIceCandidate> Function() getCandidates;

  SignalingServer({
    required void Function(String) onLog,
    required this.onAnswer,
    required this.onCandidate,
    required this.getOffer,
    required this.getCandidates,
    this.onStateChange,
  }) : _onLog = onLog;

  List<String> get connectedReceivers => _connectedReceivers;

  Future<void> start() async {
    final handler = shelf.Pipeline().addHandler((request) async {
      _onLog('Request: ${request.method} ${request.url.path}');
      final clientIp = request.context['shelf.io.connection_info']
              is HttpConnectionInfo
          ? (request.context['shelf.io.connection_info'] as HttpConnectionInfo)
              .remoteAddress
              .address
          : 'unknown';

      if (request.method == 'GET' && request.url.path == 'offer') {
        final offer = getOffer();
        if (offer != null) {
          if (!_connectedReceivers.contains(clientIp)) {
            _connectedReceivers.add(clientIp);
            _onLog('Receiver connected: $clientIp');
            onStateChange?.call();
          }
          return shelf.Response.ok(
              jsonEncode({'sdp': offer.sdp, 'type': offer.type}));
        }
        return shelf.Response.internalServerError(body: 'Offer not ready');
      } else if (request.method == 'POST' && request.url.path == 'answer') {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body);
          final answer = RTCSessionDescription(data['sdp'], data['type']);
          await onAnswer(answer);
          _onLog('Answer received from $clientIp');
          if (!_connectedReceivers.contains(clientIp)) {
            _connectedReceivers.add(clientIp);
            _onLog('Receiver connected: $clientIp');
            onStateChange?.call();
          }
          return shelf.Response.ok(jsonEncode({
            'candidates': getCandidates().map((c) => c.toMap()).toList(),
          }));
        } catch (e) {
          _onLog('Error processing answer: $e');
          return shelf.Response.internalServerError(body: 'Error: $e');
        }
      } else if (request.method == 'POST' && request.url.path == 'candidate') {
        try {
          final body = await request.readAsString();
          final data = jsonDecode(body);
          final candidate = RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          );
          await onCandidate(candidate);
          _onLog('Candidate received from $clientIp');
          return shelf.Response.ok('Candidate added');
        } catch (e) {
          _onLog('Error processing candidate: $e');
          return shelf.Response.internalServerError(body: 'Error: $e');
        }
      }
      return shelf.Response.notFound('Not found');
    });

    try {
      _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8080);
      _onLog('Server running on port 8080');
    } catch (e) {
      _onLog('Failed to start server: $e');
    }
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    _connectedReceivers.clear();
  }
}
