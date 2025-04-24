import 'dart:async';

abstract class SignalingService {
  Future<void> connect({required String role, required String roomId});
  Stream<String> get onMessage;
  Future<void> send(String message);
  Future<void> disconnect();

  static final SignalingService instance = _SignalingServiceImpl();
}

class _SignalingServiceImpl implements SignalingService {
  final _messages = StreamController<String>.broadcast();

  @override
  Future<void> connect({required String role, required String roomId}) async {
    // TODO: open WebSocket and join room
  }

  @override
  Stream<String> get onMessage => _messages.stream;

  @override
  Future<void> send(String message) async {
    // TODO: send over WebSocket
  }

  @override
  Future<void> disconnect() async {
    // TODO: close WebSocket
    await _messages.close();
  }
}
