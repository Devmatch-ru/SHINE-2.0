import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import '../utils/video_size.dart';
import './webrtc/media_devices_manager.dart';
import './webrtc/webrtc_connection.dart';
import './webrtc/discovery_manager.dart';
import './webrtc/types.dart';
import './settings_manager.dart';
import 'package:camera/camera.dart';

class BroadcasterManager {
  final List<String> _messages = [];
  bool _inCalling = false;
  String? _currentReceiverId;
  WebRTCConnection? _webrtc;
  Timer? _connectionTimer;

  late final MediaDevicesManager _mediaManager;
  late final DiscoveryManager _discovery;
  late final SettingsManager _settings;

  // Callbacks
  VoidCallback? onStateChange;
  VoidCallback? onCapturePhoto;
  void Function(String error)? onError;
  void Function(XFile media)? onMediaCaptured;

  BroadcasterManager._({
    this.onStateChange,
    this.onCapturePhoto,
    this.onError,
    this.onMediaCaptured,
    required SettingsManager settings,
  }) : _settings = settings {
    _mediaManager = MediaDevicesManager(
      settings: _settings,
      onLog: _addMessage,
      onStateChange: onStateChange,
    );

    _discovery = DiscoveryManager(
      onLog: _addMessage,
      onStateChange: onStateChange,
    );
  }

  static Future<BroadcasterManager> create({
    VoidCallback? onStateChange,
    VoidCallback? onCapturePhoto,
    void Function(String error)? onError,
    void Function(XFile media)? onMediaCaptured,
  }) async {
    final settings = await SettingsManager.getInstance();
    return BroadcasterManager._(
      onStateChange: onStateChange,
      onCapturePhoto: onCapturePhoto,
      onError: onError,
      onMediaCaptured: onMediaCaptured,
      settings: settings,
    );
  }

  // Getters
  MediaStream? get localStream => _mediaManager.localStream;
  bool get isBroadcasting => _inCalling;
  List<String> get messages => _messages;
  List<MediaDeviceInfo> get videoInputs => _mediaManager.videoInputs;
  String? get selectedVideoFPS => _mediaManager.selectedVideoFPS;
  VideoSize get selectedVideoSize => _mediaManager.selectedVideoSize;
  bool get isRecording => _mediaManager.isRecording;
  bool get isFlashlightOn => _mediaManager.isFlashlightOn;
  CameraController? get cameraController => _mediaManager.cameraController;
  Set<String> get availableReceivers => _discovery.receivers;

  Future<void> init() async {
    await _mediaManager.init();
    await _discovery.startDiscoveryListener();
    // Create initial stream
    await _mediaManager.createStream();
  }

  Future<void> dispose() async {
    await stopBroadcast();
    await _discovery.dispose();
    await _mediaManager.stopStream();
    _connectionTimer?.cancel();
  }

  Future<List<String>> discoverReceivers() async {
    return await _discovery.discoverReceivers();
  }

  Future<void> selectVideoInput(String? deviceId) async {
    await _mediaManager.selectVideoInput(deviceId);
  }

  Future<void> selectVideoFps(String fps) async {
    await _mediaManager.selectVideoFps(fps);
  }

  Future<void> selectVideoSize(String size) async {
    await _mediaManager.selectVideoSize(size);
  }

  Future<void> startBroadcast(String receiverUrl) async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP == null) {
        _addMessage('Wi-Fi IP not available');
        return;
      }

      _currentReceiverId = receiverUrl;

      // Check camera state
      if (_mediaManager.cameraController == null ||
          !_mediaManager.cameraController!.value.isInitialized) {
        _addMessage('Reinitializing camera');
        await _mediaManager.init();
      }

      // Ensure we have a media stream
      if (_mediaManager.localStream == null) {
        _addMessage('Creating media stream');
        await _mediaManager.createStream();
      }

      if (_mediaManager.localStream == null) {
        throw Exception('Failed to create media stream');
      }

      // Create WebRTC connection
      _webrtc = WebRTCConnection(
        onLog: _addMessage,
        onStateChange: () {
          onStateChange?.call();
          _checkConnectionState();
        },
        onMediaReceived: (type, data) {
          // Handle received media commands
          if (type == MediaType.photo) {
            capturePhoto();
          } else if (type == MediaType.video) {
            toggleVideoRecording();
          }
        },
        onConnectionFailed: () {
          _addMessage('Connection failed, stopping broadcast');
          stopBroadcast();
        },
      );

      // Add tracks to connection
      await _webrtc!
          .createConnection(_mediaManager.localStream!, isBroadcaster: true);

      // Connect to receiver
      final response = await http.post(
        Uri.parse('$receiverUrl/connect'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'broadcasterId': wifiIP,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to connect to receiver: ${response.statusCode}');
      }

      // Send offer
      final offerResponse = await http.post(
        Uri.parse('$receiverUrl/offer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'broadcasterId': wifiIP,
          'sdp': _webrtc!.offer!.sdp,
          'type': _webrtc!.offer!.type,
        }),
      );

      if (offerResponse.statusCode == 200) {
        final answer = RTCSessionDescription(
          jsonDecode(offerResponse.body)['sdp'],
          jsonDecode(offerResponse.body)['type'],
        );
        await _webrtc!.setRemoteDescription(answer);
      } else {
        throw Exception('Failed to send offer: ${offerResponse.statusCode}');
      }

      _inCalling = true;
      onStateChange?.call();

      // Start connection check timer
      _connectionTimer?.cancel();
      _connectionTimer = Timer.periodic(Duration(seconds: 5), (timer) {
        _checkConnectionState();
      });
    } catch (e) {
      _addMessage('Start error: $e');
      await stopBroadcast();
    }
  }

  void _checkConnectionState() {
    if (_webrtc != null && !_webrtc!.isConnected) {
      _addMessage('Connection lost, stopping broadcast');
      stopBroadcast();
    }
  }

  Future<void> stopBroadcast() async {
    if (_currentReceiverId != null) {
      try {
        await http.post(
          Uri.parse('${_currentReceiverId}/disconnect'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'broadcasterId': await NetworkInfo().getWifiIP(),
          }),
        );
      } catch (e) {
        _addMessage('Error disconnecting: $e');
      }
    }

    _inCalling = false;
    await _webrtc?.close();
    _webrtc = null;
    _connectionTimer?.cancel();
    _connectionTimer = null;
    onStateChange?.call();
  }

  Future<void> capturePhoto() async {
    if (!_inCalling) return;

    try {
      final photo = await _mediaManager.capturePhoto();
      if (photo != null) {
        await _webrtc?.sendMedia(MediaType.photo, photo);
        onMediaCaptured?.call(photo);
      }
    } catch (e) {
      _addMessage('Error capturing photo: $e');
    }
  }

  Future<void> toggleVideoRecording() async {
    if (!_inCalling) return;

    try {
      if (_mediaManager.isRecording) {
        final video = await _mediaManager.stopVideoRecording();
        if (video != null) {
          await _webrtc?.sendMedia(MediaType.video, video);
          onMediaCaptured?.call(video);
        }
      } else {
        await _mediaManager.startVideoRecording();
      }
      onStateChange?.call();
    } catch (e) {
      _addMessage('Error toggling video recording: $e');
    }
  }

  void _addMessage(String message) {
    _messages.add(message);
  }
}
