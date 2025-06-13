import 'package:equatable/equatable.dart';
import 'package:camera/camera.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class BroadcasterState extends Equatable {
  const BroadcasterState();

  @override
  List<Object?> get props => [];
}

class BroadcasterInitial extends BroadcasterState {}

class BroadcasterLoading extends BroadcasterState {}

class BroadcasterReady extends BroadcasterState {
  final CameraController camera;
  final MediaStream? localStream;
  final bool isBroadcasting;
  final bool isRecording;
  final bool isFlashlightOn;
  final String? connectedReceiver;

  const BroadcasterReady({
    required this.camera,
    this.localStream,
    this.isBroadcasting = false,
    this.isRecording = false,
    this.isFlashlightOn = false,
    this.connectedReceiver,
  });

  @override
  List<Object?> get props => [
        camera,
        localStream,
        isBroadcasting,
        isRecording,
        isFlashlightOn,
        connectedReceiver,
      ];

  BroadcasterReady copyWith({
    CameraController? camera,
    MediaStream? localStream,
    bool? isBroadcasting,
    bool? isRecording,
    bool? isFlashlightOn,
    String? connectedReceiver,
  }) {
    return BroadcasterReady(
      camera: camera ?? this.camera,
      localStream: localStream ?? this.localStream,
      isBroadcasting: isBroadcasting ?? this.isBroadcasting,
      isRecording: isRecording ?? this.isRecording,
      isFlashlightOn: isFlashlightOn ?? this.isFlashlightOn,
      connectedReceiver: connectedReceiver ?? this.connectedReceiver,
    );
  }
}

class BroadcasterError extends BroadcasterState {
  final String message;

  const BroadcasterError(this.message);

  @override
  List<Object> get props => [message];
}
