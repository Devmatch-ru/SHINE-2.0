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
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

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
      emit(const BroadcasterInitial()); // Make sure we're in initial state
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

      if (_manager.localStream != null) {
        _localRenderer.srcObject = _manager.localStream;
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: const [],
        ));
      }

      await startBroadcasting();
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> startBroadcasting() async {
    try {
      await _manager.startBroadcast(receiverUrl);

      if (_manager.isBroadcasting && _manager.localStream != null) {
        _reconnectAttempts =
            0; // Сбрасываем счетчик попыток при успешном подключении
        _reconnectTimer?.cancel();

        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
        ));
      }
    } catch (e) {
      _handleError(e.toString());
    }
  }

  void _handleConnectionFailed() {
    if (state is BroadcasterError) return;

    _addMessage('Connection failed, attempting to reconnect...');

    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;

      // Экспоненциальная задержка перед повторной попыткой
      final delay = Duration(seconds: _reconnectAttempts * 2);

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        _addMessage(
            'Attempting reconnection (attempt $_reconnectAttempts of $maxReconnectAttempts)');
        await startBroadcasting();
      });
    } else {
      _addMessage('Max reconnection attempts reached');
      emit(BroadcasterError(
          'Не удалось восстановить подключение после $maxReconnectAttempts попыток'));
    }
  }

  void _handleError(String error) {
    _addMessage('Error occurred: $error');

    if (!error.contains('Не удалось восстановить подключение')) {
      // Если это не ошибка после максимального количества попыток переподключения,
      // пробуем переподключиться
      _handleConnectionFailed();
    }

    emit(BroadcasterError(error));
  }

  void _handleStateChange() {
    if (state is BroadcasterError) return;

    final currentStream = _manager.localStream;
    if (currentStream == null) return;

    _localRenderer.srcObject = currentStream;

    if (_manager.isBroadcasting) {
      _reconnectAttempts = 0; // Сбрасываем счетчик при успешном подключении
      _reconnectTimer?.cancel();

      if (state is BroadcasterTimer) {
        final currentState = state as BroadcasterTimer;
        emit(BroadcasterTimer(
          stream: currentStream,
          seconds: currentState.timerSeconds,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
        ));
      } else if (state.isRecording || _manager.isRecording) {
        emit(BroadcasterRecording(
          stream: currentStream,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      } else {
        emit(BroadcasterReady(
          stream: currentStream,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
        ));
      }
    } else {
      emit(BroadcasterReady(
        stream: currentStream,
        connectedReceivers: const [],
        isPowerSaveMode: _manager.isPowerSaveMode,
        isVideoMode: state.isVideoMode,
      ));
    }
  }

  void _handleMediaCaptured(XFile media) {
    // Возвращаемся к предыдущему состоянию после захвата медиа
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

    // Возвращаемся к обычному состоянию через 3 секунды
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
      // Показываем сообщение о начале съёмки
      if (_manager.localStream != null) {
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '📸 Делаем фото...',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      }

      await _manager.capturePhoto();

      // Показываем сообщение об успешной съёмке
      if (_manager.localStream != null) {
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '✅ Фото сохранено!',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));

        // Возвращаемся к обычному состоянию через 3 секунды
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
      // Проверяем текущее состояние записи
      final wasRecording = state.isRecording || _manager.isRecording;

      if (wasRecording) {
        _addMessage('Останавливаем запись видео...');
        await _manager.stopVideoRecording();

        // Обновляем состояние - возвращаемся к Ready
        if (_manager.localStream != null) {
          emit(BroadcasterReady(
            stream: _manager.localStream!,
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
          ));
        }

        // Показываем сообщение о завершении записи
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '📹 Видео сохранено',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      } else {
        _addMessage('Начинаем запись видео...');
        await _manager.startVideoRecording();

        // Обновляем состояние - переходим в Recording
        if (_manager.localStream != null) {
          emit(BroadcasterRecording(
            stream: _manager.localStream!,
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
          ));
        }

        // Показываем сообщение о начале записи
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '🔴 Запись видео начата',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));
      }

      // Возвращаемся к правильному состоянию через 2 секунды
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
    print('BroadcasterCubit: $message');
  }

  Future<void> _executeFlashlightCommand() async {
    try {
      await _manager.toggleFlash();

      // Обновляем UI с информацией о состоянии фонарика
      if (_manager.localStream != null) {
        final status = _manager.isFlashOn ? 'включен' : 'выключен';
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '🔦 Фонарик $status',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
        ));

        // Возвращаемся к обычному состоянию через 2 секунды
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

    // Возвращаемся к обычному состоянию через 2 секунды
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
    _reconnectTimer?.cancel();
    _captureTimer?.cancel();
    await _localRenderer.dispose();
    await _manager.dispose();
    super.close();
  }

  Future<void> disconnect() async {
    try {
      // Останавливаем все таймеры
      _captureTimer?.cancel();
      _reconnectTimer?.cancel();

      // Останавливаем трансляцию
      await _manager.stopBroadcast();

      // Очищаем рендерер
      _localRenderer.srcObject = null;

      // Освобождаем ресурсы
      await _localRenderer.dispose();
      await _manager.dispose();

      // Возвращаемся к начальному состоянию
      emit(const BroadcasterInitial());
    } catch (e) {
      _addMessage('Error during disconnect: $e');
      emit(BroadcasterError('Ошибка при отключении: $e'));
    }
  }

  Future<void> setPhotoMode() async {
    if (_manager.localStream == null) return;

    // Если идет запись, останавливаем её
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

        // Возвращаемся к обычному состоянию через 2 секунды
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
