// Receiver bloc state models

import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Very small subset of stream-quality strings that `ReceiverScreen` sends to
/// the broadcaster.  Keep as `String` to avoid tight coupling with
/// `ReceiverManager` which now uses plain text.
enum ReceiverStreamQuality { low, medium, high }

abstract class ReceiverState extends Equatable {
  const ReceiverState({
    required this.isInitializing,
    required this.isConnected,
    this.remoteStream,
    this.connectedBroadcasters = const [],
    this.isFlashOn = false,
    this.error,
  });

  final bool isInitializing;
  final bool isConnected;
  final MediaStream? remoteStream;
  final List<String> connectedBroadcasters;
  final bool isFlashOn;
  final String? error;

  @override
  List<Object?> get props => [
    isInitializing,
    isConnected,
    remoteStream,
    connectedBroadcasters,
    isFlashOn,
    error,
  ];
}

class ReceiverInitial extends ReceiverState {
  const ReceiverInitial() : super(isInitializing: true, isConnected: false);
}

class ReceiverReady extends ReceiverState {
  const ReceiverReady({
    required super.isConnected,
    required super.remoteStream,
    required super.connectedBroadcasters,
    super.isFlashOn,
  }) : super(
    isInitializing: false,
  );
}

class ReceiverError extends ReceiverState {
  const ReceiverError(String message)
      : super(
    isInitializing: false,
    isConnected: false,
    error: message,
  );

  @override
  List<Object?> get props => [...super.props, error];
}
