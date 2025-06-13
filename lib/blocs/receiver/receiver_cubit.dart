import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/receiver_manager.dart';
import './receiver_state.dart';

class ReceiverCubit extends Cubit<ReceiverState> {
  final ReceiverManager _receiverManager;
  StreamSubscription? _broadcastersSubscription;
  Timer? _reconnectionTimer;
  bool _isListening = false;

  ReceiverCubit({required ReceiverManager receiverManager})
      : _receiverManager = receiverManager,
        super(ReceiverInitial());

  Future<void> startListening() async {
    if (_isListening) return;

    try {
      final currentLogs = state.debugLogs;
      emit(ReceiverLoading(debugLogs: currentLogs)
        ..addLog('Starting receiver...'));

      _isListening = true;
      await _receiverManager.init();

      _broadcastersSubscription = _receiverManager.connectedBroadcasters.listen(
        (broadcasters) {
          if (state is ReceiverListening) {
            final currentState = state as ReceiverListening;
            currentState.addLog(
                'Broadcasters updated: ${broadcasters.length} connected');
            emit(currentState.copyWith(connectedBroadcasters: broadcasters));
          } else {
            final newState = ReceiverListening(
              connectedBroadcasters: broadcasters,
              debugLogs: state.debugLogs,
            )..addLog('Initial broadcasters: ${broadcasters.length}');
            emit(newState);
          }
        },
        onError: (error) {
          final currentLogs = state.debugLogs;
          emit(ReceiverError('Broadcaster subscription error: $error',
              debugLogs: currentLogs)
            ..addLog('Error in broadcaster subscription: $error'));
          _startReconnectionTimer();
        },
      );

      emit(ReceiverListening(debugLogs: state.debugLogs)
        ..addLog('Receiver started successfully'));
    } catch (e) {
      final currentLogs = state.debugLogs;
      emit(ReceiverError('Failed to start receiver: $e', debugLogs: currentLogs)
        ..addLog('Startup error: $e'));
      _startReconnectionTimer();
    }
  }

  void _startReconnectionTimer() {
    final currentLogs = state.debugLogs;
    currentLogs.add('Starting reconnection timer...');

    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(const Duration(seconds: 5), () {
      if (state is ReceiverError) {
        currentLogs.add('Attempting to reconnect...');
        startListening();
      }
    });
  }

  Future<void> requestPhoto(String broadcasterId) async {
    try {
      await _receiverManager.requestPhoto(broadcasterId);
    } catch (e) {
      emit(ReceiverError(e.toString()));
    }
  }

  Future<void> requestVideo(String broadcasterId) async {
    try {
      await _receiverManager.requestVideo(broadcasterId);
    } catch (e) {
      emit(ReceiverError(e.toString()));
    }
  }

  void _handleBroadcasterStream(MediaStream stream, String broadcasterId) {
    if (state is ReceiverListening) {
      final currentState = state as ReceiverListening;
      final updatedStreams =
          Map<String, MediaStream>.from(currentState.broadcasterStreams);

      currentState
          .addLog('Handling new stream from broadcaster: $broadcasterId');
      currentState.addLog('Stream tracks: ${stream.getTracks().length}');
      stream.getTracks().forEach((track) {
        currentState.addLog(
            'Track: ${track.kind}, enabled: ${track.enabled}, muted: ${track.muted}');
      });

      // Dispose old stream if exists
      if (updatedStreams.containsKey(broadcasterId)) {
        final oldStream = updatedStreams[broadcasterId]!;
        currentState.addLog('Disposing old stream from $broadcasterId');
        oldStream.getTracks().forEach((track) => track.stop());
        oldStream.dispose();
      }

      updatedStreams[broadcasterId] = stream;
      emit(currentState.copyWith(
        broadcasterStreams: updatedStreams,
        debugLogs: currentState.debugLogs,
      ));
    }
  }

  void _handleBroadcasterDisconnect(String broadcasterId) {
    if (state is ReceiverListening) {
      final currentState = state as ReceiverListening;
      final updatedStreams =
          Map<String, MediaStream>.from(currentState.broadcasterStreams);

      currentState.addLog('Broadcaster disconnected: $broadcasterId');

      // Cleanup disconnected broadcaster's stream
      if (updatedStreams.containsKey(broadcasterId)) {
        final stream = updatedStreams[broadcasterId]!;
        currentState.addLog('Cleaning up stream from disconnected broadcaster');
        stream.getTracks().forEach((track) => track.stop());
        stream.dispose();
        updatedStreams.remove(broadcasterId);
      }

      emit(currentState.copyWith(
        broadcasterStreams: updatedStreams,
        debugLogs: currentState.debugLogs,
      ));
    }
  }

  @override
  Future<void> close() async {
    state.addLog('Closing receiver cubit...');
    _isListening = false;
    await _broadcastersSubscription?.cancel();
    _reconnectionTimer?.cancel();

    // Cleanup all streams
    if (state is ReceiverListening) {
      final currentState = state as ReceiverListening;
      currentState.addLog('Cleaning up all streams...');
      for (var entry in currentState.broadcasterStreams.entries) {
        currentState.addLog('Disposing stream from ${entry.key}');
        final stream = entry.value;
        stream.getTracks().forEach((track) => track.stop());
        stream.dispose();
      }
    }

    await _receiverManager.dispose();
    state.addLog('Receiver cubit closed');
    return super.close();
  }
}
