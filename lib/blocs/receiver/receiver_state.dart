import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class ReceiverState extends Equatable {
  final List<String> debugLogs;

  ReceiverState({List<String>? debugLogs}) : debugLogs = debugLogs ?? [];

  void addLog(String log) {
    debugLogs.insert(0, "${DateTime.now().toString().split('.')[0]} - $log");
    if (debugLogs.length > 100) {
      debugLogs.removeLast();
    }
  }

  @override
  List<Object?> get props => [];
}

class ReceiverInitial extends ReceiverState {}

class ReceiverLoading extends ReceiverState {
  ReceiverLoading({super.debugLogs});

  @override
  List<Object> get props => [debugLogs];
}

class ReceiverListening extends ReceiverState {
  final List<String> connectedBroadcasters;
  final Map<String, MediaStream> broadcasterStreams;

  ReceiverListening({
    this.connectedBroadcasters = const [],
    this.broadcasterStreams = const {},
    super.debugLogs,
  });

  @override
  List<Object> get props =>
      [connectedBroadcasters, broadcasterStreams, debugLogs];

  ReceiverListening copyWith({
    List<String>? connectedBroadcasters,
    Map<String, MediaStream>? broadcasterStreams,
    List<String>? debugLogs,
  }) {
    return ReceiverListening(
      connectedBroadcasters:
          connectedBroadcasters ?? this.connectedBroadcasters,
      broadcasterStreams: broadcasterStreams ?? this.broadcasterStreams,
      debugLogs: debugLogs ?? this.debugLogs,
    );
  }
}

class ReceiverError extends ReceiverState {
  final String message;

  ReceiverError(this.message, {super.debugLogs});

  @override
  List<Object> get props => [message, debugLogs];
}
