import 'package:equatable/equatable.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// lib/blocs/broadcaster/broadcaster_state.dart
import 'package:equatable/equatable.dart';

abstract class BroadcasterState extends Equatable {
  const BroadcasterState();

  @override
  List<Object?> get props => [];
}

class BroadcasterInitial extends BroadcasterState {}

class BroadcasterInitializing extends BroadcasterState {}

class BroadcasterReady extends BroadcasterState {
  final bool isConnected;
  final bool isRecording;
  final bool isFlashOn;
  final bool isPowerSaveMode;
  final String? connectionStatus;
  final MediaStream? localStream;
  final String? broadcasterId;
  final String? receiverUrl;
  final double connectionStrength; // 0.0 to 1.0
  final DateTime? lastHeartbeat;

  // Quality and streaming
  final String currentQuality;
  final bool isQualityChanging;
  final Map<String, dynamic> streamStats; // Various streaming statistics

  // Media capture state
  final bool isCapturingPhoto;
  final bool isCapturingWithTimer;
  final int timerSeconds; // For countdown timer
  final List<String> recentMediaPaths; // Last captured media

  // Network and performance
  final double networkLatency; // in milliseconds
  final double cpuUsage; // 0.0 to 1.0
  final double thermalState; // 0.0 to 1.0 (cool to hot)
  final int fps; // Current actual FPS
  final int bitrate; // Current bitrate

  // Error and health
  final String? lastError;
  final DateTime? lastErrorTime;
  final bool hasRecentError;
  final List<String> warnings; // Non-critical warnings

  // Multiple receiver support
  final List<String> connectedReceivers;
  final String? primaryReceiver;
  final bool isMulticastMode;

  const BroadcasterReady({
    required this.isConnected,
    required this.isRecording,
    required this.isFlashOn,
    this.isPowerSaveMode = false,
    this.connectionStatus,
    this.localStream,
    this.broadcasterId,
    this.receiverUrl,
    this.connectionStrength = 0.0,
    this.lastHeartbeat,
    this.currentQuality = 'medium',
    this.isQualityChanging = false,
    this.streamStats = const {},
    this.isCapturingPhoto = false,
    this.isCapturingWithTimer = false,
    this.timerSeconds = 0,
    this.recentMediaPaths = const [],
    this.networkLatency = 0.0,
    this.cpuUsage = 0.0,
    this.thermalState = 0.0,
    this.fps = 30,
    this.bitrate = 1200000,
    this.lastError,
    this.lastErrorTime,
    this.hasRecentError = false,
    this.warnings = const [],
    this.connectedReceivers = const [],
    this.primaryReceiver,
    this.isMulticastMode = false,
  });

  @override
  List<Object?> get props => [
        isConnected,
        isRecording,
        isFlashOn,
        isPowerSaveMode,
        connectionStatus,
        localStream?.id,
        broadcasterId,
        receiverUrl,
        connectionStrength,
        lastHeartbeat,
        currentQuality,
        isQualityChanging,
        streamStats,
        isCapturingPhoto,
        isCapturingWithTimer,
        timerSeconds,
        recentMediaPaths,
        networkLatency,
        cpuUsage,
        thermalState,
        fps,
        bitrate,
        lastError,
        lastErrorTime,
        hasRecentError,
        warnings,
        connectedReceivers,
        primaryReceiver,
        isMulticastMode,
      ];

  // Computed properties
  bool get hasStrongConnection => connectionStrength > 0.7;
  bool get hasWeakConnection =>
      connectionStrength < 0.3 && connectionStrength > 0.0;
  bool get isOverheating => thermalState > 0.8;
  bool get isHighCpuUsage => cpuUsage > 0.8;
  bool get hasMultipleReceivers => connectedReceivers.length > 1;
  bool get hasLowLatency => networkLatency < 100.0;
  bool get hasHighLatency => networkLatency > 500.0;
  bool get isStreamHealthy => hasStrongConnection && !isOverheating && fps > 20;

  String get connectionStatusText {
    if (!isConnected) {
      return 'Не подключено';
    } else if (hasStrongConnection) {
      return 'Отличное соединение';
    } else if (hasWeakConnection) {
      return 'Слабое соединение';
    } else {
      return 'Хорошее соединение';
    }
  }

  String get qualityDisplayName {
    switch (currentQuality) {
      case 'low':
        return 'Низкое';
      case 'medium':
        return 'Среднее';
      case 'high':
        return 'Высокое';
      case 'power_save':
        return 'Экономия энергии';
      default:
        return 'Неизвестно';
    }
  }

  String get detailedStatusText {
    final buffer = StringBuffer();

    if (isConnected) {
      buffer.writeln('✅ Подключено к ${connectedReceivers.length} приемникам');
      buffer.writeln('📡 Соединение: $connectionStatusText');
      buffer.writeln('🎥 Качество: $qualityDisplayName ($fps FPS)');
      buffer.writeln(
          '📊 Битрейт: ${(bitrate / 1000000).toStringAsFixed(1)} Мбит/с');

      if (networkLatency > 0) {
        buffer.writeln('⏱️ Задержка: ${networkLatency.toStringAsFixed(0)} мс');
      }

      if (isOverheating) {
        buffer.writeln(
            '🌡️ Перегрев: ${(thermalState * 100).toStringAsFixed(0)}%');
      }

      if (isHighCpuUsage) {
        buffer.writeln('💻 CPU: ${(cpuUsage * 100).toStringAsFixed(0)}%');
      }
    } else {
      buffer.writeln('❌ Не подключено');
      if (connectionStatus != null) {
        buffer.writeln('📝 Статус: $connectionStatus');
      }
    }

    if (isRecording) {
      buffer.writeln('🔴 Запись видео активна');
    }

    if (isFlashOn) {
      buffer.writeln('🔦 Фонарик включен');
    }

    if (isPowerSaveMode) {
      buffer.writeln('🔋 Режим энергосбережения');
    }

    if (warnings.isNotEmpty) {
      buffer.writeln('⚠️ Предупреждения:');
      for (final warning in warnings) {
        buffer.writeln('  • $warning');
      }
    }

    if (hasRecentError && lastError != null) {
      buffer.writeln('❌ Ошибка: $lastError');
    }

    return buffer.toString().trim();
  }

  List<String> get performanceWarnings {
    final warns = <String>[];

    if (isOverheating) {
      warns.add('Устройство перегревается');
    }

    if (isHighCpuUsage) {
      warns.add('Высокая нагрузка на процессор');
    }

    if (hasHighLatency) {
      warns.add('Высокая задержка сети');
    }

    if (fps < 15) {
      warns.add('Низкая частота кадров');
    }

    if (hasWeakConnection) {
      warns.add('Слабое соединение');
    }

    return warns;
  }

  BroadcasterReady copyWith({
    bool? isConnected,
    bool? isRecording,
    bool? isFlashOn,
    bool? isPowerSaveMode,
    String? connectionStatus,
    MediaStream? localStream,
    String? broadcasterId,
    String? receiverUrl,
    double? connectionStrength,
    DateTime? lastHeartbeat,
    String? currentQuality,
    bool? isQualityChanging,
    Map<String, dynamic>? streamStats,
    bool? isCapturingPhoto,
    bool? isCapturingWithTimer,
    int? timerSeconds,
    List<String>? recentMediaPaths,
    double? networkLatency,
    double? cpuUsage,
    double? thermalState,
    int? fps,
    int? bitrate,
    String? lastError,
    DateTime? lastErrorTime,
    bool? hasRecentError,
    List<String>? warnings,
    List<String>? connectedReceivers,
    String? primaryReceiver,
    bool? isMulticastMode,
  }) {
    return BroadcasterReady(
      isConnected: isConnected ?? this.isConnected,
      isRecording: isRecording ?? this.isRecording,
      isFlashOn: isFlashOn ?? this.isFlashOn,
      isPowerSaveMode: isPowerSaveMode ?? this.isPowerSaveMode,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      localStream: localStream ?? this.localStream,
      broadcasterId: broadcasterId ?? this.broadcasterId,
      receiverUrl: receiverUrl ?? this.receiverUrl,
      connectionStrength: connectionStrength ?? this.connectionStrength,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      currentQuality: currentQuality ?? this.currentQuality,
      isQualityChanging: isQualityChanging ?? this.isQualityChanging,
      streamStats: streamStats ?? this.streamStats,
      isCapturingPhoto: isCapturingPhoto ?? this.isCapturingPhoto,
      isCapturingWithTimer: isCapturingWithTimer ?? this.isCapturingWithTimer,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      recentMediaPaths: recentMediaPaths ?? this.recentMediaPaths,
      networkLatency: networkLatency ?? this.networkLatency,
      cpuUsage: cpuUsage ?? this.cpuUsage,
      thermalState: thermalState ?? this.thermalState,
      fps: fps ?? this.fps,
      bitrate: bitrate ?? this.bitrate,
      lastError: lastError,
      lastErrorTime: lastErrorTime,
      hasRecentError: hasRecentError ?? this.hasRecentError,
      warnings: warnings ?? this.warnings,
      connectedReceivers: connectedReceivers ?? this.connectedReceivers,
      primaryReceiver: primaryReceiver ?? this.primaryReceiver,
      isMulticastMode: isMulticastMode ?? this.isMulticastMode,
    );
  }
}

class BroadcasterError extends BroadcasterState {
  final String error;
  final String? errorCode;
  final DateTime timestamp;
  final bool isCritical;
  final bool canRetry;
  final Map<String, dynamic> errorContext;

  const BroadcasterError(
    this.error, {
    this.errorCode,
    DateTime? timestamp,
    this.isCritical = false,
    this.canRetry = true,
    this.errorContext = const {},
      }) : timestamp = timestamp ?? DateTime.now();

  @override
  List<Object?> get props => [
        error,
        errorCode,
        timestamp,
        isCritical,
        canRetry,
        errorContext,
      ];

  String get userFriendlyError {
    if (error.contains('Permission')) {
      return 'Нет разрешения на использование камеры';
    } else if (error.contains('Network') || error.contains('Connection')) {
      return 'Проблема с сетевым соединением';
    } else if (error.contains('Camera') || error.contains('Media')) {
      return 'Проблема с камерой или медиа';
    } else if (error.contains('WebRTC')) {
      return 'Ошибка видеосвязи';
    } else {
      return error;
    }
  }

  String get suggestedAction {
    if (error.contains('Permission')) {
      return 'Предоставьте разрешения в настройках';
    } else if (error.contains('Network')) {
      return 'Проверьте подключение к Wi-Fi';
    } else if (error.contains('Camera')) {
      return 'Перезапустите приложение';
    } else if (canRetry) {
      return 'Попробуйте еще раз';
    } else {
      return 'Обратитесь в поддержку';
    }
  }
}

class BroadcasterConnecting extends BroadcasterState {
  final String receiverUrl;
  final String? broadcasterId;
  final int attempt;
  final int maxAttempts;

  const BroadcasterConnecting(
    this.receiverUrl, {
    this.broadcasterId,
    this.attempt = 1,
    this.maxAttempts = 3,
  });

  @override
  List<Object?> get props => [receiverUrl, broadcasterId, attempt, maxAttempts];

  double get progress => attempt / maxAttempts;

  String get statusText => 'Подключение... ($attempt/$maxAttempts)';
}

class BroadcasterConnected extends BroadcasterState {
  final String receiverUrl;
  final String? broadcasterId;
  final MediaStream? localStream;
  final DateTime connectedAt;
  final bool isPrimary;

  const BroadcasterConnected(
    this.receiverUrl, {
    this.broadcasterId,
    this.localStream,
    DateTime? connectedAt,
    this.isPrimary = true,
  }) : connectedAt = connectedAt ?? const Duration().inMilliseconds > 0
            ? DateTime.now()
            : DateTime.now();

  @override
  List<Object?> get props => [
        receiverUrl,
        broadcasterId,
        localStream?.id,
        connectedAt,
        isPrimary,
      ];

  Duration get connectionDuration => DateTime.now().difference(connectedAt);

  String get statusText =>
      isPrimary ? 'Основное подключение' : 'Дополнительное подключение';
}
