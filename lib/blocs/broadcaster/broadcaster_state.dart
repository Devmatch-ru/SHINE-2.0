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
  final String currentQuality; // ИСПРАВЛЕНИЕ 2: Добавляем текущее качество

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
    this.currentQuality = 'medium', // ИСПРАВЛЕНИЕ 2: Значение по умолчанию
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
    currentQuality, // ИСПРАВЛЕНИЕ 2: Добавляем в props
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
    super.connectedReceivers,
    super.commandMessage,
    super.isPowerSaveMode,
    super.isVideoMode,
    super.currentQuality = 'medium', // ИСПРАВЛЕНИЕ 2: Добавляем параметр
  }) : super(
    isInitializing: false,
    isConnected: true,
    isRecording: false,
    isTimerActive: false,
    timerSeconds: 0,
    localStream: stream,
  );
}

class BroadcasterRecording extends BroadcasterState {
  const BroadcasterRecording({
    required MediaStream stream,
    super.connectedReceivers,
    super.commandMessage,
    super.isPowerSaveMode,
    super.currentQuality = 'medium', // ИСПРАВЛЕНИЕ 2: Добавляем параметр
  }) : super(
    isInitializing: false,
    isConnected: true,
    isRecording: true,
    isTimerActive: false,
    timerSeconds: 0,
    localStream: stream,
    isVideoMode: true,
  );
}

class BroadcasterTimer extends BroadcasterState {
  const BroadcasterTimer({
    required MediaStream stream,
    required int seconds,
    super.connectedReceivers,
    super.commandMessage,
    super.isPowerSaveMode,
    super.isVideoMode,
    super.currentQuality = 'medium', // ИСПРАВЛЕНИЕ 2: Добавляем параметр
  }) : super(
    isInitializing: false,
    isConnected: true,
    isRecording: false,
    isTimerActive: true,
    timerSeconds: seconds,
    localStream: stream,
  );
}

class BroadcasterCommandReceived extends BroadcasterState {
  const BroadcasterCommandReceived({
    required MediaStream stream,
    required String message,
    super.connectedReceivers,
    super.isPowerSaveMode,
    super.isVideoMode,
    super.currentQuality = 'medium', // ИСПРАВЛЕНИЕ 2: Добавляем параметр
  }) : super(
    isInitializing: false,
    isConnected: true,
    isRecording: false,
    isTimerActive: false,
    timerSeconds: 0,
    localStream: stream,
    commandMessage: message,
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
    currentQuality: 'medium', // ИСПРАВЛЕНИЕ 2: Добавляем значение по умолчанию
  );
}