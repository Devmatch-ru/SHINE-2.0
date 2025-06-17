import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum StreamQuality { low, medium, high }

abstract class ReceiverState extends Equatable {
  final bool isInitializing;
  final bool isConnected;
  final MediaStream? remoteStream;
  final String? connectedBroadcaster;
  final String? error;
  final StreamQuality streamQuality;

  const ReceiverState({
    required this.isInitializing,
    required this.isConnected,
    this.remoteStream,
    this.connectedBroadcaster,
    this.error,
    this.streamQuality = StreamQuality.medium,
  });

  void addLog(String log) {}

  @override
  List<Object?> get props => [
        isInitializing,
        isConnected,
        remoteStream,
        connectedBroadcaster,
        error,
        streamQuality,
      ];
}

class ReceiverInitial extends ReceiverState {
  const ReceiverInitial() : super(isInitializing: true, isConnected: false);
}

class ReceiverReady extends ReceiverState {
  const ReceiverReady({StreamQuality streamQuality = StreamQuality.medium})
      : super(
            isInitializing: false,
            isConnected: false,
            streamQuality: streamQuality);
}

class ReceiverConnected extends ReceiverState {
  const ReceiverConnected({
    required MediaStream stream,
    required String broadcaster,
    StreamQuality streamQuality = StreamQuality.medium,
  }) : super(
          isInitializing: false,
          isConnected: true,
          remoteStream: stream,
          connectedBroadcaster: broadcaster,
          streamQuality: streamQuality,
        );
}

class ReceiverDisconnected extends ReceiverState {
  const ReceiverDisconnected(
      {StreamQuality streamQuality = StreamQuality.medium})
      : super(
            isInitializing: false,
            isConnected: false,
            streamQuality: streamQuality);
}

class ReceiverError extends ReceiverState {
  const ReceiverError(String errorMessage)
      : super(
          isInitializing: false,
          isConnected: false,
          error: errorMessage,
        );
}
