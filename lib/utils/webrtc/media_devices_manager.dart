import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../video_size.dart';
import 'dart:async';

class MediaDevicesManager {
  List<MediaDeviceInfo> _devices = [];
  String? _selectedVideoInputId;
  String? _selectedVideoFPS = '30';
  VideoSize _selectedVideoSize = VideoSize(1280, 720);
  MediaStream? _localStream;
  final void Function(String) _onLog;
  final VoidCallback? onStateChange;
  final void Function(MediaStream)? onStreamUpdated;

  Timer? _performanceMonitor;
  bool _isLowPowerMode = false;
  DateTime _lastQualityAdjustment = DateTime.now();

  MediaDevicesManager({
    required void Function(String) onLog,
    this.onStateChange,
    this.onStreamUpdated,
  }) : _onLog = onLog;

  MediaStream? get localStream => _localStream;
  List<MediaDeviceInfo> get videoInputs =>
      _devices.where((d) => d.kind == 'videoinput').toList();
  String? get selectedVideoFPS => _selectedVideoFPS;
  VideoSize get selectedVideoSize => _selectedVideoSize;
  bool get isLowPowerMode => _isLowPowerMode;

  Future<void> init() async {
    await _loadDevices();
    navigator.mediaDevices.ondevicechange = (event) => _loadDevices();
    _startPerformanceMonitoring();
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
      final videoTrack = _localStream!.getVideoTracks().first;

      _onLog('Checking performance...');

      final uptime = now.difference(_lastQualityAdjustment);
      if (uptime.inMinutes > 5 && !_isLowPowerMode) {
        await _adaptiveQualityReduction();
        _lastQualityAdjustment = now;
      }
    } catch (e) {
      _onLog('Error checking performance: $e');
    }
  }

  bool _shouldReduceQuality(Map<String, dynamic> stats) {
    return false; // Пока отключено, можно настроить позже
  }

  bool _canIncreaseQuality(Map<String, dynamic> stats) {
    return false; // Пока отключено
  }

  Future<void> _adaptiveQualityReduction() async {
    if (!_isLowPowerMode) {
      _onLog('Switching to low power mode due to performance issues');
      _isLowPowerMode = true;

      await _applyLowPowerSettings();
    }
  }

  Future<void> _adaptiveQualityIncrease() async {
    if (_isLowPowerMode) {
      _onLog('Switching back to normal mode - performance improved');
      _isLowPowerMode = false;

      await _applyNormalSettings();
    }
  }

  Future<void> _applyLowPowerSettings() async {
    final constraints = {
      'audio': false,
      'video': {
        'width': 640,
        'height': 360,
        'frameRate': 15,
        'facingMode': 'environment',
        'aspectRatio': 16.0 / 9.0,
        'advanced': [
          {'powerLineFrequency': 50},
          {'whiteBalanceMode': 'manual'},
          {'exposureMode': 'manual'},
        ]
      },
    };

    await updateStreamWithConstraints(constraints);
    onStateChange?.call();
  }

  Future<void> _applyNormalSettings() async {
    await createStream();
    onStateChange?.call();
  }

  Future<void> dispose() async {
    _performanceMonitor?.cancel();
    await stopStream();
    navigator.mediaDevices.ondevicechange = null;
  }

  Future<void> _loadDevices() async {
    if (WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
      var status = await Permission.camera.request();
      if (status.isPermanentlyDenied) _onLog('Camera permission denied');
      status = await Permission.microphone.request();
      if (status.isPermanentlyDenied) _onLog('Microphone permission denied');
    }
    final devices = await navigator.mediaDevices.enumerateDevices();
    _devices = devices;
    _onLog('Devices loaded: ${devices.map((d) => d.label).toList()}');
    onStateChange?.call();
  }

  Future<void> selectVideoInput(String? deviceId) async {
    _selectedVideoInputId = deviceId;
    if (_localStream != null) {
      await updateStream();
    }
  }

  Future<void> selectVideoFps(String fps) async {
    _selectedVideoFPS = fps;
    _onLog('Video FPS changed to: $fps');
    if (_localStream != null) {
      await updateStream();
    }
    onStateChange?.call();
  }

  Future<void> selectVideoSize(String size) async {
    _selectedVideoSize = VideoSize.fromString(size);
    _onLog('Video size changed to: $size');
    if (_localStream != null) {
      await updateStream();
    }
    onStateChange?.call();
  }

  Future<MediaStream> createStream([Map<String, dynamic>? constraints]) async {
    final defaultConstraints = {
      'audio': false,
      'video': {
        if (_selectedVideoInputId != null && kIsWeb)
          'deviceId': {'exact': _selectedVideoInputId},
        if (_selectedVideoInputId != null && !kIsWeb)
          'optional': [
            {'sourceId': _selectedVideoInputId}
          ],
        'facingMode': 'environment',
        'width': _selectedVideoSize.width,
        'height': _selectedVideoSize.height,
        'frameRate': double.parse(_selectedVideoFPS!),
      },
    };

    _localStream = await navigator.mediaDevices.getUserMedia(
      constraints ?? defaultConstraints,
    );

    var videoTrack = _localStream!.getVideoTracks().first;
    _onLog('Video track settings: ${videoTrack.getSettings()}');
    onStateChange?.call();

    return _localStream!;
  }

  Future<void> updateStream() async {
    try {
      await stopStream();

      await Future.delayed(const Duration(milliseconds: 200));

      await createStream();
      _onLog('Stream updated with new settings');

      if (_localStream != null) {
        onStreamUpdated?.call(_localStream!);
      }

      onStateChange?.call();
    } catch (e) {
      _onLog('Error updating stream: $e');
      rethrow;
    }
  }

  Future<void> updateStreamWithConstraints(
      Map<String, dynamic> constraints) async {
    try {
      _onLog('Updating stream with custom constraints...');

      await stopStream();

      await Future.delayed(const Duration(milliseconds: 300));

      _localStream = await navigator.mediaDevices.getUserMedia(constraints);

      if (_localStream != null) {
        var videoTrack = _localStream!.getVideoTracks().first;
        _onLog('New video track settings: ${videoTrack.getSettings()}');

        onStreamUpdated?.call(_localStream!);
      }

      _onLog('Stream updated with custom constraints successfully');
      onStateChange?.call();
    } catch (e) {
      _onLog('Error updating stream with constraints: $e');
      rethrow;
    }
  }

  Future<void> stopStream() async {
    if (_localStream != null) {
      _onLog('Stopping current stream...');

      final tracks = _localStream!.getTracks();
      for (var track in tracks) {
        _onLog('Stopping track: ${track.kind}');
        await track.stop();
      }

      await _localStream!.dispose();
      _localStream = null;

      _onLog('Stream stopped and disposed');
      onStateChange?.call();
    }
  }
}
