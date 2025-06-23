// ReceiverCubit handles WebRTC receiver state and exposes commands for the UI
import 'package:bloc/bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/utils/receiver_manager.dart';

import '../../theme/app_constant.dart';
import 'receiver_state.dart';

class ReceiverCubit extends Cubit<ReceiverState> {
  ReceiverCubit() : super(const ReceiverInitial());

  late final ReceiverManager _manager;
  bool _isInitialized = false;
  String _currentQuality = 'medium'; // ИСПРАВЛЕНИЕ: Отслеживаем текущее качество
  bool _isFlashOn = false; // ИСПРАВЛЕНИЕ: Отслеживаем состояние фонарика

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    emit(const ReceiverInitial());

    _manager = ReceiverManager()
      ..onStateChange = _handleStateChange
      ..onStreamChanged = _handleStreamChanged
      ..onError = _handleError
      ..onBroadcastersChanged = _handleBroadcastersChanged;

    try {
      await _manager.init();
      _emitReady();
    } catch (e) {
      emit(ReceiverError(e.toString()));
    }
  }

  List<String> get messages => _manager.messages;
  String get currentQuality => _currentQuality; // ИСПРАВЛЕНИЕ: Геттер для качества
  bool get isFlashOn => _isFlashOn; // ИСПРАВЛЕНИЕ: Геттер для фонарика

  // ИСПРАВЛЕНИЕ: Улучшенная отправка команд с обработкой ошибок
  Future<void> sendCommand(String command) async {
    try {
      await _manager.sendCommand(command);

      // ИСПРАВЛЕНИЕ: Обновляем локальное состояние для некоторых команд
      switch (command) {
        case AppConstants.toggleFlashCommand:
          _isFlashOn = !_isFlashOn;
          break;
      }

      _emitReady();
    } catch (e) {
      emit(ReceiverError('Ошибка отправки команды: $e'));
    }
  }

  // ИСПРАВЛЕНИЕ: Отправка команды с использованием enum
  Future<void> sendBroadcasterCommand(BroadcasterCommand command) async {
    try {
      await sendCommand(command.value);
    } catch (e) {
      emit(ReceiverError('Ошибка выполнения команды "${command.displayName}": $e'));
    }
  }

  // ИСПРАВЛЕНИЕ: Улучшенная смена качества
  Future<void> changeStreamQuality(ReceiverStreamQuality quality) async {
    try {
      await _manager.changeStreamQuality(quality);

      // Обновляем локальное состояние качества
      switch (quality) {
        case ReceiverStreamQuality.low:
          _currentQuality = 'low';
          break;
        case ReceiverStreamQuality.medium:
          _currentQuality = 'medium';
          break;
        case ReceiverStreamQuality.high:
          _currentQuality = 'high';
          break;
      }

      _emitReady();
    } catch (e) {
      emit(ReceiverError('Ошибка изменения качества: $e'));
    }
  }

  // ИСПРАВЛЕНИЕ: Смена качества с использованием VideoQuality enum
  Future<void> changeVideoQuality(VideoQuality quality) async {
    try {
      await _manager.changeStreamQuality(quality.value);
      _currentQuality = quality.value;
      _emitReady();
    } catch (e) {
      emit(ReceiverError('Ошибка изменения качества видео: $e'));
    }
  }

  // ИСПРАВЛЕНИЕ: Быстрые команды для UI
  Future<void> capturePhoto() async {
    await sendBroadcasterCommand(BroadcasterCommand.capturePhoto);
  }

  Future<void> toggleFlash() async {
    await sendBroadcasterCommand(BroadcasterCommand.toggleFlash);
  }

  Future<void> startTimer() async {
    await sendBroadcasterCommand(BroadcasterCommand.startTimer);
  }

  Future<void> toggleRecording() async {
    await sendBroadcasterCommand(BroadcasterCommand.toggleRecording);
  }

  Future<void> startRecording() async {
    await sendBroadcasterCommand(BroadcasterCommand.startRecording);
  }

  Future<void> stopRecording() async {
    await sendBroadcasterCommand(BroadcasterCommand.stopRecording);
  }

  // ИСПРАВЛЕНИЕ: Смена качества через предустановки
  Future<void> setLowQuality() async {
    await changeVideoQuality(VideoQuality.low);
  }

  Future<void> setMediumQuality() async {
    await changeVideoQuality(VideoQuality.medium);
  }

  Future<void> setHighQuality() async {
    await changeVideoQuality(VideoQuality.high);
  }

  Future<void> setPowerSaveMode() async {
    await changeVideoQuality(VideoQuality.powerSave);
  }

  void switchToBroadcaster(String broadcasterUrl) {
    _manager.switchToPrimaryBroadcaster(broadcasterUrl);
  }

  // ИСПРАВЛЕНИЕ: Получение информации о текущем качестве
  VideoQualityConfig? getCurrentQualityConfig() {
    return AppConstants.videoQualities[_currentQuality];
  }

  // ИСПРАВЛЕНИЕ: Получение всех доступных качеств
  List<VideoQuality> getAvailableQualities() {
    return VideoQuality.values;
  }

  // ИСПРАВЛЕНИЕ: Проверка доступности команд
  bool canSendCommands() {
    return _manager.isConnected && _manager.connectedBroadcasters.isNotEmpty;
  }

  // ИСПРАВЛЕНИЕ: Получение статистики соединения
  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': _manager.isConnected,
      'connectionCount': _manager.connectionCount,
      'connectedBroadcasters': _manager.connectedBroadcasters,
      'primaryBroadcaster': _manager.connectedBroadcaster,
      'currentQuality': _currentQuality,
      'qualityConfig': getCurrentQualityConfig()?.fullDescription ?? 'Unknown',
      'isFlashOn': _isFlashOn,
    };
  }

  void _handleStateChange() => _emitReady();

  void _handleStreamChanged(MediaStream? stream) {
    if (stream != null) {
      // ИСПРАВЛЕНИЕ: Логируем получение потока
      print('ReceiverCubit: Stream received with ${stream.getTracks().length} tracks');
    }
    _emitReady();
  }

  void _handleBroadcastersChanged(List<String> broadcasters) {
    print('ReceiverCubit: Broadcasters changed: $broadcasters');
    _emitReady();
  }

  void _handleError(String error) {
    print('ReceiverCubit: Error occurred: $error');
    emit(ReceiverError(error));
  }

  void _emitReady() {
    if (isClosed) return;

    emit(
      ReceiverReady(
        isConnected: _manager.isConnected,
        remoteStream: _manager.remoteStream,
        connectedBroadcasters: _manager.connectedBroadcasters,
        isFlashOn: _isFlashOn,
        currentQuality: _currentQuality, // ИСПРАВЛЕНИЕ: Передаем качество в состояние
      ),
    );
  }

  @override
  Future<void> close() async {
    if (_isInitialized) {
      await _manager.dispose();
    }
    return super.close();
  }
}