import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

enum StreamQuality { low, medium, high }

abstract class ReceiverState extends Equatable {
  final bool isInitializing;
  final bool isConnected;
  final MediaStream? remoteStream;
  final String? connectedBroadcaster;
  final StreamQuality streamQuality;
  final String? lastCommand;
  final String? error;
  final String? connectionQuality;
  final int? connectionLatency;
  final String? videoResolution;
  final int? videoBitrate;

  const ReceiverState({
    this.isInitializing = false,
    this.isConnected = false,
    this.remoteStream,
    this.connectedBroadcaster,
    this.streamQuality = StreamQuality.medium,
    this.lastCommand,
    this.error,
    this.connectionQuality,
    this.connectionLatency,
    this.videoResolution,
    this.videoBitrate,
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
        lastCommand,
        connectionQuality,
        connectionLatency,
        videoResolution,
        videoBitrate,
      ];
}

class ReceiverInitial extends ReceiverState {
  const ReceiverInitial() : super(isInitializing: true);
}

class ReceiverReady extends ReceiverState {
  const ReceiverReady({StreamQuality streamQuality = StreamQuality.medium})
      : super(streamQuality: streamQuality);
}

class ReceiverConnected extends ReceiverState {
  const ReceiverConnected({
    required MediaStream? remoteStream,
    required String connectedBroadcaster,
    required StreamQuality streamQuality,
    String? lastCommand,
  }) : super(
          isConnected: true,
          remoteStream: remoteStream,
          connectedBroadcaster: connectedBroadcaster,
          streamQuality: streamQuality,
          lastCommand: lastCommand,
        );
}

class ReceiverDisconnected extends ReceiverState {
  const ReceiverDisconnected({
    required StreamQuality streamQuality,
    String? lastCommand,
  }) : super(
          streamQuality: streamQuality,
          lastCommand: lastCommand,
        );
}

class ReceiverError extends ReceiverState {
  const ReceiverError(String error,
      {StreamQuality streamQuality = StreamQuality.medium})
      : super(error: error, streamQuality: streamQuality);
}
