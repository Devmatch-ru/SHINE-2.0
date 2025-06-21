import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../utils/video_size.dart';
import './webrtc/media_devices_manager.dart';
import './webrtc/webrtc_connection.dart';
import './webrtc/discovery_manager.dart';
import './webrtc/signaling_server.dart';
import './webrtc/types.dart';
import './settings_manager.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';

class BroadcasterManager {
  final List<String> _messages = [];
  bool _inCalling = false;
  String? _currentReceiverUrl;
  final Map<RTCPeerConnection, RTCDataChannel> _dataChannels = {};

  late final MediaDevicesManager _mediaManager;
  late final WebRTCConnection _webrtc;
  late final DiscoveryManager _discovery;
  late final SignalingServer _signaling;
  late final SettingsManager _settings;
  Timer? _connectionTimer;
  CameraController? _cameraController;

  late final VoidCallback? onStateChange;
  final VoidCallback? onCapturePhoto;
  final void Function(String error)? onError;
  final void Function(XFile media)? onMediaCaptured;
  final void Function(MediaType type, String base64Data)? onMediaReceived;
  final void Function(String command)? onCommandReceived;
  final void Function(String quality)? onQualityChanged;
  final VoidCallback? onConnectionFailed;
  final void Function(String fileName, String mediaType, int sentChunks,
      int totalChunks, bool isCompleted)? onTransferProgress;

  bool _isPowerSaveMode = false;
  Timer? _thermalMonitor;
  DateTime _lastThermalCheck = DateTime.now();

  bool _isFlashOn = false;

  MediaRecorder? _mediaRecorder;
  String? _currentVideoPath;
  bool _isRecording = false;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isConnected = false;
  final ValueNotifier<List<String>> messagesNotifier = ValueNotifier([]);

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
    _mediaManager = MediaDevicesManager(
      onLog: _addMessage,
      onStateChange: onStateChange,
      onStreamUpdated: _handleStreamUpdated,
    );

    _webrtc = WebRTCConnection(
      onLog: _addMessage,
      onStateChange: onStateChange,
      onCapturePhoto: onCapturePhoto,
      onIceCandidate: _handleIceCandidate,
      onConnectionFailed: onConnectionFailed,
      onMediaReceived: _handleMediaReceived,
      onCommandReceived: onCommandReceived,
      onQualityChangeRequested: _handleQualityChange,
      onTransferProgress:
          (fileName, mediaType, sentChunks, totalChunks, isCompleted) {
        onTransferProgress?.call(
            fileName, mediaType, sentChunks, totalChunks, isCompleted);
      },
    );

    _discovery = DiscoveryManager(
      onLog: _addMessage,
      onStateChange: onStateChange,
    );

    _signaling = SignalingServer(
      onLog: _addMessage,
      onStateChange: onStateChange,
      onAnswer: (answer) => _webrtc.setRemoteDescription(answer),
      onCandidate: (candidate) => _webrtc.addIceCandidate(candidate),
      getOffer: () => _webrtc.offer,
      getCandidates: () => _webrtc.candidates,
    );

    _initializeSettings();
  }

  Future<void> _initializeSettings() async {
    _settings = await SettingsManager.getInstance();
  }

  MediaStream? get localStream => _mediaManager.localStream;
  bool get isBroadcasting => _inCalling;
  List<String> get messages => messagesNotifier.value;
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
    await _mediaManager.init();
    await _discovery.startDiscoveryListener();
    _startThermalMonitoring();
  }

  Future<void> toggleFlash() async {
    try {
      _addMessage('Flashlight toggle requested');

      if (_mediaManager.localStream == null) {
        _addMessage('No media stream available for flashlight');
        throw Exception('No media stream available');
      }

      final videoTracks = _mediaManager.localStream!.getVideoTracks();
      if (videoTracks.isEmpty) {
        _addMessage('No video tracks available');
        throw Exception('No video tracks available');
      }

      final videoTrack = videoTracks.first;

      final hasTorch = await videoTrack.hasTorch();
      _addMessage('Camera torch support: $hasTorch');

      if (!hasTorch) {
        _addMessage('Current camera does not support torch mode');
        onError?.call('Камера не поддерживает фонарик');
        return;
      }

      _isFlashOn = !_isFlashOn;

      await videoTrack.setTorch(_isFlashOn);
      _addMessage('Torch set to: $_isFlashOn');

      final status = _isFlashOn ? 'включен' : 'выключен';
      _addMessage('Flashlight $status successfully');

      onStateChange?.call();
    } catch (e) {
      _addMessage('Error toggling flash: $e');
      onError?.call('Ошибка при переключении вспышки: $e');
    }
  }

  Future<void> captureWithTimer() async {
    onStateChange?.call();
    await Future.delayed(Duration(seconds: 3));
    await capturePhoto();
  }

  Future<void> dispose() async {
    _addMessage('Disposing broadcaster manager...');

    try {
      await stopBroadcast();

      _thermalMonitor?.cancel();

      await Future.delayed(const Duration(milliseconds: 300));

      await _discovery.dispose();
      await _mediaManager.dispose();

      _connectionTimer?.cancel();
      _addMessage('Broadcaster manager disposed successfully');
    } catch (e) {
      _addMessage('Error during disposal: $e');
    }
  }

  Future<List<String>> discoverReceivers() async {
    return await _discovery.discoverReceivers();
  }

  Future<void> refreshReceivers() async {
    await _discovery.discoverReceivers();
    onStateChange?.call();
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
      if (receiverUrl.isEmpty) {
        throw Exception('Receiver URL is empty');
      }

      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP == null) {
        throw Exception('Wi-Fi IP not available');
      }

      _currentReceiverUrl = receiverUrl;

      final mediaConstraints = {
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

      int retryCount = 0;
      while (retryCount < 15) {
        try {
          await _mediaManager.createStream(mediaConstraints);
          if (_mediaManager.localStream != null) break;
          retryCount++;
        } catch (e) {
          _addMessage('Attempt ${retryCount + 1} to create stream failed: $e');
          if (retryCount >= 2) throw e;
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (_mediaManager.localStream == null) {
        throw Exception(
            'Failed to create media stream after multiple attempts');
      }

      retryCount = 0;
      while (retryCount < 15) {
        try {
          await _webrtc.createConnection(_mediaManager.localStream!);
          if (_webrtc.offer != null) break;
          retryCount++;
        } catch (e) {
          _addMessage(
              'Attempt ${retryCount + 1} to create WebRTC connection failed: $e');
          if (retryCount >= 2) throw e;
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (_webrtc.offer == null) {
        throw Exception('WebRTC offer is null after multiple attempts');
      }

      await _signaling.start();

      _inCalling = true;
      onStateChange?.call();

      bool hasResponse = false;
      _connectionTimer = Timer(Duration(seconds: 15), () {
        if (!hasResponse) {
          _addMessage('Connection timeout after 15 seconds');
          stopBroadcast();
        }
      });

      final uri = Uri.parse(receiverUrl);
      if (!uri.hasScheme || !uri.hasAuthority) {
        throw Exception('Invalid receiver URL format');
      }

      retryCount = 0;
      Exception? lastError;

      while (retryCount < 15) {
        try {
          _addMessage('Attempt ${retryCount + 1} to send offer to receiver');

          final response = await http
              .post(
            Uri.parse('$receiverUrl/offer'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'sdp': _webrtc.offer!.sdp,
              'type': _webrtc.offer!.type,
              'broadcasterUrl': 'http://$wifiIP:8080',
            }),
          )
              .timeout(Duration(seconds: 5));

          hasResponse = true;
          _connectionTimer?.cancel();

          if (response.statusCode == 200) {
            _addMessage('Offer sent successfully');
            return;
          } else {
            lastError = Exception(
                'Failed to send offer: ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          lastError = Exception('Error sending offer: $e');
        }

        retryCount++;
        if (retryCount < 15) {
          await Future.delayed(Duration(seconds: 1));
        }
      }

      throw lastError ??
          Exception('Failed to send offer after multiple attempts');
    } catch (e) {
      _addMessage('Error starting broadcast: $e');
      await stopBroadcast();
      onError?.call('Ошибка при запуске трансляции: $e');
      rethrow;
    }
  }

  Future<void> capturePhoto() async {
    try {
      _addMessage('Starting photo capture process...');

      if (_mediaManager.localStream != null) {
        _addMessage('Media stream available, getting video track...');
        final videoTracks = _mediaManager.localStream!.getVideoTracks();
        _addMessage('Found ${videoTracks.length} video tracks');

        if (videoTracks.isEmpty) {
          throw Exception('No video tracks in stream');
        }

        final videoTrack = videoTracks.first;
        _addMessage(
            'Video track found: ${videoTrack.id}, enabled: ${videoTrack.enabled}');

        _addMessage('Capturing frame from video track...');
        final frame = await videoTrack.captureFrame();
        _addMessage('Frame captured successfully');

        final directory = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'photo_$timestamp.jpg';
        final filePath = '${directory.path}/$fileName';

        final file = File(filePath);
        final bytes = frame.asUint8List();
        _addMessage('Converting frame to bytes: ${bytes.length} bytes');
        await file.writeAsBytes(bytes);
        _addMessage('Photo saved to: $filePath');

        await GallerySaver.saveImage(
          filePath,
          albumName: 'Shine',
        );
        _addMessage('Photo saved to gallery');

        final xFile = XFile(filePath);
        onMediaCaptured?.call(xFile);

        _addMessage('Sending photo to receiver...');
        await _sendMediaToReceiver(MediaType.photo, xFile);
      } else {
        throw Exception('No video stream available');
      }
    } catch (e) {
      _addMessage('Error capturing photo: $e');
      onError?.call('Ошибка при съемке фото: $e');
    }
  }

  Future<void> startVideoRecording() async {
    try {
      _addMessage('Starting video recording from WebRTC stream...');

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
      _addMessage('Video recording started: $_currentVideoPath');
      onStateChange?.call();
    } catch (e) {
      _addMessage('Error starting video recording: $e');
      onError?.call('Ошибка при начале записи видео: $e');
    }
  }

  Future<void> stopVideoRecording() async {
    try {
      _addMessage('Stopping video recording...');

      if (_mediaRecorder == null || !_isRecording) {
        _addMessage('No active recording to stop');
        return;
      }

      await _mediaRecorder!.stop();
      _mediaRecorder = null;
      _isRecording = false;

      if (_currentVideoPath != null) {
        await GallerySaver.saveVideo(
          _currentVideoPath!,
          albumName: 'Shine',
        );
        _addMessage('Video saved to gallery');

        final xFile = XFile(_currentVideoPath!);
        _addMessage('Video recorded: $_currentVideoPath');
        onMediaCaptured?.call(xFile);

        await _sendMediaToReceiver(MediaType.video, xFile);

        _currentVideoPath = null;
      }

      onStateChange?.call();
    } catch (e) {
      _addMessage('Error stopping video recording: $e');
      onError?.call('Ошибка при остановке записи видео: $e');
    }
  }

  Future<void> _sendMediaToReceiver(MediaType type, XFile media) async {
    try {
      _addMessage('Sending ${type.name} to receiver...');

      final success = await _webrtc.sendMedia(type, media);

      if (success) {
        _addMessage('${type.name} sent successfully');
      } else {
        _addMessage('Failed to send ${type.name}');
      }
    } catch (e) {
      _addMessage('Error sending media: $e');
    }
  }

  Future<void> _handleIceCandidate(RTCIceCandidate candidate) async {
    try {
      final response = await http.post(
        Uri.parse('${_currentReceiverUrl}/candidate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'candidate': candidate.toMap()}),
      );
      if (response.statusCode == 200) {
        _addMessage('ICE candidate sent successfully');
      } else {
        _addMessage('Failed to send ICE candidate: ${response.statusCode}');
      }
    } catch (e) {
      _addMessage('Error sending ICE candidate: $e');
    }
  }

  void _handleMediaReceived(MediaType type, String base64Data) {
    onMediaReceived?.call(type, base64Data);
  }

  void _handleQualityChange(String quality) async {
    try {
      _addMessage('Changing stream quality to: $quality');

      Map<String, dynamic> constraints;
      int targetBitrate;

      switch (quality) {
        case 'low':
          constraints = {
            'video': {
              'facingMode': 'environment',
              'width': 640,
              'height': 360,
              'frameRate': 24,
              'aspectRatio': 16.0 / 9.0,
              'advanced': [
                {
                  'width': {'min': 640, 'ideal': 640, 'max': 640},
                  'height': {'min': 360, 'ideal': 360, 'max': 360},
                  'frameRate': {'min': 24, 'ideal': 24, 'max': 24},
                },
                {
                  'exposureMode': 'continuous',
                  'focusMode': 'continuous',
                  'whiteBalanceMode': 'continuous',
                }
              ]
            }
          };
          targetBitrate = 800000; // 800 Kbps
          break;
        case 'medium':
          constraints = {
            'video': {
              'facingMode': 'environment',
              'width': 1280,
              'height': 720,
              'frameRate': 30,
              'aspectRatio': 16.0 / 9.0,
              'advanced': [
                {
                  'width': {'min': 1280, 'ideal': 1280, 'max': 1280},
                  'height': {'min': 720, 'ideal': 720, 'max': 720},
                  'frameRate': {'min': 30, 'ideal': 30, 'max': 30},
                },
                {
                  'exposureMode': 'continuous',
                  'focusMode': 'continuous',
                  'whiteBalanceMode': 'continuous',
                }
              ]
            }
          };
          targetBitrate = 1500000; // 1.5 Mbps
          break;
        case 'high':
          constraints = {
            'video': {
              'facingMode': 'environment',
              'width': 1920,
              'height': 1080,
              'frameRate': 30,
              'aspectRatio': 16.0 / 9.0,
              'advanced': [
                {
                  'width': {'min': 1920, 'ideal': 1920, 'max': 1920},
                  'height': {'min': 1080, 'ideal': 1080, 'max': 1080},
                  'frameRate': {'min': 30, 'ideal': 30, 'max': 30},
                },
                {
                  'exposureMode': 'continuous',
                  'focusMode': 'continuous',
                  'whiteBalanceMode': 'continuous',
                }
              ]
            }
          };
          targetBitrate = 2000000; // 2 Mbps
          break;
        default:
          constraints = {
            'video': {
              'facingMode': 'environment',
              'width': 1280,
              'height': 720,
              'frameRate': 30,
              'aspectRatio': 16.0 / 9.0,
              'advanced': [
                {
                  'width': {'min': 1280, 'ideal': 1280, 'max': 1280},
                  'height': {'min': 720, 'ideal': 720, 'max': 720},
                  'frameRate': {'min': 30, 'ideal': 30, 'max': 30},
                },
                {
                  'exposureMode': 'continuous',
                  'focusMode': 'continuous',
                  'whiteBalanceMode': 'continuous',
                }
              ]
            }
          };
          targetBitrate = 1500000; // 1.5 Mbps
      }

      //ограничения к существующему потоку
      await _mediaManager.updateStreamWithConstraints(constraints);

      if (_mediaManager.localStream != null) {
        await _webrtc.updateStream(_mediaManager.localStream!);

        final senders = 'await _webrtc.getSenders()';

      }

      _addMessage(
          'Stream quality changed successfully to: $quality with bitrate ${targetBitrate ~/ 1000}kbps');
      onQualityChanged?.call(quality);
      onStateChange?.call();
    } catch (e) {
      _addMessage('Error changing quality: $e');
      onError?.call('Ошибка при изменении качества: $e');
    }
  }

  Future<void> stopBroadcast() async {
    if (!_inCalling) return;

    try {
      _addMessage('Stopping broadcast...');
      _inCalling = false;

      await _webrtc.close();

      await _signaling.stop();

      _dataChannels.clear();

      _currentReceiverUrl = null;
      onStateChange?.call();

      _addMessage('Broadcast stopped successfully');
    } catch (e) {
      _addMessage('Error stopping broadcast: $e');
      onError?.call('Ошибка при остановке трансляции: $e');
    }
  }

  void _addMessage(String message) {
    messagesNotifier.value = [...messagesNotifier.value, message];
  }

  void _handleStreamUpdated(MediaStream stream) async {
    try {
      _addMessage('Stream updated, updating WebRTC connection...');

      await _webrtc.updateStream(stream);

      _addMessage('WebRTC connection updated with new stream');
      onStateChange?.call();
    } catch (e) {
      _addMessage('Error updating WebRTC stream: $e');
      onError?.call('Ошибка при обновлении потока: $e');
    }
  }

  void _startThermalMonitoring() {
    _thermalMonitor = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkThermalStateAndOptimize();
    });
  }

  void _checkThermalStateAndOptimize() {
    final now = DateTime.now();
    final timeSinceLastCheck = now.difference(_lastThermalCheck);

    if (timeSinceLastCheck.inMinutes > 3 && _inCalling && !_isPowerSaveMode) {
      _addMessage('Enabling power save mode to prevent overheating');
      _enablePowerSaveMode();
    }

    _lastThermalCheck = now;
  }

  void _enablePowerSaveMode() async {
    if (_isPowerSaveMode) return;

    try {
      _isPowerSaveMode = true;
      _addMessage('Power save mode enabled');

      _handleQualityChange('medium');

      onQualityChanged?.call('power_save');
      onStateChange?.call();
    } catch (e) {
      _addMessage('Error enabling power save mode: $e');
    }
  }
}
