// lib/utils/webrtc/media_devices_manager.dart (Updated)
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../constants.dart';
import '../service/logging_service.dart';
import '../video_size.dart';
class MediaDevicesManager with LoggerMixin {
  @override
  String get loggerContext => 'MediaDevicesManager';

  // Device state
  List<MediaDeviceInfo> _devices = [];
  String? _selectedVideoInputId;
  String? _selectedVideoFPS = '30';
  VideoSize _selectedVideoSize = VideoSize(1280, 720);
  MediaStream? _localStream;

  // Performance monitoring
  Timer? _performanceMonitor;
  bool _isLowPowerMode = false;
  DateTime _lastQualityAdjustment = DateTime.now();

  // Callbacks
  final VoidCallback? onStateChange;
  final void Function(MediaStream)? onStreamUpdated;

  MediaDevicesManager({
    this.onStateChange,
    this.onStreamUpdated,
  });

  // Getters
  MediaStream? get localStream => _localStream;
  List<MediaDeviceInfo> get videoInputs =>
      _devices.where((d) => d.kind == 'videoinput').toList();
  String? get selectedVideoFPS => _selectedVideoFPS;
  VideoSize get selectedVideoSize => _selectedVideoSize;
  bool get isLowPowerMode => _isLowPowerMode;

  Future<void> init() async {
    try {
      logInfo('Initializing media devices manager...');
      await _requestPermissions();
      await _loadDevices();
      navigator.mediaDevices.ondevicechange = (event) => _loadDevices();
      _startPerformanceMonitoring();
      logInfo('Media devices manager initialized successfully');
    } catch (e, stackTrace) {
      logError('Error initializing media devices manager: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    if (WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
      final cameraStatus = await Permission.camera.request();
      if (cameraStatus.isPermanentlyDenied) {
        logError('Camera permission permanently denied');
        throw Exception('Camera permission required');
      }

      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus.isPermanentlyDenied) {
        logWarning('Microphone permission permanently denied');
      }
    }
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      _devices = devices;
      logInfo('Devices loaded: ${devices.length} total, ${videoInputs.length} video inputs');

      for (final device in videoInputs) {
        logInfo('Video device: ${device.label} (${device.deviceId})');
      }

      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error loading devices: $e', stackTrace);
    }
  }

  void _startPerformanceMonitoring() {
    _performanceMonitor = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkPerformanceAndAdjust();
    });
  }

  void _checkPerformanceAndAdjust() async {
    if (_localStream == null) return;

    final now = DateTime.now();
    if (now.difference(_lastQualityAdjustment).inSeconds < 30) return;

    try {
      logDebug('Checking performance...');

      final uptime = now.difference(_lastQualityAdjustment);
      if (uptime.inMinutes > 5 && !_isLowPowerMode) {
        await _enableLowPowerMode();
        _lastQualityAdjustment = now;
      }
    } catch (e, stackTrace) {
      logError('Error checking performance: $e', stackTrace);
    }
  }

  Future<void> _enableLowPowerMode() async {
    if (_isLowPowerMode) return;

    try {
      logInfo('Enabling low power mode for thermal management');
      _isLowPowerMode = true;

      final lowPowerConstraints = AppConstants.videoQualities['low']!.toConstraints();
      await updateStreamWithConstraints(lowPowerConstraints);

      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error enabling low power mode: $e', stackTrace);
    }
  }

  Future<void> _disableLowPowerMode() async {
    if (!_isLowPowerMode) return;

    try {
      logInfo('Disabling low power mode');
      _isLowPowerMode = false;

      await createStream();
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error disabling low power mode: $e', stackTrace);
    }
  }

  Future<void> selectVideoInput(String? deviceId) async {
    try {
      _selectedVideoInputId = deviceId;
      logInfo('Video input selected: $deviceId');

      if (_localStream != null) {
        await updateStream();
      }
    } catch (e, stackTrace) {
      logError('Error selecting video input: $e', stackTrace);
    }
  }

  Future<void> selectVideoFps(String fps) async {
    try {
      _selectedVideoFPS = fps;
      logInfo('Video FPS changed to: $fps');

      if (_localStream != null) {
        await updateStream();
      }

      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error selecting video FPS: $e', stackTrace);
    }
  }

  Future<void> selectVideoSize(String size) async {
    try {
      _selectedVideoSize = VideoSize.fromString(size);
      logInfo('Video size changed to: $size');

      if (_localStream != null) {
        await updateStream();
      }

      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error selecting video size: $e', stackTrace);
    }
  }

  Future<MediaStream> createStream([Map<String, dynamic>? constraints]) async {
    try {
      final finalConstraints = constraints ?? _buildDefaultConstraints();

      logInfo('Creating media stream with constraints: $finalConstraints');

      _localStream = await navigator.mediaDevices.getUserMedia(finalConstraints);

      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final videoTrack = videoTracks.first;
          logInfo('Video track created - Settings: ${videoTrack.getSettings()}');
        }
      }

      onStateChange?.call();
      return _localStream!;
    } catch (e, stackTrace) {
      logError('Error creating media stream: $e', stackTrace);
      rethrow;
    }
  }

  Map<String, dynamic> _buildDefaultConstraints() {
    final constraints = <String, dynamic>{
      'audio': false,
      'video': <String, dynamic>{
        'facingMode': 'environment',
        'width': _selectedVideoSize.width,
        'height': _selectedVideoSize.height,
        'frameRate': double.parse(_selectedVideoFPS!),
        'aspectRatio': 16.0 / 9.0,
      },
    };

    // Add device selection if available
    if (_selectedVideoInputId != null) {
      final videoConstraints = constraints['video'] as Map<String, dynamic>;
      if (kIsWeb) {
        videoConstraints['deviceId'] = {'exact': _selectedVideoInputId};
      } else {
        videoConstraints['optional'] = [
          {'sourceId': _selectedVideoInputId}
        ];
      }
    }

    return constraints;
  }

  Future<void> updateStream() async {
    try {
      logInfo('Updating media stream...');

      await stopStream();
      await Future.delayed(const Duration(milliseconds: 200));

      await createStream();
      logInfo('Stream updated with new settings');

      if (_localStream != null) {
        onStreamUpdated?.call(_localStream!);
      }

      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error updating stream: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> updateStreamWithConstraints(Map<String, dynamic> constraints) async {
    try {
      logInfo('Updating stream with custom constraints...');

      await stopStream();
      await Future.delayed(const Duration(milliseconds: 300));

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
          final videoTrack = videoTracks.first;
          logInfo('New video track settings: ${videoTrack.getSettings()}');
        }

        onStreamUpdated?.call(_localStream!);
      }

      logInfo('Stream updated with custom constraints successfully');
      onStateChange?.call();
    } catch (e, stackTrace) {
      logError('Error updating stream with constraints: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> stopStream() async {
    if (_localStream != null) {
      try {
        logInfo('Stopping current stream...');

        final tracks = _localStream!.getTracks();
        for (final track in tracks) {
          logDebug('Stopping track: ${track.kind}');
          await track.stop();
        }

        await _localStream!.dispose();
        _localStream = null;

        logInfo('Stream stopped and disposed');
        onStateChange?.call();
      } catch (e, stackTrace) {
        logError('Error stopping stream: $e', stackTrace);
      }
    }
  }

  Future<void> optimizeForQuality(String quality) async {
    try {
      final qualityConfig = AppConstants.videoQualities[quality];
      if (qualityConfig == null) {
        logWarning('Unknown quality setting: $quality');
        return;
      }

      logInfo('Optimizing stream for quality: $quality');

      _selectedVideoSize = VideoSize(qualityConfig.width, qualityConfig.height);
      _selectedVideoFPS = qualityConfig.frameRate.toString();

      if (_localStream != null) {
        await updateStreamWithConstraints(qualityConfig.toConstraints());
      }

      logInfo('Stream optimized for $quality quality');
    } catch (e, stackTrace) {
      logError('Error optimizing for quality: $e', stackTrace);
    }
  }

  void toggleLowPowerMode() {
    if (_isLowPowerMode) {
      _disableLowPowerMode();
    } else {
      _enableLowPowerMode();
    }
  }

  Future<void> dispose() async {
    try {
      logInfo('Disposing media devices manager...');

      _performanceMonitor?.cancel();
      await stopStream();
      navigator.mediaDevices.ondevicechange = null;

      logInfo('Media devices manager disposed successfully');
    } catch (e, stackTrace) {
      logError('Error disposing media devices manager: $e', stackTrace);
    }
  }
}