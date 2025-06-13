import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../settings_manager.dart';
import '../video_size.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class MediaDevicesManager {
  List<MediaDeviceInfo> _devices = [];
  String? _selectedVideoInputId;
  String? _selectedVideoFPS = '30';
  VideoSize _selectedVideoSize = VideoSize(1280, 720);
  MediaStream? _localStream;
  bool _isBackCamera = true;

  // Camera related
  CameraController? _cameraController;
  bool _isFlashlightOn = false;
  bool _isRecording = false;
  XFile? _lastCapturedMedia;

  // Dependencies
  final SettingsManager _settings;
  final void Function(String) _onLog;
  final VoidCallback? onStateChange;

  MediaDevicesManager({
    required SettingsManager settings,
    required void Function(String) onLog,
    this.onStateChange,
  })  : _settings = settings,
        _onLog = onLog;

  // Getters
  MediaStream? get localStream => _localStream;
  CameraController? get cameraController => _cameraController;
  List<MediaDeviceInfo> get videoInputs =>
      _devices.where((d) => d.kind == 'videoinput').toList();
  String? get selectedVideoFPS => _selectedVideoFPS;
  VideoSize get selectedVideoSize => _selectedVideoSize;
  bool get isBackCamera => _isBackCamera;
  bool get isFlashlightOn => _isFlashlightOn;
  bool get isRecording => _isRecording;
  XFile? get lastCapturedMedia => _lastCapturedMedia;

  Future<void> init() async {
    await _requestPermissions();
    await _loadDevices();
    await _initCamera();

    // Set up device change listener
    navigator.mediaDevices.ondevicechange = (event) => _loadDevices();

    // Select back camera by default
    await _selectBackCamera();
  }

  Future<void> _requestPermissions() async {
    if (WebRTC.platformIsAndroid || WebRTC.platformIsIOS) {
      var status = await Permission.camera.request();
      if (status.isPermanentlyDenied) {
        _onLog('Camera permission denied');
        throw Exception('Camera permission required');
      }

      status = await Permission.microphone.request();
      if (status.isPermanentlyDenied) {
        _onLog('Microphone permission denied');
      }
    }
  }

  Future<void> _loadDevices() async {
    final devices = await navigator.mediaDevices.enumerateDevices();
    _devices = devices;
    _onLog('Devices loaded: ${devices.map((d) => d.label).toList()}');
    onStateChange?.call();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }

    // Find back camera
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      _settings.isHighQualityEnabled
          ? ResolutionPreset.max
          : ResolutionPreset.medium,
      enableAudio: false, // Disable audio for WebRTC compatibility
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _cameraController!.initialize();
      _isBackCamera = backCamera.lensDirection == CameraLensDirection.back;
      onStateChange?.call();
    } catch (e) {
      _onLog('Failed to initialize camera: $e');
      throw e;
    }
  }

  Future<void> _selectBackCamera() async {
    final cameras = videoInputs;
    if (cameras.isEmpty) return;

    // Try to find back camera
    String? backCameraId;
    for (var device in cameras) {
      if (device.label.toLowerCase().contains('back') ||
          device.label.toLowerCase().contains('rear')) {
        backCameraId = device.deviceId;
        break;
      }
    }

    // If no back camera found, use the last camera (usually back on mobile)
    _selectedVideoInputId = backCameraId ?? cameras.last.deviceId;
    _isBackCamera = true;
  }

  Future<void> toggleCamera() async {
    if (_cameraController == null) return;

    final cameras = await availableCameras();
    if (cameras.length < 2) return;

    final currentCamera = _cameraController!.description;
    final newCamera = cameras.firstWhere(
      (camera) => camera.lensDirection != currentCamera.lensDirection,
      orElse: () => currentCamera,
    );

    // If flashlight is on, turn it off before switching
    if (_isFlashlightOn) {
      await _toggleFlashlightInternal(false);
    }

    // Dispose current controller
    await _cameraController!.dispose();

    // Create new controller
    _cameraController = CameraController(
      newCamera,
      _settings.isHighQualityEnabled
          ? ResolutionPreset.max
          : ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    await _cameraController!.initialize();
    _isBackCamera = newCamera.lensDirection == CameraLensDirection.back;

    // Update WebRTC stream if active
    final webrtcCameras = videoInputs;
    if (webrtcCameras.isNotEmpty) {
      _selectedVideoInputId = _isBackCamera
          ? webrtcCameras.lastOrNull?.deviceId
          : webrtcCameras.firstOrNull?.deviceId;

      if (_localStream != null) {
        await updateStream();
      }
    }

    onStateChange?.call();
  }

  Future<bool> toggleFlashlight() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    // Check if flash is available (only on back cameras)
    if (!_isBackCamera) {
      throw Exception('Flash is only available on back camera');
    }

    await _toggleFlashlightInternal(!_isFlashlightOn);
    onStateChange?.call();
    return _isFlashlightOn;
  }

  Future<void> _toggleFlashlightInternal(bool enable) async {
    if (_cameraController == null) return;

    try {
      if (enable) {
        await _cameraController!.setFlashMode(FlashMode.torch);
        _isFlashlightOn = true;
      } else {
        await _cameraController!.setFlashMode(FlashMode.off);
        _isFlashlightOn = false;
      }
    } catch (e) {
      _onLog('Failed to toggle flashlight: $e');
      throw e;
    }
  }

  // WebRTC Stream Management
  Future<MediaStream> createStream() async {
    try {
      // Stop existing tracks before creating new stream
      await stopStream();

      // First try to get stream from camera controller
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        try {
          // Start camera preview
          await _cameraController!.startImageStream((image) {
            // Handle preview frames if needed
          });

          // Get video stream using WebRTC with exact camera device
          final cameras = await availableCameras();
          final currentCamera = _cameraController!.description;
          final currentCameraIndex = cameras.indexOf(currentCamera);

          // Get the correct device ID
          String deviceId = _selectedVideoInputId ??
              (videoInputs.isNotEmpty
                  ? videoInputs[currentCameraIndex].deviceId
                  : '0');

          // Create constraints based on platform
          final Map<String, dynamic> videoConstraints = {
            'width': _selectedVideoSize.width,
            'height': _selectedVideoSize.height,
            'frameRate': double.parse(_selectedVideoFPS!),
          };

          // Add device ID constraints based on platform
          if (kIsWeb) {
            videoConstraints['deviceId'] = deviceId;
          } else {
            // For mobile, use sourceId in optional constraints
            videoConstraints['optional'] = [
              {'sourceId': deviceId}
            ];
          }

          _localStream = await navigator.mediaDevices.getUserMedia({
            'audio': false,
            'video': videoConstraints,
          });

          // Stop image stream as we now have WebRTC stream
          await _cameraController!.stopImageStream();

          _onLog('Created stream from camera with deviceId: $deviceId');
          onStateChange?.call();
          return _localStream!;
        } catch (e) {
          _onLog('Failed to get stream from camera: $e');
          // Stop image stream on error
          try {
            await _cameraController!.stopImageStream();
          } catch (_) {}
        }
      }

      // Fallback to default WebRTC getUserMedia
      _onLog('Falling back to default camera');
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'width': _selectedVideoSize.width,
          'height': _selectedVideoSize.height,
          'frameRate': double.parse(_selectedVideoFPS!),
        },
      });

      var videoTrack = _localStream!.getVideoTracks().first;
      _onLog('Created stream from getUserMedia: ${videoTrack.getSettings()}');
      onStateChange?.call();

      return _localStream!;
    } catch (e) {
      _onLog('Failed to create stream: $e');
      throw e;
    }
  }

  Future<void> updateStream() async {
    final oldStream = _localStream;

    try {
      // Create new stream first
      await createStream();

      // Only stop old stream after new one is created successfully
      if (oldStream != null) {
        oldStream.getTracks().forEach((track) => track.stop());
        await oldStream.dispose();
      }
    } catch (e) {
      _onLog('Error updating stream: $e');
      // Restore old stream if update fails
      _localStream = oldStream;
      throw e;
    }
  }

  Future<void> stopStream() async {
    try {
      // Stop camera preview if running
      if (_cameraController?.value.isStreamingImages ?? false) {
        await _cameraController!.stopImageStream();
      }

      // Stop WebRTC tracks
      if (_localStream != null) {
        _localStream!.getTracks().forEach((track) async {
          await track.stop();
        });
        _localStream = null;
      }

      onStateChange?.call();
    } catch (e) {
      _onLog('Error stopping stream: $e');
    }
  }

  // Camera Settings
  Future<void> selectVideoInput(String? deviceId) async {
    _selectedVideoInputId = deviceId;
    _isBackCamera = videoInputs.any(
      (device) =>
          device.deviceId == deviceId &&
          (device.label.toLowerCase().contains('back') ||
              device.label.toLowerCase().contains('rear')),
    );

    if (_localStream != null) {
      await updateStream();
    }
  }

  Future<void> selectVideoFps(String fps) async {
    _selectedVideoFPS = fps;
    if (_localStream != null) {
      await updateStream();
    }
  }

  Future<void> selectVideoSize(String size) async {
    _selectedVideoSize = VideoSize.fromString(size);
    if (_localStream != null) {
      await updateStream();
    }
  }

  // Media Capture
  Future<String> _getMediaPath(String type) async {
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return path.join(directory.path, 'shine_$type\_$timestamp');
  }

  Future<XFile> capturePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    final isHighQuality = _settings.isHighQualityEnabled;
    final XFile photo = await _cameraController!.takePicture();

    if (isHighQuality) {
      _lastCapturedMedia = photo;
      return photo;
    }

    // Compress if not high quality
    final File originalFile = File(photo.path);
    final img.Image? originalImage = img.decodeImage(
      await originalFile.readAsBytes(),
    );

    if (originalImage != null) {
      final img.Image compressedImage = img.copyResize(
        originalImage,
        width: originalImage.width ~/ 2,
        height: originalImage.height ~/ 2,
      );

      final String compressedPath = await _getMediaPath('photo') + '.jpg';
      final File compressedFile = File(compressedPath);
      await compressedFile.writeAsBytes(
        img.encodeJpg(compressedImage, quality: 80),
      );

      // Delete original if not needed
      if (!_settings.isSaveOriginalEnabled) {
        await originalFile.delete();
      }

      _lastCapturedMedia = XFile(compressedPath);
      return _lastCapturedMedia!;
    }

    _lastCapturedMedia = photo;
    return photo;
  }

  Future<void> startVideoRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      throw Exception('Camera not initialized');
    }

    if (_isRecording) return;

    try {
      await _cameraController!.startVideoRecording();
      _isRecording = true;
      onStateChange?.call();
    } catch (e) {
      _onLog('Error starting video recording: $e');
      throw e;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    if (!_isRecording || _cameraController == null) return null;

    try {
      final XFile video = await _cameraController!.stopVideoRecording();
      _isRecording = false;
      onStateChange?.call();

      // TODO: Implement video compression if needed
      if (!_settings.isHighQualityEnabled && !_settings.isSaveOriginalEnabled) {
        // For now, we'll just return the original video
        // This should be implemented based on your video compression requirements
      }

      _lastCapturedMedia = video;
      return video;
    } catch (e) {
      _onLog('Error stopping video recording: $e');
      _isRecording = false;
      onStateChange?.call();
      throw e;
    }
  }

  Future<void> deleteLastCapturedMedia() async {
    if (_lastCapturedMedia != null) {
      final file = File(_lastCapturedMedia!.path);
      if (await file.exists()) {
        await file.delete();
      }
      _lastCapturedMedia = null;
    }
  }

  Future<void> dispose() async {
    await stopStream();
    await _cameraController?.dispose();
    if (_isFlashlightOn) {
      await _toggleFlashlightInternal(false);
    }
    navigator.mediaDevices.ondevicechange = null;
  }
}
