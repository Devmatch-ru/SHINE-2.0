class AppConstants {
  // Network constants
  static const int discoveryPort = 9000;
  static const int signalingPort = 8080;
  static const int maxConnections = 7;
  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiverTimeout = Duration(seconds: 30);
  static const Duration discoveryInterval = Duration(seconds: 5);
  static const Duration cleanupInterval = Duration(seconds: 10);
  static const Duration thermalCheckInterval = Duration(seconds: 30);

  // WebRTC constants
  static const int maxChunkSize = 16 * 1024;
  static const int maxRetries = 3;
  static const int chunkDelayMs = 50;
  static const int retryDelayBaseMs = 100;

  static const Map<String, VideoQualityConfig> videoQualities = {
    'low': VideoQualityConfig(
      width: 640,
      height: 360,
      frameRate: 24,
      bitrate: 800000,
    ),
    'medium': VideoQualityConfig(
      width: 1280,
      height: 720,
      frameRate: 30,
      bitrate: 1500000,
    ),
    'high': VideoQualityConfig(
      width: 1920,
      height: 1080,
      frameRate: 30,
      bitrate: 2000000,
    ),
  };

  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': [
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    }
  ];

  // Messages
  static const String discoveryMessage = 'DISCOVER';
  static const String receiverPrefix = 'RECEIVER:';

  // Commands
  static const String capturePhotoCommand = 'capture_photo';
  static const String toggleFlashCommand = 'toggle_flashlight';
  static const String startTimerCommand = 'start_timer';
  static const String toggleRecordingCommand = 'toggle_video';
  static const String changeQualityCommand = 'change_quality';
}

class VideoQualityConfig {
  final int width;
  final int height;
  final int frameRate;
  final int bitrate;

  const VideoQualityConfig({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrate,
  });

  Map<String, dynamic> toConstraints() {
    return {
      'video': {
        'facingMode': 'environment',
        'width': width,
        'height': height,
        'frameRate': frameRate,
        'aspectRatio': 16.0 / 9.0,
        'advanced': [
          {
            'width': {'min': width, 'ideal': width, 'max': width},
            'height': {'min': height, 'ideal': height, 'max': height},
            'frameRate': {'min': frameRate, 'ideal': frameRate, 'max': frameRate},
          },
          {
            'exposureMode': 'continuous',
            'focusMode': 'continuous',
            'whiteBalanceMode': 'continuous',
          }
        ]
      }
    };
  }
}