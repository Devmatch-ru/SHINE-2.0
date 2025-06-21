// ReceiverCubit handles WebRTC receiver state and exposes commands for the UI
import 'package:bloc/bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/utils/receiver_manager.dart';

import 'receiver_state.dart';

class ReceiverCubit extends Cubit<ReceiverState> {
  ReceiverCubit() : super(const ReceiverInitial());

  late final ReceiverManager _manager;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    emit(const ReceiverInitial());

    _manager = ReceiverManager()
      ..onStateChange = _handleStateChange
      ..onStreamChanged = _handleStreamChanged
      ..onError = _handleError
      ..onBroadcastersChanged = _handleBroadcastersChanged;

    try {
      await _manager.init();
      _emitReady();
    } catch (e) {
      emit(ReceiverError(e.toString()));
    }
  }

  List<String> get messages => _manager.messages;

  Future<void> sendCommand(String command) async {
    try {
      await _manager.sendCommand(command);
    } catch (e) {
      emit(ReceiverError(e.toString()));
    }
  }

  Future<void> changeStreamQuality(ReceiverStreamQuality quality) async {
    try {
      await _manager.changeStreamQuality(quality);
    } catch (e) {
      emit(ReceiverError(e.toString()));
    }
  }

  void switchToBroadcaster(String broadcasterUrl) {
    _manager.switchToPrimaryBroadcaster(broadcasterUrl);
  }

  void _handleStateChange() => _emitReady();

  void _handleStreamChanged(MediaStream? _) => _emitReady();

  void _handleBroadcastersChanged(List<String> _) => _emitReady();

  void _handleError(String error) => emit(ReceiverError(error));

  void _emitReady() {
    emit(
      ReceiverReady(
        isConnected: _manager.isConnected,
        remoteStream: _manager.remoteStream,
        connectedBroadcasters: _manager.connectedBroadcasters,
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_isInitialized) {
      await _manager.dispose();
    }
    return super.close();
  }
}
