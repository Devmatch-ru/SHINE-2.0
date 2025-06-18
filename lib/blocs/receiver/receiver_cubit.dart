import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/receiver_manager.dart';
import 'receiver_state.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'dart:async';

enum CommandType { photo, video, flashlight, timer }

class ReceiverCubit extends Cubit<ReceiverState> {
  final ReceiverManager _manager;
  final RTCVideoRenderer _remoteRenderer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;
  bool _isFlashOn = false;

  ReceiverCubit()
      : _remoteRenderer = RTCVideoRenderer(),
        _manager = ReceiverManager(),
        super(const ReceiverInitial());

  Future<void> initialize() async {
    try {
      await _remoteRenderer.initialize();

      _manager
        ..onStateChange = _handleStateChange
        ..onStreamChanged = _handleStreamChanged
        ..onError = _handleError
        ..onMediaReceived = _handleMediaReceived;

      await _manager.init();
      emit(const ReceiverReady());
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleStateChange() {
    _reconnectTimer?.cancel();

    if (_manager.isConnected && _manager.remoteStream != null) {
      _reconnectAttempts = 0;

      final currentState = state;
      if (currentState is ReceiverConnected) {
        if (currentState.remoteStream != _manager.remoteStream ||
            currentState.connectedBroadcaster !=
                _manager.connectedBroadcaster) {
          emit(ReceiverConnected(
            remoteStream: _manager.remoteStream!,
            connectedBroadcaster: _manager.connectedBroadcaster!,
            streamQuality: currentState.streamQuality,
          ));
        }
      } else {
        emit(ReceiverConnected(
          remoteStream: _manager.remoteStream!,
          connectedBroadcaster: _manager.connectedBroadcaster!,
          streamQuality: state.streamQuality,
        ));
      }
    } else {
      if (_manager.isConnected) {
        if (!(state is ReceiverConnected)) {
          emit(ReceiverConnected(
            remoteStream: null,
            connectedBroadcaster: _manager.connectedBroadcaster!,
            streamQuality: state.streamQuality,
          ));
        }
      } else {
        if (!(state is ReceiverDisconnected)) {
          emit(ReceiverDisconnected(streamQuality: state.streamQuality));
        }
        _startReconnection();
      }
    }
  }

  void _handleStreamChanged(MediaStream? stream) {
    _remoteRenderer.srcObject = stream;

    if (stream != null && _manager.connectedBroadcaster != null) {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      final currentState = state;
      if (currentState is ReceiverConnected) {
        if (currentState.remoteStream != stream ||
            currentState.connectedBroadcaster !=
                _manager.connectedBroadcaster) {
          emit(ReceiverConnected(
            remoteStream: stream,
            connectedBroadcaster: _manager.connectedBroadcaster!,
            streamQuality: currentState.streamQuality,
          ));
        }
      } else {
        emit(ReceiverConnected(
          remoteStream: stream,
          connectedBroadcaster: _manager.connectedBroadcaster!,
          streamQuality: state.streamQuality,
        ));
      }
    } else {
      if (!(state is ReceiverDisconnected)) {
        emit(ReceiverDisconnected(streamQuality: state.streamQuality));
      }
      _startReconnection();
    }
  }

  void _handleError(String error) {
    print('Receiver error: $error');

    if (!error.contains('Max reconnection attempts reached')) {
      if (!(state is ReceiverError)) {
        _startReconnection();
      }
    }

    if (state is! ReceiverError || (state as ReceiverError).error != error) {
      emit(ReceiverError(error));
    }
  }

  void _startReconnection() {
    if (_reconnectAttempts >= maxReconnectAttempts) {
      emit(ReceiverError('Max reconnection attempts reached'));
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts * 2);

    print(
        'Starting reconnection attempt $_reconnectAttempts after ${delay.inSeconds} seconds');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      if (state is! ReceiverConnected) {
        emit(ReceiverDisconnected(streamQuality: state.streamQuality));

        if (_manager.connectedBroadcaster != null) {
          _manager.switchToPrimaryBroadcaster(_manager.connectedBroadcaster!);
        }
      }
    });
  }

  void _handleMediaReceived(String mediaType, String filePath) {
    try {
      if (mediaType.toLowerCase() == 'photo') {
        GallerySaver.saveImage(filePath, albumName: 'Shine')
            .then((_) => print('Photo saved to gallery: $filePath'))
            .catchError((e) => print('Error saving photo: $e'));
      } else if (mediaType.toLowerCase() == 'video') {
        GallerySaver.saveVideo(filePath, albumName: 'Shine')
            .then((_) => print('Video saved to gallery: $filePath'))
            .catchError((e) => print('Error saving video: $e'));
      }
    } catch (e) {
      print('Error handling media: $e');
    }
  }

  Future<void> changeStreamQuality(StreamQuality quality) async {
    try {
      await _manager.changeStreamQuality(quality);

      if (state is ReceiverConnected) {
        final currentState = state as ReceiverConnected;
        emit(ReceiverConnected(
          remoteStream: currentState.remoteStream,
          connectedBroadcaster: currentState.connectedBroadcaster!,
          streamQuality: quality,
        ));
      } else if (state is ReceiverReady) {
        emit(ReceiverReady(streamQuality: quality));
      } else if (state is ReceiverDisconnected) {
        emit(ReceiverDisconnected(streamQuality: quality));
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> sendCommand(CommandType command) async {
    if (!_manager.isConnected) {
      _handleError('Нет подключения к транслирующему');
      return;
    }

    try {
      String commandString;
      switch (command) {
        case CommandType.photo:
          commandString = 'capture_photo';
          break;
        case CommandType.video:
          commandString = 'toggle_video';
          break;
        case CommandType.flashlight:
          _isFlashOn = !_isFlashOn;
          commandString = 'toggle_flashlight';
          break;
        case CommandType.timer:
          commandString = 'start_timer';
          break;
      }

      await _manager.sendCommandToAll(commandString);

      if (state is ReceiverConnected) {
        final currentState = state as ReceiverConnected;
        emit(ReceiverConnected(
          remoteStream: currentState.remoteStream,
          connectedBroadcaster: currentState.connectedBroadcaster!,
          streamQuality: currentState.streamQuality,
          lastCommand: commandString,
        ));
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void switchBroadcaster(String broadcasterUrl) {
    try {
      _manager.switchToPrimaryBroadcaster(broadcasterUrl);
      _reconnectAttempts = 0;
    } catch (e) {
      _handleError(e.toString());
    }
  }

  List<String> get connectedBroadcasters => _manager.connectedBroadcasters;
  List<String> get debugMessages => _manager.messages;
  RTCVideoRenderer get remoteRenderer => _remoteRenderer;
  bool get isFlashOn => _isFlashOn;

  @override
  Future<void> close() async {
    _reconnectTimer?.cancel();
    await _remoteRenderer.dispose();
    await _manager.dispose();
    super.close();
  }
}
