// lib/blocs/broadcaster/broadcaster_cubit.dart (Updated)
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:camera/camera.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../utils/broadcaster_manager.dart';
import '../../utils/service/error_handling_service.dart';
import '../../utils/service/logging_service.dart';
import '../../utils/webrtc/types.dart';
import './broadcaster_state.dart';

class BroadcasterCubit extends Cubit<BroadcasterState> with LoggerMixin {
  @override
  String get loggerContext => 'BroadcasterCubit';

  late final BroadcasterManager _manager;
  late final RTCVideoRenderer _localRenderer;

  final String receiverUrl;
  StreamSubscription? _streamSubscription;
  Timer? _stateUpdateTimer;
  Timer? _performanceMonitor;
  Timer? _heartbeatTimer;

  // Performance metrics
  double _currentCpuUsage = 0.0;
  double _currentThermalState = 0.0;
  double _currentNetworkLatency = 0.0;
  int _currentFps = 30;
  int _currentBitrate = 1200000;
  final List<String> _currentWarnings = [];

  BroadcasterCubit({required this.receiverUrl}) : super(BroadcasterInitial()) {
    logInfo('Creating BroadcasterCubit for receiver: $receiverUrl');
    _initializeComponents();
  }

  void _initializeComponents() {
    // Создаем видео рендерер для локального стрима
    _localRenderer = RTCVideoRenderer();
    logInfo('Video renderer created');

    // Создаем менеджер с колбэками
    _manager = BroadcasterManager(
      onStateChange: _handleStateChange,
      onError: _handleError,
      onMediaCaptured: _handleMediaCaptured,
      onConnectionFailed: _handleConnectionFailed,
      onQualityChanged: _handleQualityChanged,
    );
    logInfo('BroadcasterManager initialized');
  }

  // Getters
  RTCVideoRenderer get localRenderer => _localRenderer;
  BroadcasterManager get manager => _manager;
  bool get isConnected => _manager.isConnected;
  bool get isRecording => _manager.isRecording;
  bool get isFlashOn => _manager.isFlashOn;
  MediaStream? get localStream => _manager.localStream;
  String? get broadcasterId => _manager.broadcasterId;

  Future<void> initialize() async {
    try {
      logInfo('Initializing broadcaster...');
      emit(BroadcasterInitializing());

      // Инициализируем рендерер
      await _localRenderer.initialize();
      logInfo('Renderer initialized');

      // Инициализируем менеджер
      await _manager.init();
      logInfo('Manager initialized');

      // Создаем медиа стрим для предварительного просмотра
      await _createInitialStream();

      // Запускаем мониторинг
      _startStateUpdateTimer();
      _startPerformanceMonitoring();

      logInfo('Broadcaster initialized successfully');
    } catch (e, stackTrace) {
      logError('Error initializing broadcaster: $e', stackTrace);
      emit(BroadcasterError('Ошибка инициализации: $e', isCritical: true));
    }
  }

  Future<void> _createInitialStream() async {
    try {
      logInfo('Creating initial media stream for preview...');

      // Создаем стрим для предварительного просмотра
      final mediaConstraints = {
        'audio': false,
        'video': {
          'facingMode': 'environment',
          'width': 1280,
          'height': 720,
          'frameRate': 30,
          'aspectRatio': 16.0 / 9.0,
        },
      };

      final stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);

      if (stream != null) {
        // Привязываем стрим к рендереру
        _localRenderer.srcObject = stream;
        logInfo('Video stream attached to renderer');

        // Эмитим состояние с локальным стримом
        emit(BroadcasterReady(
          isConnected: false,
          isRecording: false,
          isFlashOn: false,
          connectionStatus: 'Готов к подключению',
          localStream: stream,
          broadcasterId: _manager.broadcasterId,
          receiverUrl: receiverUrl,
          currentFps: _currentFps,
          currentBitrate: _currentBitrate,
        ));
      }
    } catch (e, stackTrace) {
      logError('Error creating initial stream: $e', stackTrace);
      // Эмитим состояние без стрима, но готовое к работе
      emit(BroadcasterReady(
        isConnected: false,
        isRecording: false,
        isFlashOn: false,
        connectionStatus: 'Камера недоступна',
        broadcasterId: _manager.broadcasterId,
        receiverUrl: receiverUrl,
        lastError: 'Камера недоступна',
        lastErrorTime: DateTime.now(),
        hasRecentError: true,
      ));
    }
  }

  void _startStateUpdateTimer() {
    _stateUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _updateState();
    });
  }

  void _startPerformanceMonitoring() {
    _performanceMonitor = Timer.periodic(const Duration(seconds: 5), (timer) {
      _updatePerformanceMetrics();
    });
  }

  void _updatePerformanceMetrics() {
    try {
      // Симуляция метрик производительности
      // В реальном приложении здесь были бы системные вызовы
      final now = DateTime.now();

      // CPU usage simulation based on connection state and quality
      if (_manager.isConnected) {
        _currentCpuUsage = (0.3 + (DateTime.now().millisecondsSinceEpoch % 1000) / 10000)
            .clamp(0.0, 1.0);
      } else {
        _currentCpuUsage = 0.1;
      }

      // Thermal state simulation
      if (_manager.isBroadcasting) {
        _currentThermalState = (_currentThermalState + 0.02).clamp(0.0, 1.0);
      } else {
        _currentThermalState = (_currentThermalState - 0.05).clamp(0.0, 1.0);
      }

      // Network latency simulation
      if (_manager.isConnected) {
        _currentNetworkLatency = 50 + (DateTime.now().millisecondsSinceEpoch % 100);
      } else {
        _currentNetworkLatency = 0;
      }

      // FPS tracking
      _currentFps = _manager.isConnected ? 30 : 0;

      // Update warnings
      _updateWarnings();

    } catch (e, stackTrace) {
      logError('Error updating performance metrics: $e', stackTrace);
    }
  }

  void _updateWarnings() {
    _currentWarnings.clear();

    if (_currentThermalState > 0.8) {
      _currentWarnings.add('Устройство перегревается');
    }

    if (_currentCpuUsage > 0.8) {
      _currentWarnings.add('Высокая нагрузка на процессор');
    }

    if (_currentNetworkLatency > 500) {
      _currentWarnings.add('Высокая задержка сети');
    }

    if (_currentFps < 15 && _manager.isConnected) {
      _currentWarnings.add('Низкая частота кадров');
    }
  }

  void _updateState() {
    if (state is BroadcasterReady) {
      final currentState = state as BroadcasterReady;
      final newLocalStream = _manager.localStream;

      // Обновляем рендерер если стрим изменился
      if (newLocalStream != null && currentState.localStream?.id != newLocalStream.id) {
        _localRenderer.srcObject = newLocalStream;
        logInfo('Updated renderer with new stream: ${newLocalStream.id}');
      }

      // Calculate connection strength
      final connectionStrength = _calculateConnectionStrength();

      // Эмитим новое состояние только если что-то значительно изменилось
      final newState = BroadcasterReady(
        isConnected: _manager.isConnected,
        isRecording: _manager.isRecording,
        isFlashOn: _manager.isFlashOn,
        isPowerSaveMode: _manager.isPowerSaveMode,
        connectionStatus: _getConnectionStatus(),
        localStream: newLocalStream ?? currentState.localStream,
        broadcasterId: _manager.broadcasterId,
        receiverUrl: receiverUrl,
        connectionStrength: connectionStrength,
        lastHeartbeat: _manager.isConnected ? DateTime.now() : currentState.lastHeartbeat,
        currentQuality: _getCurrentQuality(),
        networkLatency: _currentNetworkLatency,
        cpuUsage: _currentCpuUsage,
        thermalState: _currentThermalState,
        fps: _currentFps,
        bitrate: _currentBitrate,
        warnings: List.from(_currentWarnings),
        connectedReceivers: _manager.connectedReceivers,
        primaryReceiver: _manager.connectedReceivers.isNotEmpty
            ? _manager.connectedReceivers.first
            : null,
        isMulticastMode: _manager.connectedReceivers.length > 1,
      );

      if (_shouldUpdateState(currentState, newState)) {
        emit(newState);
      }
    }
  }

  bool _shouldUpdateState(BroadcasterReady oldState, BroadcasterReady newState) {
    // Проверяем значительные изменения
    return oldState.isConnected != newState.isConnected ||
        oldState.isRecording != newState.isRecording ||
        oldState.isFlashOn != newState.isFlashOn ||
        oldState.localStream?.id != newState.localStream?.id ||
        (oldState.connectionStrength - newState.connectionStrength).abs() > 0.1 ||
        oldState.connectedReceivers.length != newState.connectedReceivers.length ||
        oldState.warnings.length != newState.warnings.length;
  }

  double _calculateConnectionStrength() {
    if (!_manager.isConnected) return 0.0;

    double strength = 0.5; // Base strength

    // Add strength for low latency
    if (_currentNetworkLatency < 100) {
      strength += 0.3;
    } else if (_currentNetworkLatency < 300) {
      strength += 0.1;
    }

    // Add strength for good performance
    if (_currentCpuUsage < 0.5) {
      strength += 0.1;
    }

    if (_currentThermalState < 0.5) {
      strength += 0.1;
    }

    return strength.clamp(0.0, 1.0);
  }

  String _getCurrentQuality() {
    // Логика определения текущего качества
    if (_manager.isPowerSaveMode) {
      return 'power_save';
    }
    return 'medium'; // Default
  }

  String _getConnectionStatus() {
    if (_manager.isBroadcasting && _manager.isConnected) {
      final receiverCount = _manager.connectedReceivers.length;
      if (receiverCount > 1) {
        return 'Подключено к $receiverCount приемникам';
      }
      return 'Подключено';
    } else if (_manager.isBroadcasting) {
      return 'Подключение...';
    } else {
      return 'Готов к подключению';
    }
  }

  Future<void> startBroadcast() async {
    try {
      logInfo('Starting broadcast to: $receiverUrl');
      emit(BroadcasterConnecting(
        receiverUrl,
        broadcasterId: _manager.broadcasterId,
      ));

      await _manager.startBroadcast(receiverUrl);

      // Обновляем рендерер с новым стримом после подключения
      final stream = _manager.localStream;
      if (stream != null) {
        _localRenderer.srcObject = stream;
        logInfo('Updated renderer after broadcast start');
      }

      logInfo('Broadcast started successfully');
      emit(BroadcasterConnected(
        receiverUrl,
        broadcasterId: _manager.broadcasterId,
        localStream: stream,
      ));

      // Запускаем heartbeat мониторинг
      _startHeartbeatTimer();

      // Переходим в состояние Ready для нормальной работы
      _handleStateChange();

    } catch (e, stackTrace) {
      logError('Error starting broadcast: $e', stackTrace);
      emit(BroadcasterError(
        'Ошибка подключения: $e',
        errorCode: 'CONNECTION_FAILED',
        canRetry: true,
        errorContext: {'receiverUrl': receiverUrl},
      ));
    }
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _sendHeartbeat();
    });
  }

  void _sendHeartbeat() async {
    if (!_manager.isConnected) {
      _heartbeatTimer?.cancel();
      return;
    }

    try {
      // Heartbeat логика уже в BroadcasterManager
      logDebug('Heartbeat check');
    } catch (e) {
      logWarning('Heartbeat failed: $e');
    }
  }

  Future<void> stopBroadcast() async {
    try {
      logInfo('Stopping broadcast...');
      _heartbeatTimer?.cancel();

      await _manager.stopBroadcast();

      // Возвращаемся к предварительному просмотру
      await _createInitialStream();

    } catch (e, stackTrace) {
      logError('Error stopping broadcast: $e', stackTrace);
      emit(BroadcasterError(
        'Ошибка отключения: $e',
        errorCode: 'DISCONNECT_FAILED',
      ));
    }
  }

  // Command methods with enhanced state tracking
  Future<void> capturePhoto() async {
    try {
      logInfo('Capturing photo...');

      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(isCapturingPhoto: true));
      }

      await _manager.capturePhoto();

      // Reset capture state after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (state is BroadcasterReady) {
          final currentState = state as BroadcasterReady;
          emit(currentState.copyWith(isCapturingPhoto: false));
        }
      });

    } catch (e, stackTrace) {
      logError('Error capturing photo: $e', stackTrace);

      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(
          isCapturingPhoto: false,
          lastError: 'Ошибка съемки фото: $e',
          lastErrorTime: DateTime.now(),
          hasRecentError: true,
        ));
      }
    }
  }

  Future<void> captureWithTimer() async {
    try {
      logInfo('Capturing photo with timer...');

      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(
          isCapturingWithTimer: true,
          timerSeconds: 3,
        ));

        // Timer countdown
        for (int i = 3; i > 0; i--) {
          await Future.delayed(const Duration(seconds: 1));
          if (state is BroadcasterReady) {
            final timerState = state as BroadcasterReady;
            emit(timerState.copyWith(timerSeconds: i - 1));
          }
        }
      }

      await _manager.captureWithTimer();

      // Reset timer state
      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(
          isCapturingWithTimer: false,
          timerSeconds: 0,
        ));
      }

    } catch (e, stackTrace) {
      logError('Error capturing with timer: $e', stackTrace);

      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(
          isCapturingWithTimer: false,
          timerSeconds: 0,
          lastError: 'Ошибка съемки с таймером: $e',
          lastErrorTime: DateTime.now(),
          hasRecentError: true,
        ));
      }
    }
  }

  Future<void> toggleRecording() async {
    try {
      if (_manager.isRecording) {
        logInfo('Stopping video recording...');
        await _manager.stopVideoRecording();
      } else {
        logInfo('Starting video recording...');
        await _manager.startVideoRecording();
      }
    } catch (e, stackTrace) {
      logError('Error toggling recording: $e', stackTrace);

      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(
          lastError: 'Ошибка записи видео: $e',
          lastErrorTime: DateTime.now(),
          hasRecentError: true,
        ));
      }
    }
  }

  Future<void> toggleFlash() async {
    try {
      logInfo('Toggling flash...');
      await _manager.toggleFlash();
    } catch (e, stackTrace) {
      logError('Error toggling flash: $e', stackTrace);

      if (state is BroadcasterReady) {
        final currentState = state as BroadcasterReady;
        emit(currentState.copyWith(
          lastError: 'Ошибка переключения вспышки: $e',
          lastErrorTime: DateTime.now(),
          hasRecentError: true,
        ));
      }
    }
  }

  // Settings methods
  Future<void> selectVideoInput(String? deviceId) async {
    try {
      await _manager.selectVideoInput(deviceId);
      _handleStateChange();
    } catch (e, stackTrace) {
      logError('Error selecting video input: $e', stackTrace);
    }
  }

  Future<void> selectVideoFps(String fps) async {
    try {
      await _manager.selectVideoFps(fps);
      _currentFps = int.tryParse(fps) ?? 30;
      _handleStateChange();
    } catch (e, stackTrace) {
      logError('Error selecting video FPS: $e', stackTrace);
    }
  }

  Future<void> selectVideoSize(String size) async {
    try {
      await _manager.selectVideoSize(size);
      _handleStateChange();
    } catch (e, stackTrace) {
      logError('Error selecting video size: $e', stackTrace);
    }
  }

  // Event handlers
  void _handleStateChange() {
    logDebug('State change callback triggered');
    // State update handled by timer
  }

  void _handleError(String error) {
    logError('Manager error: $error');

    // Определяем критичность ошибки
    final isCritical = error.contains('камера') ||
        error.contains('инициализ') ||
        error.contains('permission');

    final canRetry = !error.contains('permission') &&
        !error.contains('не поддерживается');

    emit(BroadcasterError(
      error,
      isCritical: isCritical,
      canRetry: canRetry,
      errorContext: {
        'receiverUrl': receiverUrl,
        'broadcasterId': _manager.broadcasterId,
        'isConnected': _manager.isConnected,
      },
    ));
  }

  void _handleMediaCaptured(XFile media) {
    logInfo('Media captured: ${media.path}');

    if (state is BroadcasterReady) {
      final currentState = state as BroadcasterReady;
      final updatedPaths = List<String>.from(currentState.recentMediaPaths);
      updatedPaths.insert(0, media.path);

      // Keep only last 5 media paths
      if (updatedPaths.length > 5) {
        updatedPaths.removeLast();
      }

      emit(currentState.copyWith(
        recentMediaPaths: updatedPaths,
      ));
    }
  }

  void _handleConnectionFailed() {
    logWarning('Connection failed');
    emit(BroadcasterError(
      'Соединение потеряно',
      errorCode: 'CONNECTION_LOST',
      canRetry: true,
      errorContext: {'receiverUrl': receiverUrl},
    ));
  }

  void _handleQualityChanged(String quality) {
    logInfo('Quality changed to: $quality');

    if (state is BroadcasterReady) {
      final currentState = state as BroadcasterReady;
      emit(currentState.copyWith(
        currentQuality: quality,
        isQualityChanging: false,
      ));
    }
  }

  // Utility methods
  void clearError() {
    if (state is BroadcasterReady) {
      final currentState = state as BroadcasterReady;
      emit(currentState.copyWith(
        lastError: null,
        lastErrorTime: null,
        hasRecentError: false,
      ));
    }
  }

  String getDetailedStatus() {
    if (state is BroadcasterReady) {
      return (state as BroadcasterReady).detailedStatusText;
    }
    return state.toString();
  }

  Map<String, dynamic> getPerformanceStats() {
    return {
      'cpuUsage': _currentCpuUsage,
      'thermalState': _currentThermalState,
      'networkLatency': _currentNetworkLatency,
      'fps': _currentFps,
      'bitrate': _currentBitrate,
      'warnings': _currentWarnings,
      'isConnected': _manager.isConnected,
      'connectionStrength': state is BroadcasterReady
          ? (state as BroadcasterReady).connectionStrength
          : 0.0,
    };
  }

  @override
  Future<void> close() async {
    logInfo('Disposing broadcaster cubit...');

    _stateUpdateTimer?.cancel();
    _performanceMonitor?.cancel();
    _heartbeatTimer?.cancel();
    _streamSubscription?.cancel();

    try {
      await _manager.dispose();
      await _localRenderer.dispose();
    } catch (e, stackTrace) {
      logError('Error disposing broadcaster cubit: $e', stackTrace);
    }

    return super.close();
  }
}