import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/utils/webrtc/discovery_manager.dart';
import '../../utils/broadcaster_manager.dart';
import 'broadcaster_state.dart';

class BroadcasterCubit extends Cubit<BroadcasterState> {
  String? _receiverUrl;
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  late final BroadcasterManager _manager;
  late final DiscoveryManager _discoveryManager;
  Timer? _captureTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int maxReconnectAttempts = 5;

  BroadcasterCubit({String? receiverUrl})
      : _receiverUrl = receiverUrl,
        super(const BroadcasterInitial()) {
    _discoveryManager = DiscoveryManager(
      onLog: (message) => print('Discovery: $message'),
      onStateChange: () => print('Discovery state changed'),
    );
  }

  RTCVideoRenderer get localRenderer {
    if (state is BroadcasterInitial) {
      throw Exception('Renderer not initialized yet');
    }
    return _localRenderer;
  }

  bool get isFlashOn => _manager.isFlashOn;
  List<String> get debugMessages => _manager.messages;

  String get currentQuality => _manager.currentQuality;

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

      if (_manager.localStream != null) {
        _localRenderer.srcObject = _manager.localStream;
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: const [],
        ));
      }

      await _discoveryManager.startDiscoveryListener();
      final receivers = await _discoveryManager.discoverReceivers();
      if (receivers.isNotEmpty) {
        _receiverUrl = receivers.first.replaceFirst('RECEIVER:', 'http://');
      } else {
        _handleError('Не удалось обнаружить ресивер');
        return;
      }

      if (_receiverUrl == null || _receiverUrl!.startsWith('http://169.254.')) {
        _handleError('Неверный адрес ресивера: $_receiverUrl');
        return;
      }

      await startBroadcasting();
    } catch (e) {
      _handleError(e.toString());
    }
  }

  Future<void> startBroadcasting() async {
    if (_receiverUrl == null || _receiverUrl!.startsWith('http://169.254.')) {
      _handleError('Неверный адрес ресивера: $_receiverUrl');
      return;
    }

    try {
      await _manager.startBroadcast(_receiverUrl!);

      if (_manager.isBroadcasting && _manager.localStream != null) {
        _reconnectAttempts = 0;
        _reconnectTimer?.cancel();

        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
        ));
      }
    } catch (e) {
      _handleError('Ошибка при запуске трансляции: $e');
    }
  }

  void _handleConnectionFailed() {
    if (isClosed) return;
    if (state is BroadcasterError) return;

    _addMessage('Connection failed, attempting to reconnect...');

    if (_reconnectAttempts < maxReconnectAttempts) {
      _reconnectAttempts++;
      final delay = Duration(seconds: _reconnectAttempts * 2);

      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(delay, () async {
        _addMessage('Attempting reconnection (attempt $_reconnectAttempts of $maxReconnectAttempts)');
        final receivers = await _discoveryManager.discoverReceivers();
        if (receivers.isNotEmpty) {
          _receiverUrl = receivers.first.replaceFirst('RECEIVER:', 'http://');
        }
        await startBroadcasting();
      });
    } else {
      _addMessage('Max reconnection attempts reached');
      emit(BroadcasterError('Не удалось восстановить подключение после $maxReconnectAttempts попыток'));
    }
  }

  void _handleError(String error) {
    if (isClosed) return;
    _addMessage('Error occurred: $error');

    if (!error.contains('Не удалось восстановить подключение')) {
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
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();

      if (state is BroadcasterTimer) {
        final currentState = state as BroadcasterTimer;
        emit(BroadcasterTimer(
          stream: currentStream,
          seconds: currentState.timerSeconds,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      } else if (state.isRecording || _manager.isRecording) {
        emit(BroadcasterRecording(
          stream: currentStream,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      } else {
        emit(BroadcasterReady(
          stream: currentStream,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      }
    } else {
      emit(BroadcasterReady(
        stream: currentStream,
        connectedReceivers: const [],
        isPowerSaveMode: _manager.isPowerSaveMode,
        isVideoMode: state.isVideoMode,
        currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
        currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
      ));
    }
  }

  void _handleCommandReceived(String command) {
    if (_manager.localStream == null) return;

    String message;
    switch (command) {
      case 'photo':
        // message = 'Получена команда: Сделать фото';
        _executePhotoCommand();
        break;
      case 'toggle_video':
        // message = 'Получена команда: Переключить видеозапись';
        _executeVideoCommand();
        break;
      case 'flashlight':
        // message = 'Получена команда: Переключить фонарик';
        _executeFlashlightCommand();
        break;
      case 'timer':
        // message = 'Получена команда: Запустить таймер';
        _executeTimerCommand();
        break;
      default:
        message = 'Получена команда: $command';
    }

    emit(BroadcasterCommandReceived(
      stream: _manager.localStream!,
      message: "message",
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
      isVideoMode: state.isVideoMode,
      currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
    ));

    Future.delayed(const Duration(seconds: 3), () {
      if (_manager.localStream != null) {
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          isVideoMode: state.isVideoMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      }

      await _manager.capturePhoto();

      if (_manager.localStream != null) {
        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '✅ Фото сохранено!',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));

        Future.delayed(const Duration(seconds: 3), () {
          if (_manager.localStream != null) {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
              currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
        await _manager.stopVideoRecording();
        if (_manager.localStream != null) {
          emit(BroadcasterReady(
            stream: _manager.localStream!,
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
            currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
          ));
        }

        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '📹 Видео сохранено',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      } else {
        _addMessage('Начинаем запись видео...');
        await _manager.startVideoRecording();

        if (_manager.localStream != null) {
          emit(BroadcasterRecording(
            stream: _manager.localStream!,
            connectedReceivers: _manager.connectedReceivers,
            isPowerSaveMode: _manager.isPowerSaveMode,
            currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
          ));
        }

        emit(BroadcasterCommandReceived(
          stream: _manager.localStream!,
          message: '🔴 Запись видео начата',
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (_manager.localStream != null) {
          if (_manager.isRecording) {
            emit(BroadcasterRecording(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
              currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
            ));
          } else {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
              currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
            ));
          }
        }
      });
    } catch (e) {
      emit(BroadcasterError('Ошибка при работе с видео: $e'));
    }
  }

  void _addMessage(String message) {
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
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));

        Future.delayed(const Duration(seconds: 2), () {
          if (_manager.localStream != null) {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
              currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));
      } else {
        await _manager.startVideoRecording();
        emit(BroadcasterRecording(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
        currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
      ));
      await Future.delayed(const Duration(seconds: 1));
    }

    await capturePhoto();
    emit(BroadcasterReady(
      stream: _manager.localStream!,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
      currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
      currentQuality: quality, // ИСПРАВЛЕНИЕ 2: Используем новое качество
    ));

    Future.delayed(const Duration(seconds: 2), () {
      if (_manager.localStream != null) {
        emit(BroadcasterReady(
          stream: _manager.localStream!,
          connectedReceivers: _manager.connectedReceivers,
          isPowerSaveMode: _manager.isPowerSaveMode,
          currentQuality: quality, // ИСПРАВЛЕНИЕ 2: Используем новое качество
        ));
      }
    });
  }

  String _getQualityDisplayName(String quality) {
    switch (quality) {
      case 'low':
        return 'Низкое (640x360, 24fps)';
      case 'medium':
        return 'Среднее (1280x720, 30fps)';
      case 'high':
        return 'Высокое (1920x1080, 30fps)';
      case 'power_save':
        return 'Энергосбережение (средняя)';
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
    await _discoveryManager.dispose();
    super.close();
  }

  Future<void> disconnect() async {
    try {
      _captureTimer?.cancel();
      _reconnectTimer?.cancel();

      await _manager.stopBroadcast();
      _localRenderer.srcObject = null;
      await _manager.dispose();
      await _discoveryManager.dispose();

      await Future.delayed(const Duration(milliseconds: 300));
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
      currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
    ));
  }

  Future<void> setVideoMode() async {
    if (_manager.localStream == null) return;

    emit(BroadcasterReady(
      stream: _manager.localStream!,
      connectedReceivers: _manager.connectedReceivers,
      isPowerSaveMode: _manager.isPowerSaveMode,
      isVideoMode: true,
      currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
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
          currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
        ));

        Future.delayed(const Duration(seconds: 2), () {
          if (_manager.localStream != null) {
            emit(BroadcasterReady(
              stream: _manager.localStream!,
              connectedReceivers: _manager.connectedReceivers,
              isPowerSaveMode: _manager.isPowerSaveMode,
              currentQuality: _manager.currentQuality, // ИСПРАВЛЕНИЕ 2: Передаем качество
            ));
          }
        });
      }
    } catch (e) {
      emit(BroadcasterError('Ошибка при переключении фонарика: $e'));
    }
  }
}