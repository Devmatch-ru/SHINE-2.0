import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:camera/camera.dart';
import '../../utils/broadcaster_manager.dart';
import './broadcaster_state.dart';

class BroadcasterCubit extends Cubit<BroadcasterState> {
  final BroadcasterManager _broadcasterManager;

  BroadcasterCubit({required BroadcasterManager broadcasterManager})
      : _broadcasterManager = broadcasterManager,
        super(BroadcasterInitial());

  Future<void> initialize() async {
    try {
      emit(BroadcasterLoading());

      await _broadcasterManager.init();
      final camera = _broadcasterManager.cameraController;
      final stream = _broadcasterManager.localStream;

      if (camera == null) {
        emit(BroadcasterError('Camera not initialized'));
        return;
      }

      if (stream == null) {
        emit(BroadcasterError('Stream not initialized'));
        return;
      }

      emit(BroadcasterReady(
        camera: camera,
        localStream: stream,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
    }
  }

  Future<void> startBroadcast(String receiverUrl) async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.startBroadcast(receiverUrl);
      emit(currentState.copyWith(
        isBroadcasting: true,
        connectedReceiver: receiverUrl,
        localStream: _broadcasterManager.localStream,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  Future<void> stopBroadcast() async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.stopBroadcast();
      emit(currentState.copyWith(
        isBroadcasting: false,
        connectedReceiver: null,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  Future<void> capturePhoto() async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.capturePhoto();
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  Future<void> toggleVideoRecording() async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.toggleVideoRecording();
      emit(currentState.copyWith(
        isRecording: _broadcasterManager.isRecording,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  Future<void> selectVideoInput(String deviceId) async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.selectVideoInput(deviceId);
      emit(currentState.copyWith(
        camera: _broadcasterManager.cameraController,
        localStream: _broadcasterManager.localStream,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  Future<void> selectVideoFps(String fps) async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.selectVideoFps(fps);
      emit(currentState.copyWith(
        localStream: _broadcasterManager.localStream,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  Future<void> selectVideoSize(String size) async {
    if (state is! BroadcasterReady) return;
    final currentState = state as BroadcasterReady;

    try {
      await _broadcasterManager.selectVideoSize(size);
      emit(currentState.copyWith(
        localStream: _broadcasterManager.localStream,
      ));
    } catch (e) {
      emit(BroadcasterError(e.toString()));
      await Future.delayed(Duration(seconds: 1));
      emit(currentState);
    }
  }

  @override
  Future<void> close() async {
    await _broadcasterManager.dispose();
    return super.close();
  }
}
