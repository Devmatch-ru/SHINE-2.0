// lib/utils/broadcaster_manager.dart (Updated)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

import '../../constants.dart';
import '../../video_size.dart';
import '../../webrtc/discovery_manager.dart';
import '../../webrtc/media_devices_manager.dart';
import '../../webrtc/signaling_server.dart';
import '../../webrtc/types.dart';
import '../../webrtc/webrtc_connection.dart';
import '../service/command_service.dart';
import '../service/logging_service.dart';
import '../service/media_service.dart';
import '../service/network_service.dart';
import '../service/webrtc_service.dart';



class BroadcasterManager with LoggerMixin {
  @override
  String get loggerContext => 'BroadcasterManager';

  // Services
  final LoggingService _loggingService = LoggingService();
  final CommandService _commandService = CommandService();
  final WebRTCService _webrtcService = WebRTCService();
  final MediaService _mediaService = MediaService();
  final NetworkService _networkService = NetworkService();

  // State
  bool _inCalling = false;
  String? _currentReceiverUrl;
  final Map<RTCPeerConnection, RTCDataChannel> _dataChannels = {};

  // Components
  late final MediaDevicesManager _mediaManager;
  late final WebRTCConnection _webrtc;
  late final DiscoveryManager _discovery;
  late final SignalingServer _signaling;

  // Timers
  Timer? _connectionTimer;
  Timer? _thermalMonitor;

  // Recording
  MediaRecorder? _mediaRecorder;
  String? _currentVideoPath;
  bool _isRecording = false;

  // State flags
  bool _isPowerSaveMode = false;
  bool _isFlashOn = false;
  bool _isConnected = false;
  DateTime _lastThermalCheck = DateTime.now();

  // Callbacks
  final VoidCallback? onStateChange;
  final VoidCallback? onCapturePhoto;
  final void Function(String error)? onError;
  final void Function(XFile media)? onMediaCaptured;
  final void Function(MediaType type, String base64Data)? onMediaReceived;
  final void Function(String command)? onCommandReceived;
  final void Function(String quality)? onQualityChanged;
  final VoidCallback? onConnectionFailed;
  final void Function(String fileName, String mediaType, int sentChunks,
      int totalChunks, bool isCompleted)? onTransferProgress;

  BroadcasterManager({
    this.onStateChange,
    this.onCapturePhoto,
    this.onError,
    this.onMediaCaptured,
    this.onMediaReceived,
    this.onCommandReceived,
    this.onQualityChanged,
    this.onConnectionFailed,
    this.onTransferProgress,
  }) {
    _initializeComponents();
    _initializeSettings();
  }

  void _initializeComponents() {
    _mediaManager = MediaDevicesManager(
      onLog: (msg) => logInfo(msg),
      onStateChange: onStateChange,
      onStreamUpdated: _handleStreamUpdated,
    );

    _webrtc = WebRTCConnection(
      onLog: (msg) => logInfo(msg),
      onStateChange: onStateChange,
      onCapturePhoto: onCapturePhoto,
      onIceCandidate: _handleIceCandidate,
      onConnectionFailed: onConnectionFailed,
      onMediaReceived: _handleMediaReceived,
      onCommandReceived: onCommandReceived,
      onQualityChangeRequested: _handleQualityChange,
      onTransferProgress: onTransferProgress,
    );

    _discovery = DiscoveryManager(
      onLog: (msg) => logInfo(msg),
      onStateChange: onStateChange,
    );

    _signaling = SignalingServer(
      onLog: (msg) => logInfo(msg),
      onStateChange: onStateChange,
      onAnswer: (answer) => _webrtc.setRemoteDescription(answer),
      onCandidate: (candidate) => _webrtc.addIceCandidate(candidate),
      getOffer: () => _webrtc.offer,
      getCandidates: () => _webrtc.candidates,
    );
  }

  Future<void> _initializeSettings() async {
    // Initialize any required settings
  }

  // Getters
  MediaStream? get localStream => _mediaManager.localStream;
  bool get isBroadcasting => _inCalling;
  List<String> get messages => _loggingService.messages;
  List<MediaDeviceInfo> get videoInputs => _mediaManager.videoInputs;
  String? get selectedVideoFPS => _mediaManager.selectedVideoFPS;
  VideoSize get selectedVideoSize => _mediaManager.selectedVideoSize;
  List<String> get connectedReceivers => _signaling.connectedReceivers;
  Set<String> get availableReceivers => _discovery.receivers;
  bool get isRecording => _isRecording;
  bool get isFlashOn => _isFlashOn;
  bool get isPowerSaveMode => _isPowerSaveMode;
  bool get isConnected => _isConnected;

  Future<void> init() async {
    try {
      logInfo('Initializing broadcaster manager...');
      await _mediaManager.init();
      await _discovery.startDiscoveryListener();
      _startThermalMonitoring();
      logInfo('Broadcaster manager initialized successfully');
    } catch (e, stackTrace) {
      logError('Failed to initialize broadcaster manager: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> toggleFlash() async {
    try {
      logInfo('Flashlight toggle requested');

      if (_mediaManager.localStream == null) {
        throw Exception('No media stream available');
      }

      final videoTracks = _mediaManager.localStream!.getVideoTracks();
      if (videoTracks.isEmpty) {
        throw Exception('No video tracks available');
      }

      final videoTrack = videoTracks.first;
      final hasTorch = await videoTrack.hasTorch();
      logInfo('Camera torch support: $hasTorch');

      if (!hasTorch) {
        throw Exception('Camera does not support torch mode');
      }

      _isFlashOn = !_isFlashOn;
      await videoTrack.setTorch(_isFlashOn);

      final status = _isFlashOn ? 'включен' : 'выключен';
      logInfo('Flashlight $status successfully');
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error toggling flash: $e', stackTrace);
      onError?.call('Ошибка при переключении вспышки: $e');
    }
  }

  Future<void> captureWithTimer() async {
    onStateChange?.call();
    await Future.delayed(const Duration(seconds: 3));
    await capturePhoto();
  }

  Future<void> capturePhoto() async {
    try {
      logInfo('Starting photo capture process...');

      if (_mediaManager.localStream == null) {
        throw Exception('No video stream available');
      }

      final videoTracks = _mediaManager.localStream!.getVideoTracks();
      if (videoTracks.isEmpty) {
        throw Exception('No video tracks in stream');
      }

      final filePath = await _mediaService.capturePhotoFromTrack(videoTracks.first);
      final xFile = XFile(filePath);
      onMediaCaptured?.call(xFile);

      logInfo('Sending photo to receiver...');
      await _sendMediaToReceiver(MediaType.photo, xFile);
    } catch (e, stackTrace) {
      logError('Error capturing photo: $e', stackTrace);
      onError?.call('Ошибка при съемке фото: $e');
    }
  }

  Future<void> startVideoRecording() async {
    try {
      logInfo('Starting video recording from WebRTC stream...');

      if (_mediaManager.localStream == null) {
        throw Exception('No video stream available');
      }

      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_$timestamp.mp4';
      _currentVideoPath = '${directory.path}/$fileName';

      _mediaRecorder = MediaRecorder(albumName: 'Shine');

      final videoTrack = _mediaManager.localStream!.getVideoTracks().first;
      await _mediaRecorder!.start(
        _currentVideoPath!,
        videoTrack: videoTrack,
        audioChannel: RecorderAudioChannel.OUTPUT,
      );

      _isRecording = true;
      logInfo('Video recording started: $_currentVideoPath');
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error starting video recording: $e', stackTrace);
      onError?.call('Ошибка при начале записи видео: $e');
    }
  }

  Future<void> stopVideoRecording() async {
    try {
      logInfo('Stopping video recording...');

      if (_mediaRecorder == null || !_isRecording) {
        logInfo('No active recording to stop');
        return;
      }

      await _mediaRecorder!.stop();
      _mediaRecorder = null;
      _isRecording = false;

      if (_currentVideoPath != null) {
        await _mediaService.saveToGallery(_currentVideoPath!, 'video');

        final xFile = XFile(_currentVideoPath!);
        logInfo('Video recorded: $_currentVideoPath');
        onMediaCaptured?.call(xFile);

        await _sendMediaToReceiver(MediaType.video, xFile);
        _currentVideoPath = null;
      }

      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error stopping video recording: $e', stackTrace);
      onError?.call('Ошибка при остановке записи видео: $e');
    }
  }

  Future<void> startBroadcast(String receiverUrl) async {
    try {
      if (receiverUrl.isEmpty) {
        throw Exception('Receiver URL is empty');
      }

      // Validate URL
      final uri = _networkService.validateReceiverUrl(receiverUrl);
      if (uri == null) {
        throw Exception('Invalid receiver URL format');
      }

      // Get WiFi IP
      final wifiIP = await _networkService.getWifiIP();
      if (wifiIP == null) {
        throw Exception('Wi-Fi IP not available');
      }

      _currentReceiverUrl = receiverUrl;

      // Create media stream with retry
      await _createMediaStreamWithRetry();

      // Create WebRTC connection with retry
      await _createWebRTCConnectionWithRetry();

      await _signaling.start();
      _inCalling = true;
      onStateChange?.call();

      // Set connection timeout
      _setConnectionTimeout();

      // Send offer to receiver
      await _networkService.sendOfferToReceiver(
        receiverUrl,
        _webrtc.offer!,
        'http://$wifiIP:${AppConstants.signalingPort}',
      );

      logInfo('Broadcast started successfully');
    } catch (e, stackTrace) {
      logError('Error starting broadcast: $e', stackTrace);
      await stopBroadcast();
      onError?.call('Ошибка при запуске трансляции: $e');
      rethrow;
    }
  }

  Future<void> _createMediaStreamWithRetry() async {
    final mediaConstraints = _buildMediaConstraints();

    for (int attempt = 0; attempt < 15; attempt++) {
      try {
        await _mediaManager.createStream(mediaConstraints);
        if (_mediaManager.localStream != null) {
          logInfo('Media stream created successfully on attempt ${attempt + 1}');
          return;
        }
      } catch (e) {
        logWarning('Attempt ${attempt + 1} to create stream failed: $e');
        if (attempt >= 2) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    throw Exception('Failed to create media stream after multiple attempts');
  }

  Future<void> _createWebRTCConnectionWithRetry() async {
    for (int attempt = 0; attempt < 15; attempt++) {
      try {
        await _webrtc.createConnection(_mediaManager.localStream!);
        if (_webrtc.offer != null) {
          logInfo('WebRTC connection created successfully on attempt ${attempt + 1}');
          return;
        }
      } catch (e) {
        logWarning('Attempt ${attempt + 1} to create WebRTC connection failed: $e');
        if (attempt >= 2) rethrow;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    throw Exception('WebRTC offer is null after multiple attempts');
  }

  Map<String, dynamic> _buildMediaConstraints() {
    return {
      'audio': false,
      'video': {
        'facingMode': 'environment',
        'width': selectedVideoSize.width,
        'height': selectedVideoSize.height,
        'frameRate': int.tryParse(selectedVideoFPS ?? '') ?? 30,
        'aspectRatio': 16.0 / 9.0,
        'advanced': [
          {
            'width': {
              'min': selectedVideoSize.width,
              'ideal': selectedVideoSize.width
            },
            'height': {
              'min': selectedVideoSize.height,
              'ideal': selectedVideoSize.height
            },
          },
          {
            'frameRate': {
              'min': 24,
              'ideal': int.tryParse(selectedVideoFPS ?? '') ?? 30
            },
          },
          {
            'exposureMode': 'continuous',
            'focusMode': 'continuous',
            'whiteBalanceMode': 'continuous',
          }
        ]
      },
    };
  }

  void _setConnectionTimeout() {
    bool hasResponse = false;
    _connectionTimer = Timer(AppConstants.connectionTimeout, () {
      if (!hasResponse) {
        logError('Connection timeout after ${AppConstants.connectionTimeout.inSeconds} seconds');
        stopBroadcast();
      }
    });
  }

  Future<void> _sendMediaToReceiver(MediaType type, XFile media) async {
    try {
      logInfo('Sending ${type.name} to receiver...');
      final success = await _webrtc.sendMedia(type, media);

      if (success) {
        logInfo('${type.name} sent successfully');
      } else {
        logWarning('Failed to send ${type.name}');
      }
    } catch (e, stackTrace) {
      logError('Error sending media: $e', stackTrace);
    }
  }

  Future<void> _handleIceCandidate(RTCIceCandidate candidate) async {
    if (_currentReceiverUrl == null) return;

    try {
      await _networkService.sendIceCandidate(_currentReceiverUrl!, candidate);
    } catch (e, stackTrace) {
      logError('Error sending ICE candidate: $e', stackTrace);
    }
  }

  void _handleMediaReceived(MediaType type, String base64Data) {
    onMediaReceived?.call(type, base64Data);
  }

  void _handleQualityChange(String quality) async {
    try {
      logInfo('Changing stream quality to: $quality');

      final qualityConfig = AppConstants.videoQualities[quality];
      if (qualityConfig == null) {
        logWarning('Unknown quality setting: $quality, using medium');
        return _handleQualityChange('medium');
      }

      final constraints = qualityConfig.toConstraints();
      await _mediaManager.updateStreamWithConstraints(constraints);

      if (_mediaManager.localStream != null) {
        await _webrtc.updateStream(_mediaManager.localStream!);
      }

      logInfo('Stream quality changed successfully to: $quality with bitrate ${qualityConfig.bitrate ~/ 1000}kbps');
      onQualityChanged?.call(quality);
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error changing quality: $e', stackTrace);
      onError?.call('Ошибка при изменении качества: $e');
    }
  }

  Future<void> stopBroadcast() async {
    if (!_inCalling) return;

    try {
      logInfo('Stopping broadcast...');
      _inCalling = false;
      _connectionTimer?.cancel();

      await _webrtc.close();
      await _signaling.stop();

      _dataChannels.clear();
      _currentReceiverUrl = null;

      onStateChange?.call();
      logInfo('Broadcast stopped successfully');
    } catch (e, stackTrace) {
      logError('Error stopping broadcast: $e', stackTrace);
      onError?.call('Ошибка при остановке трансляции: $e');
    }
  }

  void _handleStreamUpdated(MediaStream stream) async {
    try {
      logInfo('Stream updated, updating WebRTC connection...');
      await _webrtc.updateStream(stream);
      logInfo('WebRTC connection updated with new stream');
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error updating WebRTC stream: $e', stackTrace);
      onError?.call('Ошибка при обновлении потока: $e');
    }
  }

  void _startThermalMonitoring() {
    _thermalMonitor = Timer.periodic(AppConstants.thermalCheckInterval, (timer) {
      _checkThermalStateAndOptimize();
    });
  }

  void _checkThermalStateAndOptimize() {
    final now = DateTime.now();
    final timeSinceLastCheck = now.difference(_lastThermalCheck);

    if (timeSinceLastCheck.inMinutes > 3 && _inCalling && !_isPowerSaveMode) {
      logInfo('Enabling power save mode to prevent overheating');
      _enablePowerSaveMode();
    }

    _lastThermalCheck = now;
  }

  void _enablePowerSaveMode() async {
    if (_isPowerSaveMode) return;

    try {
      _isPowerSaveMode = true;
      logInfo('Power save mode enabled');

      await _handleQualityChange('medium');
      onQualityChanged?.call('power_save');
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error enabling power save mode: $e', stackTrace);
    }
  }

  // Delegate methods for simplicity
  Future<List<String>> discoverReceivers() => _discovery.discoverReceivers();
  Future<void> refreshReceivers() async {
    await _discovery.discoverReceivers();
    onStateChange?.call();
  }
  Future<void> selectVideoInput(String? deviceId) => _mediaManager.selectVideoInput(deviceId);
  Future<void> selectVideoFps(String fps) => _mediaManager.selectVideoFps(fps);
  Future<void> selectVideoSize(String size) => _mediaManager.selectVideoSize(size);

  Future<void> dispose() async {
    try {
      logInfo('Disposing broadcaster manager...');
      await stopBroadcast();

      _thermalMonitor?.cancel();
      await Future.delayed(const Duration(milliseconds: 300));

      await _discovery.dispose();
      await _mediaManager.dispose();

      _connectionTimer?.cancel();
      logInfo('Broadcaster manager disposed successfully');
    } catch (e, stackTrace) {
      logError('Error during disposal: $e', stackTrace);
    }
  }
}