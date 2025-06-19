import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../utils/broadcaster_manager.dart';
import 'broadcaster_state.dart';

class BroadcasterCubit extends Cubit<BroadcasterState> {
  final String receiverUrl;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  late final BroadcasterManager _manager;
  Timer? _captureTimer;

  BroadcasterCubit({required this.receiverUrl})
      : super(const BroadcasterInitial());

  RTCVideoRenderer get localRenderer {
    if (state is BroadcasterInitial) {
      throw Exception('Renderer not initialized yet');
    }
    return _localRenderer;
  }

  bool get isFlashOn => _manager.isFlashOn;
  List<String> get debugMessages => _manager.messages;

  Future<void> initialize() async {
    try {
      emit(const BroadcasterInitial());
      await _localRenderer.initialize();

      _manager = BroadcasterManager(
        onStateChange: _handleStateChange,
        onError: _handleError,
        onMediaCaptured: _handleMediaCaptured,
        onCommandReceived: _handleCommandReceived,
        onQualityChanged: _handleQualityChanged,
        onConnectionFailed: _handleConnectionFailed,
      );

      await _manager.init();

      if (_manager.localStream == null) {
        throw Exception('Local stream not initialized');
      }

      _localRenderer.srcObject = _manager.localStream;
      emit(BroadcasterReady(
        stream: _manager.localStream!,
        connectedReceivers: const [],
      ));

      await startBroadcasting();
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> startBroadcasting() async {
    try {
      if (_manager.localStream == null) {
        _addMessage('Local stream is null, cannot start broadcast');
        throw Exception('Local stream is not available');
      }

      _addMessage('Starting broadcast to $receiverUrl');
      await _manager.startBroadcast(receiverUrl);

      if (_manager.isBroadcasting) {
        _addMessage('Broadcast started successfully');
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
        ));
      } else {
        _addMessage('Broadcast failed to start');
        throw Exception('Broadcast failed to start');
      }
    } catch (e) {
      _handleError('Ошибка при запуске трансляции: $e');
    }
  }

  void _handleConnectionFailed() {
    _addMessage('Соединение потеряно');
    emit(BroadcasterError('Соединение с приемником потеряно'));
  }

  void _handleError(String error) {
    _addMessage('Ошибка: $error');
    emit(BroadcasterError(error));
  }

  void _handleStateChange() {
    if (state is BroadcasterError) return;

    final currentStream = _manager.localStream;
    if (currentStream == null) return;

    _localRenderer.srcObject = currentStream;

    if (_manager.isBroadcasting) {
      _addMessage('Состояние обновлено: трансляция активна');
      emit(BroadcasterReady(
        stream: currentStream,
        connectedReceivers: _manager.connectedReceivers,
        isPowerSaveMode: _manager.isPowerSaveMode,
        isVideoMode: state.isVideoMode,
      ));
    } else {
      _addMessage('Состояние обновлено: трансляция неактивна');
      emit(BroadcasterReady(
        stream: currentStream,
        connectedReceivers: const [],
        isPowerSaveMode: _manager.isPowerSaveMode,
        isVideoMode: state.isVideoMode,
      ));
    }
  }

  void _handleMediaCaptured(XFile media) {
    if (_manager.localStream != null) {
      emit(BroadcasterReady(
        stream: _manager.localStream!,
        connectedReceivers: _manager.connectedReceivers,
        isPowerSaveMode: _manager.isPowerSaveMode,
        isVideoMode: state.isVideoMode,
      ));
    }
  }

  void _handleCommandReceived(String command) {
    if (_manager.localStream == null) return;

    String message;
    switch (command) {
      case 'capture_photo':
        message = 'Получена команда: Сделать фото';
        _executePhotoCommand();
        break;
      case 'toggle_video':
        message = 'Получена команда: Переключить видеозапись';
        _executeVideoCommand();
        break;
      case 'toggle_flashlight':
        message = 'Получена команда: Переключить фонарик';
        _executeFlashlightCommand();
        break;
      case 'start_timer':
        message = 'Получена команда: Запустить таймер';
        _executeTimerCommand();
        break;
      default:
        message = 'Получена команда: $command';
    }

    emit(BroadcasterCommandReceived(
      stream: _manager.localStream!,
      message: message,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
      isVideoMode: state.isVideoMode,
    ));

    Future.delayed(const Duration(seconds: 3), () {
      if (_manager.localStream != null) {
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
        ));
      }
    });
  }

  Future<void> _executePhotoCommand() async {
    try {
      if (_manager.localStream != null) {
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '📸 Делаем фото...',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      }

      await _manager.capturePhoto();

      if (_manager.localStream != null) {
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '✅ Фото сохранено!',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));

        Future.delayed(const Duration(seconds: 3), () {
          if (_manager.localStream != null) {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
            ));
          }
        });
      }
    } catch (e) {
      emit(BroadcasterError('Ошибка при съемке фото: $e'));
    }
  }

  Future<void> _executeVideoCommand() async {
    try {
      final wasRecording = state.isRecording || _manager.isRecording;

      if (wasRecording) {
        _addMessage('Останавливаем запись видео...');
        await _manager.stopVideoRecording();

        if (_manager.localStream != null) {
          emit(BroadcasterReady(
            stream: _manager.localStream!,
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
          ));
          emit(BroadcasterCommandReceived(
            stream: _manager.localStream!,
            message: '📹 Видео сохранено',
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
          ));
        }
      } else {
        _addMessage('Начинаем запись видео...');
        await _manager.startVideoRecording();

        if (_manager.localStream != null) {
          emit(BroadcasterRecording(
            stream: _manager.localStream!,
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
          ));
          emit(BroadcasterCommandReceived(
            stream: _manager.localStream!,
            message: '🔴 Запись видео начата',
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
          ));
        }
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (_manager.localStream != null) {
          if (_manager.isRecording) {
            emit(BroadcasterRecording(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
            ));
          } else {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
            ));
          }
        }
      });
    } catch (e) {
      emit(BroadcasterError('Ошибка при работе с видео: $e'));
    }
  }

  void _addMessage(String message) {
    print('Broadcaster: $message');
  }

  Future<void> _executeFlashlightCommand() async {
    try {
      await _manager.toggleFlash();

      if (_manager.localStream != null) {
        final status = _manager.isFlashOn ? 'включен' : 'выключен';
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '🔦 Фонарик $status',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));

        Future.delayed(const Duration(seconds: 2), () {
          if (_manager.localStream != null) {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
            ));
          }
        });
      }
    } catch (e) {
      emit(BroadcasterError('Ошибка при переключении фонарика: $e'));
    }
  }

  Future<void> _executeTimerCommand() async {
    try {
      await startTimerCapture();
    } catch (e) {
      emit(BroadcasterError('Ошибка при запуске таймера: $e'));
    }
  }

  Future<void> toggleRecording() async {
    if (!_manager.isBroadcasting) {
      emit(BroadcasterError('Нет подключения к слушателю'));
      return;
    }

    try {
      if (state.isRecording || _manager.isRecording) {
        await _manager.stopVideoRecording();
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      } else {
        await _manager.startVideoRecording();
        emit(BroadcasterRecording(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      }
    } catch (e) {
      emit(BroadcasterError(e.toString()));
    }
  }

  Future<void> capturePhoto() async {
    if (!_manager.isBroadcasting) {
      emit(BroadcasterError('Нет подключения к слушателю'));
      return;
    }

    try {
      await _manager.capturePhoto();
    } catch (e) {
      emit(BroadcasterError(e.toString()));
    }
  }

  Future<void> startTimerCapture() async {
    if (state.isTimerActive || state.isRecording) return;

    const totalSeconds = 3;
    for (int i = totalSeconds; i > 0; i--) {
      emit(BroadcasterTimer(
        stream: _manager.localStream!,
        seconds: i,
        connectedReceivers: _manager.connectedReceivers,
        isPowerSaveMode: _manager.isPowerSaveMode,
      ));
      await Future.delayed(const Duration(seconds: 1));
    }

    await capturePhoto();
    emit(BroadcasterReady(
      stream: _manager.localStream!,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
    ));
  }

  void _handleQualityChanged(String quality) {
    if (_manager.localStream == null) return;

    final message = 'Качество изменено на: ${_getQualityDisplayName(quality)}';

    emit(BroadcasterCommandReceived(
      stream: _manager.localStream!,
      message: message,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
    ));

    Future.delayed(const Duration(seconds: 2), () {
      if (_manager.localStream != null) {
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      }
    });
  }

  String _getQualityDisplayName(String quality) {
    switch (quality) {
      case 'low':
        return 'Низкое (640x360, 15fps)';
      case 'medium':
        return 'Среднее (1280x720, 30fps)';
      case 'high':
        return 'Высокое (1920x1080, 25fps)';
      default:
        return quality;
    }
  }

  @override
  Future<void> close() async {
    _captureTimer?.cancel();
    await _localRenderer.dispose();
    await _manager.dispose();
    super.close();
  }

  Future<void> disconnect() async {
    try {
      _captureTimer?.cancel();

      await _manager.stopBroadcast();

      _localRenderer.srcObject = null;

      await _localRenderer.dispose();
      await _manager.dispose();

      emit(const BroadcasterInitial());
    } catch (e) {
      _addMessage('Error during disconnect: $e');
      emit(BroadcasterError('Ошибка при отключении: $e'));
    }
  }

  Future<void> setPhotoMode() async {
    if (_manager.localStream == null) return;

    if (state.isRecording) {
      await _manager.stopVideoRecording();
    }

    emit(BroadcasterReady(
      stream: _manager.localStream!,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
      isVideoMode: false,
    ));
  }

  Future<void> setVideoMode() async {
    if (_manager.localStream == null) return;

    emit(BroadcasterReady(
      stream: _manager.localStream!,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
      isVideoMode: true,
    ));
  }

  Future<void> toggleFlash() async {
    try {
      await _manager.toggleFlash();

      if (_manager.localStream != null) {
        final status = _manager.isFlashOn ? 'включен' : 'выключен';
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '🔦 Фонарик $status',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
        ));

        Future.delayed(const Duration(seconds: 2), () {
          if (_manager.localStream != null) {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
              isVideoMode: state.isVideoMode,
            ));
          }
        });
      }
    } catch (e) {
      emit(BroadcasterError('Ошибка при переключении фонарика: $e'));
    }
  }
}