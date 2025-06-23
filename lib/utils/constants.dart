class AppConstants {
  // Network constants - увеличены таймауты для стабильности
  static const int discoveryPort = 9000;
  static const int signalingPort = 8080;
  static const int maxConnections = 7;
  static const Duration connectionTimeout = Duration(seconds: 30); // Увеличено с 15 до 30
  static const Duration receiverTimeout = Duration(seconds: 45); // Увеличено с 30 до 45
  static const Duration discoveryInterval = Duration(seconds: 8); // Увеличено с 5 до 8
  static const Duration cleanupInterval = Duration(seconds: 15); // Увеличено с 10 до 15
  static const Duration thermalCheckInterval = Duration(seconds: 45); // Увеличено с 30 до 45

  // WebRTC constants - оптимизированы для стабильности
  static const int maxChunkSize = 8 * 1024; // Уменьшено с 16KB до 8KB
  static const int maxRetries = 5; // Увеличено с 3 до 5
  static const int chunkDelayMs = 100; // Увеличено с 50 до 100
  static const int retryDelayBaseMs = 200; // Увеличено с 100 до 200

  // Улучшенные настройки качества видео
  static const Map<String, VideoQualityConfig> videoQualities = {
    'low': VideoQualityConfig(
      width: 640,
      height: 360,
      frameRate: 24, // Уменьшено с 24 для стабильности
      bitrate: 600000, // Уменьшено с 800000
    ),
    'medium': VideoQualityConfig(
      width: 1280,
      height: 720,
      frameRate: 30,
      bitrate: 1200000, // Уменьшено с 1500000
    ),
    'high': VideoQualityConfig(
      width: 1920,
      height: 1080,
      frameRate: 30,
      bitrate: 1800000, // Уменьшено с 2000000
    ),
    'power_save': VideoQualityConfig(
      width: 480,
      height: 270,
      frameRate: 20,
      bitrate: 400000,
    ),
  };

  // Улучшенные STUN серверы для лучшей связности
  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': [
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
        'stun:stun3.l.google.com:19302',
        'stun:stun4.l.google.com:19302',
      ],
    },
    {
      'urls': [
        'stun:stun.services.mozilla.com:3478',
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

  // Connection stability constants
  static const Duration dataChannelTimeout = Duration(seconds: 10);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const int maxReconnectAttempts = 3;
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const Duration commandQueueProcessingInterval = Duration(milliseconds: 100);
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
            'width': {'min': width ~/ 2, 'ideal': width, 'max': width + 100},
            'height': {'min': height ~/ 2, 'ideal': height, 'max': height + 100},
            'frameRate': {'min': frameRate - 5, 'ideal': frameRate, 'max': frameRate + 5},
          },
          {
            'exposureMode': 'continuous',
            'focusMode': 'continuous',
            'whiteBalanceMode': 'continuous',
          },
          // Дополнительные настройки для стабильности
          {
            'echoCancellation': false,
            'noiseSuppression': false,
            'autoGainControl': false,
          }
        ]
      }
    };
  }

  // Метод для создания более мягких ограничений при проблемах с соединением
  Map<String, dynamic> toFlexibleConstraints() {
    return {
      'video': {
        'facingMode': 'environment',
        'width': {'min': 480, 'ideal': width, 'max': 1920},
        'height': {'min': 270, 'ideal': height, 'max': 1080},
        'frameRate': {'min': 15, 'ideal': frameRate, 'max': 30},
        'aspectRatio': 16.0 / 9.0,
      }
    };
  }
}