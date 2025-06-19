import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class BroadcasterState extends Equatable {
  final bool isInitializing;
  final bool isConnected;
  final bool isRecording;
  final bool isTimerActive;
  final int timerSeconds;
  final MediaStream? localStream;
  final List<String> connectedReceivers;
  final String? error;
  final String? commandMessage;
  final bool isPowerSaveMode;
  final bool isVideoMode;

  const BroadcasterState({
    required this.isInitializing,
    required this.isConnected,
    required this.isRecording,
    required this.isTimerActive,
    required this.timerSeconds,
    this.localStream,
    this.connectedReceivers = const [],
    this.error,
    this.commandMessage,
    this.isPowerSaveMode = false,
    this.isVideoMode = false,
  });

  @override
  List<Object?> get props => [
        isInitializing,
        isConnected,
        isRecording,
        isTimerActive,
        timerSeconds,
        localStream,
        connectedReceivers,
        error,
        commandMessage,
        isPowerSaveMode,
        isVideoMode,
      ];
}

class BroadcasterInitial extends BroadcasterState {
  const BroadcasterInitial()
      : super(
          isInitializing: true,
          isConnected: false,
          isRecording: false,
          isTimerActive: false,
          timerSeconds: 0,
          isVideoMode: false,
        );
}

class BroadcasterReady extends BroadcasterState {
  const BroadcasterReady({
    required MediaStream stream,
    List<String> connectedReceivers = const [],
    String? commandMessage,
    bool isPowerSaveMode = false,
    bool isVideoMode = false,
  }) : super(
          isInitializing: false,
          isConnected: true,
          isRecording: false,
          isTimerActive: false,
          timerSeconds: 0,
          localStream: stream,
          connectedReceivers: connectedReceivers,
          commandMessage: commandMessage,
          isPowerSaveMode: isPowerSaveMode,
          isVideoMode: isVideoMode,
        );
}

class BroadcasterRecording extends BroadcasterState {
  const BroadcasterRecording({
    required MediaStream stream,
    List<String> connectedReceivers = const [],
    String? commandMessage,
    bool isPowerSaveMode = false,
  }) : super(
          isInitializing: false,
          isConnected: true,
          isRecording: true,
          isTimerActive: false,
          timerSeconds: 0,
          localStream: stream,
          connectedReceivers: connectedReceivers,
          commandMessage: commandMessage,
          isPowerSaveMode: isPowerSaveMode,
          isVideoMode: true,
        );
}

class BroadcasterTimer extends BroadcasterState {
  const BroadcasterTimer({
    required MediaStream stream,
    required int seconds,
    List<String> connectedReceivers = const [],
    String? commandMessage,
    bool isPowerSaveMode = false,
    bool isVideoMode = false,
  }) : super(
          isInitializing: false,
          isConnected: true,
          isRecording: false,
          isTimerActive: true,
          timerSeconds: seconds,
          localStream: stream,
          connectedReceivers: connectedReceivers,
          commandMessage: commandMessage,
          isPowerSaveMode: isPowerSaveMode,
          isVideoMode: isVideoMode,
        );
}

class BroadcasterCommandReceived extends BroadcasterState {
  const BroadcasterCommandReceived({
    required MediaStream stream,
    required String message,
    List<String> connectedReceivers = const [],
    bool isPowerSaveMode = false,
    bool isVideoMode = false,
  }) : super(
          isInitializing: false,
          isConnected: true,
          isRecording: false,
          isTimerActive: false,
          timerSeconds: 0,
          localStream: stream,
          connectedReceivers: connectedReceivers,
          commandMessage: message,
          isPowerSaveMode: isPowerSaveMode,
          isVideoMode: isVideoMode,
        );
}

class BroadcasterError extends BroadcasterState {
  const BroadcasterError(String errorMessage)
      : super(
          isInitializing: false,
          isConnected: false,
          isRecording: false,
          isTimerActive: false,
          timerSeconds: 0,
          error: errorMessage,
          isVideoMode: false,
        );
}
