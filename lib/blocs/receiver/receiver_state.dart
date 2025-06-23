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
    this.currentQuality = 'medium', // ИСПРАВЛЕНИЕ: Добавляем текущее качество
    this.error,
  });

  final bool isInitializing;
  final bool isConnected;
  final MediaStream? remoteStream;
  final List<String> connectedBroadcasters;
  final bool isFlashOn;
  final String currentQuality; // ИСПРАВЛЕНИЕ: Новое поле для отслеживания качества
  final String? error;

  @override
  List<Object?> get props => [
    isInitializing,
    isConnected,
    remoteStream,
    connectedBroadcasters,
    isFlashOn,
    currentQuality, // ИСПРАВЛЕНИЕ: Добавляем в props
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
    super.currentQuality = 'medium', // ИСПРАВЛЕНИЕ: Добавляем параметр качества
  }) : super(
    isInitializing: false,
  );

  // ИСПРАВЛЕНИЕ: Добавляем удобные геттеры
  bool get hasStream => remoteStream != null;
  bool get hasMultipleBroadcasters => connectedBroadcasters.length > 1;
  int get broadcasterCount => connectedBroadcasters.length;

  // ИСПРАВЛЕНИЕ: Геттер для получения информации о качестве
  String get qualityDisplayName {
    switch (currentQuality) {
      case 'low':
        return 'Низкое (640x360)';
      case 'medium':
        return 'Среднее (1280x720)';
      case 'high':
        return 'Высокое (1920x1080)';
      case 'power_save':
        return 'Энергосбережение (854x480)';
      default:
        return 'Неизвестно';
    }
  }

  // ИСПРАВЛЕНИЕ: Копирование состояния с изменениями
  ReceiverReady copyWith({
    bool? isConnected,
    MediaStream? remoteStream,
    List<String>? connectedBroadcasters,
    bool? isFlashOn,
    String? currentQuality,
  }) {
    return ReceiverReady(
      isConnected: isConnected ?? this.isConnected,
      remoteStream: remoteStream ?? this.remoteStream,
      connectedBroadcasters: connectedBroadcasters ?? this.connectedBroadcasters,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      currentQuality: currentQuality ?? this.currentQuality,
    );
  }
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

  // ИСПРАВЛЕНИЕ: Удобные геттеры для типов ошибок
  bool get isConnectionError => error?.contains('connection') == true ||
      error?.contains('подключен') == true;

  bool get isCommandError => error?.contains('команд') == true ||
      error?.contains('command') == true;

  bool get isQualityError => error?.contains('качеств') == true ||
      error?.contains('quality') == true;

  // ИСПРАВЛЕНИЕ: Получение типа ошибки для UI
  String get errorType {
    if (isConnectionError) return 'connection';
    if (isCommandError) return 'command';
    if (isQualityError) return 'quality';
    return 'general';
  }

  // ИСПРАВЛЕНИЕ: Локализованное сообщение об ошибке
  String get localizedError {
    if (error == null) return 'Неизвестная ошибка';

    if (error!.contains('No active connection')) {
      return 'Нет активного соединения';
    }
    if (error!.contains('Data channel')) {
      return 'Ошибка канала данных';
    }
    if (error!.contains('timeout')) {
      return 'Превышено время ожидания';
    }
    if (error!.contains('Failed to send')) {
      return 'Не удалось отправить команду';
    }

    return error!;
  }
}