// ReceiverCubit handles WebRTC receiver state and exposes commands for the UI
import 'package:bloc/bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/utils/receiver_manager.dart';

import 'receiver_state.dart';
class ReceiverCubit extends Cubit<ReceiverState> with LoggerMixin, ErrorHandlerMixin {
  @override
  String get loggerContext => 'ReceiverCubit';

  late final ReceiverManager _manager;
  final CommandService _commandService = CommandService();
  StreamSubscription? _errorSubscription;
  Timer? _connectionMonitor;
  Timer? _statsUpdateTimer;
  Timer? _heartbeatTimer;

  ReceiverCubit() : super(const ReceiverState()) {
    logInfo('Creating ReceiverCubit');
    _initializeManager();
    _setupErrorListener();
    _startConnectionMonitoring();
    _startStatsUpdating();
  }

  void _initializeManager() {
    try {
      _manager = ReceiverManager();

      // Set up callbacks
      _manager.onStateChange = _handleStateChange;
      _manager.onStreamChanged = _handleStreamChanged;
      _manager.onError = _handleManagerError;
      _manager.onBroadcastersChanged = _handleBroadcastersChanged;
      _manager.onMediaReceived = _handleMediaReceived;
      _manager.onPhotoReceived = _handlePhotoReceived;
      _manager.onVideoReceived = _handleVideoReceived;

      logInfo('ReceiverManager initialized with callbacks');
    } catch (e, stackTrace) {
      handleError('_initializeManager', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  void _setupErrorListener() {
    final errorService = ErrorHandlingService();
    _errorSubscription = errorService.errorStream.listen((error) {
      if (error.category == ErrorCategory.webrtc ||
          error.category == ErrorCategory.network ||
          error.category == ErrorCategory.media) {
        _handleAppError(error);
      }
    });
  }

  void _startConnectionMonitoring() {
    _connectionMonitor = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkConnectionHealth();
    });
  }

  void _startStatsUpdating() {
    _statsUpdateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateConnectionStats();
    });
  }

  void _checkConnectionHealth() {
    try {
      final isHealthy = _manager.isConnected && _manager.remoteStream != null;
      final connectionStrength = _calculateConnectionStrength();

      if (state.isConnected != isHealthy ||
          (state.connectionStrength - connectionStrength).abs() > 0.1) {
        logInfo('Connection health changed: $isHealthy (strength: $connectionStrength)');
        _updateConnectionState();
      }

      // Check for stale broadcasters
      final now = DateTime.now();
      final staleHeartbeats = <String, DateTime>{};

      for (final broadcaster in state.connectedBroadcasters) {
        final lastHeartbeat = state.broadcasterHeartbeats[broadcaster];
        if (lastHeartbeat != null && now.difference(lastHeartbeat).inSeconds > 30) {
          staleHeartbeats[broadcaster] = lastHeartbeat;
        }
      }

      if (staleHeartbeats.isNotEmpty) {
        logWarning('Detected stale heartbeats: ${staleHeartbeats.keys}');
        emit(state.copyWith(
          broadcasterHeartbeats: Map.from(state.broadcasterHeartbeats)..removeWhere(
                  (key, value) => staleHeartbeats.containsKey(key)
          ),
        ));
      }
    } catch (e, stackTrace) {
      handleError('_checkConnectionHealth', e, stackTrace: stackTrace);
    }
  }

  void _updateConnectionStats() {
    if (!state.isConnected) return;

    try {
      final connectionStrength = _calculateConnectionStrength();
      final now = DateTime.now();

      emit(state.copyWith(
        connectionStrength: connectionStrength,
        statusMessage: _generateStatusMessage(),
      ));
    } catch (e, stackTrace) {
      handleError('_updateConnectionStats', e, stackTrace: stackTrace);
    }
  }

  double _calculateConnectionStrength() {
    if (!_manager.isConnected) return 0.0;

    double strength = 0.5; // Base strength for being connected

    // Add points for active stream
    if (_manager.remoteStream != null) strength += 0.3;

    // Add points for multiple healthy connections
    final healthyBroadcasters = state.connectedBroadcasters
        .where((b) => state.isBroadcasterHealthy(b))
        .length;

    if (healthyBroadcasters > 0) {
      strength += 0.2 * (healthyBroadcasters / state.connectedBroadcasters.length);
    }

    return strength.clamp(0.0, 1.0);
  }

  String _generateStatusMessage() {
    if (!state.isConnected) {
      return 'Ожидание подключения...';
    }

    if (state.hasMultipleConnections) {
      return 'Активна трансляция от ${state.connectionCount} устройств';
    }

    if (state.remoteStream != null) {
      return 'Активна трансляция';
    }

    return 'Подключено, ожидание видео...';
  }

  void _handleAppError(AppError error) {
    logWarning('Handling app error: ${error.message}');

    emit(state.copyWith(
      lastError: error.userFriendlyMessage,
      lastErrorTime: DateTime.now(),
      hasRecentError: true,
    ));
  }

  Future<void> initialize() async {
    try {
      logInfo('Initializing receiver...');
      emit(state.copyWith(isInitializing: true));

      await _manager.init();
      logInfo('Manager initialized');

      _updateConnectionState();

      emit(state.copyWith(
        isInitializing: false,
        isConnected: _manager.isConnected,
        remoteStream: _manager.remoteStream,
        connectedBroadcasters: _manager.connectedBroadcasters,
        connectionCount: _manager.connectionCount,
        statusMessage: _generateStatusMessage(),
      ));

      logInfo('Receiver initialized successfully');
    } catch (e, stackTrace) {
      handleError('initialize', e, stackTrace: stackTrace);

      emit(state.copyWith(
        isInitializing: false,
        lastError: 'Ошибка инициализации: $e',
        lastErrorTime: DateTime.now(),
        hasRecentError: true,
      ));
    }
  }

  void _handleStateChange() {
    logDebug('State change callback triggered');
    _updateConnectionState();
  }

  void _handleStreamChanged(MediaStream? stream) {
    logInfo('Stream changed: ${stream?.id ?? 'null'}');

    emit(state.copyWith(
      remoteStream: stream,
      hasVideoStream: stream != null,
      connectionStrength: _calculateConnectionStrength(),
      statusMessage: _generateStatusMessage(),
    ));
  }

  void _handleManagerError(String error) {
    logError('Manager error: $error');
    handleUserError('ReceiverManager', error);

    emit(state.copyWith(
      lastError: error,
      lastErrorTime: DateTime.now(),
      hasRecentError: true,
    ));
  }

  void _handleBroadcastersChanged(List<String> broadcasters) {
    logInfo('Broadcasters changed: ${broadcasters.length} connected');

    // Update heartbeats for new broadcasters
    final updatedHeartbeats = Map<String, DateTime>.from(state.broadcasterHeartbeats);
    final now = DateTime.now();

    for (final broadcaster in broadcasters) {
      if (!updatedHeartbeats.containsKey(broadcaster)) {
        updatedHeartbeats[broadcaster] = now;
      }
    }

    // Remove heartbeats for disconnected broadcasters
    updatedHeartbeats.removeWhere(
            (broadcaster, heartbeat) => !broadcasters.contains(broadcaster)
    );

    emit(state.copyWith(
      connectedBroadcasters: broadcasters,
      connectionCount: broadcasters.length,
      broadcasterHeartbeats: updatedHeartbeats,
      connectionStrength: _calculateConnectionStrength(),
      statusMessage: _generateStatusMessage(),
    ));
  }

  void _handleMediaReceived(String mediaType, String filePath) {
    logInfo('Media received: $mediaType at $filePath');

    final updatedStats = Map<String, int>.from(state.mediaStats);
    updatedStats[mediaType] = (updatedStats[mediaType] ?? 0) + 1;

    emit(state.copyWith(
      lastMediaReceived: filePath,
      lastMediaType: mediaType,
      lastMediaTime: DateTime.now(),
      mediaStats: updatedStats,
    ));
  }

  void _handlePhotoReceived(String broadcasterUrl, Uint8List data) {
    logInfo('Photo received from $broadcasterUrl: ${data.length} bytes');

    emit(state.copyWith(
      lastPhotoData: data,
      lastMediaTime: DateTime.now(),
    ));
  }

  void _handleVideoReceived(String broadcasterUrl, Uint8List data) {
    logInfo('Video received from $broadcasterUrl: ${data.length} bytes');

    emit(state.copyWith(
      lastVideoData: data,
      lastMediaTime: DateTime.now(),
    ));
  }

  void _updateConnectionState() {
    final isConnected = _manager.isConnected;
    final hasStream = _manager.remoteStream != null;
    final connectionCount = _manager.connectionCount;
    final connectionStrength = _calculateConnectionStrength();

    emit(state.copyWith(
      isConnected: isConnected,
      hasVideoStream: hasStream,
      remoteStream: _manager.remoteStream,
      connectedBroadcasters: _manager.connectedBroadcasters,
      connectionCount: connectionCount,
      connectedBroadcaster: _manager.connectedBroadcaster,
      connectionStrength: connectionStrength,
      statusMessage: _generateStatusMessage(),
    ));
  }

  // Command methods with improved error handling and state tracking
  Future<void> sendCommand(String command) async {
    try {
      logInfo('Sending command: $command');

      emit(state.copyWith(isCommandProcessing: true));

      await _manager.sendCommand(command);

      final updatedHistory = Map<String, DateTime>.from(state.commandHistory);
      updatedHistory[command] = DateTime.now();

      emit(state.copyWith(
        lastCommandSent: command,
        lastCommandTime: DateTime.now(),
        isCommandProcessing: false,
        commandHistory: updatedHistory,
      ));

      logInfo('Command sent successfully: $command');
    } catch (e, stackTrace) {
      handleWebRTCError('sendCommand', e, stackTrace: stackTrace);

      emit(state.copyWith(
        lastError: 'Ошибка отправки команды: $e',
        lastErrorTime: DateTime.now(),
        hasRecentError: true,
        isCommandProcessing: false,
      ));
    }
  }

  Future<void> sendCommandToAll(String command) async {
    try {
      logInfo('Sending command to all: $command');

      if (state.connectedBroadcasters.isEmpty) {
        throw Exception('Нет подключенных устройств');
      }

      emit(state.copyWith(isCommandProcessing: true));

      await _manager.sendCommandToAll(command);

      final updatedHistory = Map<String, DateTime>.from(state.commandHistory);
      updatedHistory['${command}_all'] = DateTime.now();

      emit(state.copyWith(
        lastCommandSent: '$command (всем)',
        lastCommandTime: DateTime.now(),
        isCommandProcessing: false,
        commandHistory: updatedHistory,
      ));

      logInfo('Command sent to all successfully: $command');
    } catch (e, stackTrace) {
      handleWebRTCError('sendCommandToAll', e, stackTrace: stackTrace);

      emit(state.copyWith(
        lastError: 'Ошибка отправки команды всем: $e',
        lastErrorTime: DateTime.now(),
        hasRecentError: true,
        isCommandProcessing: false,
      ));
    }
  }

  Future<void> changeStreamQuality(String quality) async {
    try {
      logInfo('Changing stream quality to: $quality');

      emit(state.copyWith(
        isQualityChanging: true,
        currentQuality: quality,
      ));

      await _manager.sendCommand(quality);

      emit(state.copyWith(
        currentQuality: quality,
        isQualityChanging: false,
        lastQualityChange: DateTime.now(),
        lastCommandSent: 'change_quality_$quality',
        lastCommandTime: DateTime.now(),
      ));

      logInfo('Stream quality change requested: $quality');
    } catch (e, stackTrace) {
      handleWebRTCError('changeStreamQuality', e, stackTrace: stackTrace);

      emit(state.copyWith(
        lastError: 'Ошибка изменения качества: $e',
        lastErrorTime: DateTime.now(),
        hasRecentError: true,
        isQualityChanging: false,
      ));
    }
  }

  // Specific command methods
  Future<void> capturePhoto() async {
    await sendCommand('photo');
  }

  Future<void> toggleFlashlight() async {
    await sendCommand('flashlight');
  }

  Future<void> startTimer() async {
    await sendCommand('timer');
  }

  Future<void> toggleVideoRecording() async {
    await sendCommand('video');
  }

  // Quality control methods
  Future<void> setLowQuality() async {
    await changeStreamQuality('low');
  }

  Future<void> setMediumQuality() async {
    await changeStreamQuality('medium');
  }

  Future<void> setHighQuality() async {
    await changeStreamQuality('high');
  }

  // Connection management
  void switchToPrimaryBroadcaster(String broadcasterUrl) {
    try {
      logInfo('Switching to primary broadcaster: $broadcasterUrl');

      _manager.switchToPrimaryBroadcaster(broadcasterUrl);

      emit(state.copyWith(
        connectedBroadcaster: broadcasterUrl,
        statusMessage: 'Переключено на $broadcasterUrl',
      ));

      logInfo('Switched to primary broadcaster successfully');
    } catch (e, stackTrace) {
      handleError('switchToPrimaryBroadcaster', e, stackTrace: stackTrace);

      emit(state.copyWith(
        lastError: 'Ошибка переключения источника: $e',
        lastErrorTime: DateTime.now(),
        hasRecentError: true,
      ));
    }
  }

  // Heartbeat handling
  void updateBroadcasterHeartbeat(String broadcasterUrl) {
    final updatedHeartbeats = Map<String, DateTime>.from(state.broadcasterHeartbeats);
    updatedHeartbeats[broadcasterUrl] = DateTime.now();

    emit(state.copyWith(
      broadcasterHeartbeats: updatedHeartbeats,
      connectionStrength: _calculateConnectionStrength(),
    ));
  }

  // Error management
  void clearLastError() {
    emit(state.copyWith(
      lastError: null,
      lastErrorTime: null,
      hasRecentError: false,
    ));
  }

  void clearRecentCommands() {
    emit(state.copyWith(
      lastCommandSent: null,
      lastCommandTime: null,
      commandHistory: {},
    ));
  }

  // Debug and monitoring
  void toggleDebugInfo() {
    emit(state.copyWith(
      showDebugInfo: !state.showDebugInfo,
    ));
  }

  // Getters for UI
  List<String> get messages => _manager.messages;
  bool get isConnected => _manager.isConnected;
  MediaStream? get remoteStream => _manager.remoteStream;
  int get connectionCount => _manager.connectionCount;
  List<String> get connectedBroadcasters => _manager.connectedBroadcasters;
  String? get connectedBroadcaster => _manager.connectedBroadcaster;

  Map<String, dynamic> getConnectionStats() {
    return {
      'isConnected': isConnected,
      'hasVideoStream': remoteStream != null,
      'connectionCount': connectionCount,
      'connectedBroadcasters': connectedBroadcasters,
      'currentQuality': state.currentQuality,
      'connectionStrength': state.connectionStrength,
      'lastCommand': state.lastCommandSent,
      'lastCommandTime': state.lastCommandTime?.toIso8601String(),
      'lastError': state.lastError,
      'lastErrorTime': state.lastErrorTime?.toIso8601String(),
      'totalMediaReceived': state.totalMediaReceived,
      'photosReceived': state.photosReceived,
      'videosReceived': state.videosReceived,
      'averageCommandResponseTime': state.averageCommandResponseTime?.inMilliseconds,
    };
  }

  String generateDebugReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== RECEIVER DEBUG REPORT ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    buffer.writeln('Connection Status:');
    buffer.writeln('  Connected: ${isConnected}');
    buffer.writeln('  Has Video Stream: ${remoteStream != null}');
    buffer.writeln('  Connection Count: $connectionCount');
    buffer.writeln('  Connection Strength: ${(state.connectionStrength * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Primary Broadcaster: ${connectedBroadcaster ?? 'None'}');
    buffer.writeln();

    buffer.writeln('Connected Broadcasters:');
    for (final broadcaster in connectedBroadcasters) {
      final isHealthy = state.isBroadcasterHealthy(broadcaster);
      final lastHeartbeat = state.broadcasterHeartbeats[broadcaster];
      buffer.writeln('  - $broadcaster (${isHealthy ? 'Healthy' : 'Stale'})');
      if (lastHeartbeat != null) {
        buffer.writeln('    Last heartbeat: ${DateTime.now().difference(lastHeartbeat).inSeconds}s ago');
      }
    }
    buffer.writeln();

    buffer.writeln('State Information:');
    buffer.writeln('  Current Quality: ${state.currentQuality}');
    buffer.writeln('  Status: ${state.statusText}');
    buffer.writeln('  Last Command: ${state.lastCommandSent}');
    buffer.writeln('  Last Command Time: ${state.lastCommandTime}');
    buffer.writeln('  Is Quality Changing: ${state.isQualityChanging}');
    buffer.writeln('  Is Command Processing: ${state.isCommandProcessing}');
    buffer.writeln();

    buffer.writeln('Media Statistics:');
    buffer.writeln('  Total Received: ${state.totalMediaReceived}');
    buffer.writeln('  Photos: ${state.photosReceived}');
    buffer.writeln('  Videos: ${state.videosReceived}');
    buffer.writeln('  Last Media: ${state.lastMediaType} at ${state.lastMediaTime}');
    buffer.writeln();

    if (state.hasRecentError) {
      buffer.writeln('Recent Error:');
      buffer.writeln('  Error: ${state.lastError}');
      buffer.writeln('  Time: ${state.lastErrorTime}');
      buffer.writeln();
    }

    buffer.writeln('Command History (last 10):');
    final sortedCommands = state.commandHistory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedCommands.take(10)) {
      buffer.writeln('  ${entry.key}: ${entry.value}');
    }
    buffer.writeln();

    buffer.writeln('Recent Messages (last 10):');
    final recentMessages = messages.take(10);
    for (final message in recentMessages) {
      buffer.writeln('  $message');
    }

    return buffer.toString();
  }

  @override
  Future<void> close() async {
    try {
      logInfo('Closing ReceiverCubit...');

      _connectionMonitor?.cancel();
      _statsUpdateTimer?.cancel();
      _heartbeatTimer?.cancel();
      _errorSubscription?.cancel();

      await _manager.dispose();

      logInfo('ReceiverCubit closed successfully');
    } catch (e, stackTrace) {
      handleError('close', e, stackTrace: stackTrace);
    }

    return super.close();
  }
}