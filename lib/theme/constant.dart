export 'colors.dart';
export 'text_styles.dart';
export 'dimensions.dart';
export 'animations.dart';
export 'icons.dart';
export 'theme.dart';

// Сохраняем обратную совместимость
import 'colors.dart';
import 'colors.dart' as colors;
import 'text_styles.dart' as text_styles;
import 'dimensions.dart' as dimensions;
import 'icons.dart' as icons;

// Переэкспортируем классы для обратной совместимости
class AppColors extends colors.AppColors {}
class AppTextStyles extends text_styles.AppTextStyles {}
class AppSpacing extends dimensions.AppSpacing {}
class IconSize extends dimensions.IconSize {}
class AppBorderRadius extends dimensions.AppBorderRadius {}
class AppIcons extends icons.AppIcons {}

// Строки приложения
class AppStrings {
  static const String termsOfService = '''
  Данное пользовательское соглашение (далее — Соглашение) регулирует отношения между Evgenii Serdiuk, далее — Разработчик, и пользователем мобильного приложения Shine Remote Camera, далее — Пользователь.Используя приложение Shine Remote Camera, Пользователь соглашается с условиями данного Соглашения. Если Пользователь не согласен с условиями Соглашения, ему следует прекратить использование приложения.
  
  1. Описание сервиса
  Приложение Shine Remote Camera предоставляет возможность подключаться к другим устройствам для удалённой съёмки.
  
  2. Права и обязанности сторон
  2.1. Разработчик обязуется обеспечить работоспособность приложения в соответствии с его функциональными возможностями.
  2.2. Пользователь обязуется использовать приложение только в законных целях, не нарушая права и свободы третьих лиц.
  2.3. Разработчик также обязуется выпускать необходимые обновления приложения для обеспечения его работоспособности на обновленных версиях операционных систем Android и iOS, а также для внедрения нового функционала.
  
  3. Интеллектуальная собственность
  Все права на приложение, включая программный код, дизайн, тексты, графика и другие элементы, принадлежат Разработчику. Не допускается копирование, распространение или модификация приложения без письменного разрешения Разработчика.
  
  4. Ответственность
  Разработчик не несет ответственности за любой прямой или косвенный ущерб, понесенный Пользователем или третьими лицами в результате использования или невозможности использования приложения.
  
  5. Конфиденциальность
  Разработчик обязуется не раскрывать личную информацию Пользователя, полученную в ходе использования приложения, без согласия Пользователя, за исключением случаев, предусмотренных законом.
  
  6. Изменения в Соглашении
  Разработчик оставляет за собой право вносить изменения в Соглашение в любое время без предварительного уведомления Пользователя. Новая версия Соглашения вступает в силу с момента ее опубликования в приложении или на официальном сайте Разработчика.
  
  7. Заключительные положения
  7.1. Настоящее Соглашение является юридически обязывающим документом между Пользователем и Разработчиком и регулирует условия использования приложения.
  7.2. Все споры и разногласия, возникающие в связи с исполнением настоящего Соглашения, решаются путем переговоров. В случае невозможности достижения согласия споры подлежат рассмотрению в порядке, установленном законодательством страны Разработчика.
  
  8. Обратная связь
  В случае возникновения вопросов, предложений или необходимости технической поддержки, Пользователи могут обращаться в службу поддержки приложения Shine Remote Camera по электронной почте: helpmewhynot69@gmail.com. Команда поддержки приложения обязуется предоставлять оперативную помощь и консультации по всем интересующим вопросам, связанным с использованием приложения.''';
}

// Константы приложения
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

  // Улучшенные конфигурации качества видео
  static const Map<String, VideoQualityConfig> videoQualities = {
    'low': VideoQualityConfig(
      width: 640,
      height: 360,
      frameRate: 24,
      bitrate: 800000,
      name: 'Низкое',
      description: '640x360, 24fps, 800kbps',
    ),
    'medium': VideoQualityConfig(
      width: 1280,
      height: 720,
      frameRate: 30,
      bitrate: 1500000,
      name: 'Среднее',
      description: '1280x720, 30fps, 1.5Mbps',
    ),
    'high': VideoQualityConfig(
      width: 1920,
      height: 1080,
      frameRate: 30,
      bitrate: 2000000,
      name: 'Высокое',
      description: '1920x1080, 30fps, 2Mbps',
    ),
    'power_save': VideoQualityConfig(
      width: 854,
      height: 480,
      frameRate: 20,
      bitrate: 600000,
      name: 'Энергосбережение',
      description: '854x480, 20fps, 600kbps',
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
  static const String startRecordingCommand = 'start_recording';
  static const String stopRecordingCommand = 'stop_recording';
  static const String switchCameraCommand = 'switch_camera';
  static const String adjustFocusCommand = 'adjust_focus';

  // Настройки по умолчанию
  static const Map<String, dynamic> defaultSettings = {
    'highQuality': true,
    'saveOriginal': true,
    'sendImmediately': true,
    'sendToAll': false,
    'autoReconnect': true,
    'thermalProtection': true,
    'adaptiveQuality': true,
  };

  // Таймауты для различных операций
  static const Duration commandTimeout = Duration(seconds: 5);
  static const Duration mediaTransferTimeout = Duration(seconds: 30);
  static const Duration reconnectDelay = Duration(seconds: 3);
  static const Duration healthCheckInterval = Duration(seconds: 10);

  // Лимиты для медиа
  static const int maxPhotoSize = 10 * 1024 * 1024; // 10MB
  static const int maxVideoSize = 100 * 1024 * 1024; // 100MB
  static const int maxRecordingDuration = 600; // 10 минут в секундах

  // Качество изображений
  static const double photoQuality = 0.95;
  static const double thumbnailQuality = 0.7;
  static const int thumbnailSize = 200;

  // Статусы соединения
  static const String connectionStatusDisconnected = 'disconnected';
  static const String connectionStatusConnecting = 'connecting';
  static const String connectionStatusConnected = 'connected';
  static const String connectionStatusReconnecting = 'reconnecting';
  static const String connectionStatusError = 'error';

  // Типы уведомлений
  static const String notificationTypeCommand = 'command';
  static const String notificationTypeQuality = 'quality';
  static const String notificationTypeMedia = 'media';
  static const String notificationTypeConnection = 'connection';
  static const String notificationTypeError = 'error';
}

// Конфигурация качества видео
class VideoQualityConfig {
  final int width;
  final int height;
  final int frameRate;
  final int bitrate;
  final String name;
  final String description;

  const VideoQualityConfig({
    required this.width,
    required this.height,
    required this.frameRate,
    required this.bitrate,
    required this.name,
    required this.description,
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

  bool get isHighDefinition => width >= 1920;
  bool get isLowBandwidth => bitrate <= 800000;

  String get bitrateString => '${(bitrate / 1000).round()}kbps';
  String get resolutionString => '${width}x$height';
  String get fullDescription => '$name ($resolutionString, ${frameRate}fps, $bitrateString)';

  VideoQualityConfig copyWith({
    int? width,
    int? height,
    int? frameRate,
    int? bitrate,
    String? name,
    String? description,
  }) {
    return VideoQualityConfig(
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      bitrate: bitrate ?? this.bitrate,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  String toString() => fullDescription;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoQualityConfig &&
        other.width == width &&
        other.height == height &&
        other.frameRate == frameRate &&
        other.bitrate == bitrate;
  }

  @override
  int get hashCode {
    return width.hashCode ^
    height.hashCode ^
    frameRate.hashCode ^
    bitrate.hashCode;
  }
}

// Enum для команд
enum BroadcasterCommand {
  capturePhoto,
  toggleFlash,
  startTimer,
  toggleRecording,
  startRecording,
  stopRecording,
  changeQuality,
  switchCamera,
  adjustFocus,
}

extension BroadcasterCommandExtension on BroadcasterCommand {
  String get value {
    switch (this) {
      case BroadcasterCommand.capturePhoto:
        return AppConstants.capturePhotoCommand;
      case BroadcasterCommand.toggleFlash:
        return AppConstants.toggleFlashCommand;
      case BroadcasterCommand.startTimer:
        return AppConstants.startTimerCommand;
      case BroadcasterCommand.toggleRecording:
        return AppConstants.toggleRecordingCommand;
      case BroadcasterCommand.startRecording:
        return AppConstants.startRecordingCommand;
      case BroadcasterCommand.stopRecording:
        return AppConstants.stopRecordingCommand;
      case BroadcasterCommand.changeQuality:
        return AppConstants.changeQualityCommand;
      case BroadcasterCommand.switchCamera:
        return AppConstants.switchCameraCommand;
      case BroadcasterCommand.adjustFocus:
        return AppConstants.adjustFocusCommand;
    }
  }

  String get displayName {
    switch (this) {
      case BroadcasterCommand.capturePhoto:
        return 'Сделать фото';
      case BroadcasterCommand.toggleFlash:
        return 'Переключить фонарик';
      case BroadcasterCommand.startTimer:
        return 'Запустить таймер';
      case BroadcasterCommand.toggleRecording:
        return 'Переключить запись';
      case BroadcasterCommand.startRecording:
        return 'Начать запись';
      case BroadcasterCommand.stopRecording:
        return 'Остановить запись';
      case BroadcasterCommand.changeQuality:
        return 'Изменить качество';
      case BroadcasterCommand.switchCamera:
        return 'Переключить камеру';
      case BroadcasterCommand.adjustFocus:
        return 'Настроить фокус';
    }
  }
}

// Enum для качества видео
enum VideoQuality {
  low,
  medium,
  high,
  powerSave,
}

extension VideoQualityExtension on VideoQuality {
  String get value {
    switch (this) {
      case VideoQuality.low:
        return 'low';
      case VideoQuality.medium:
        return 'medium';
      case VideoQuality.high:
        return 'high';
      case VideoQuality.powerSave:
        return 'power_save';
    }
  }

  VideoQualityConfig get config {
    return AppConstants.videoQualities[value]!;
  }

  String get displayName {
    return config.name;
  }

  String get description {
    return config.description;
  }
}