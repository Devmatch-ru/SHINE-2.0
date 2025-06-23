import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_constant.dart';

class SettingsManager {
  // ИСПРАВЛЕНИЕ: Расширенные ключи настроек
  static const String _kHighQuality = 'high_quality';
  static const String _kSaveOriginal = 'save_original';
  static const String _kSendImmediately = 'send_immediately';
  static const String _kSendToAll = 'send_to_all';
  static const String _kAutoReconnect = 'auto_reconnect';
  static const String _kThermalProtection = 'thermal_protection';
  static const String _kAdaptiveQuality = 'adaptive_quality';
  static const String _kDefaultQuality = 'default_quality';
  static const String _kMaxRecordingDuration = 'max_recording_duration';
  static const String _kPhotoQuality = 'photo_quality';
  static const String _kAutoSaveToGallery = 'auto_save_to_gallery';
  static const String _kShowDebugInfo = 'show_debug_info';
  static const String _kUseHardwareAcceleration = 'use_hardware_acceleration';
  static const String _kConnectionTimeout = 'connection_timeout';
  static const String _kMaxConnections = 'max_connections';
  static const String _kCompressionLevel = 'compression_level';

  late final SharedPreferences _prefs;
  static SettingsManager? _instance;

  SettingsManager._();

  static Future<SettingsManager> getInstance() async {
    if (_instance == null) {
      _instance = SettingsManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _setDefaultsIfNeeded();
  }

  // ИСПРАВЛЕНИЕ: Устанавливаем значения по умолчанию
  Future<void> _setDefaultsIfNeeded() async {
    final defaults =  AppConstants.defaultSettings;

    for (final entry in defaults.entries) {
      final key = '_k${entry.key[0].toUpperCase()}${entry.key.substring(1)}';

      // Используем рефлексию для получения константы
      switch (entry.key) {
        case 'highQuality':
          if (!_prefs.containsKey(_kHighQuality)) {
            await _prefs.setBool(_kHighQuality, entry.value as bool);
          }
          break;
        case 'saveOriginal':
          if (!_prefs.containsKey(_kSaveOriginal)) {
            await _prefs.setBool(_kSaveOriginal, entry.value as bool);
          }
          break;
        case 'sendImmediately':
          if (!_prefs.containsKey(_kSendImmediately)) {
            await _prefs.setBool(_kSendImmediately, entry.value as bool);
          }
          break;
        case 'sendToAll':
          if (!_prefs.containsKey(_kSendToAll)) {
            await _prefs.setBool(_kSendToAll, entry.value as bool);
          }
          break;
        case 'autoReconnect':
          if (!_prefs.containsKey(_kAutoReconnect)) {
            await _prefs.setBool(_kAutoReconnect, entry.value as bool);
          }
          break;
        case 'thermalProtection':
          if (!_prefs.containsKey(_kThermalProtection)) {
            await _prefs.setBool(_kThermalProtection, entry.value as bool);
          }
          break;
        case 'adaptiveQuality':
          if (!_prefs.containsKey(_kAdaptiveQuality)) {
            await _prefs.setBool(_kAdaptiveQuality, entry.value as bool);
          }
          break;
      }
    }

    // ИСПРАВЛЕНИЕ: Устанавливаем дополнительные значения по умолчанию
    if (!_prefs.containsKey(_kDefaultQuality)) {
      await _prefs.setString(_kDefaultQuality, 'medium');
    }
    if (!_prefs.containsKey(_kMaxRecordingDuration)) {
      await _prefs.setInt(_kMaxRecordingDuration, AppConstants.maxRecordingDuration);
    }
    if (!_prefs.containsKey(_kPhotoQuality)) {
      await _prefs.setDouble(_kPhotoQuality, AppConstants.photoQuality);
    }
    if (!_prefs.containsKey(_kConnectionTimeout)) {
      await _prefs.setInt(_kConnectionTimeout, AppConstants.connectionTimeout.inSeconds);
    }
    if (!_prefs.containsKey(_kMaxConnections)) {
      await _prefs.setInt(_kMaxConnections, AppConstants.maxConnections);
    }
  }

  // ИСПРАВЛЕНИЕ: Основные настройки
  bool get isHighQualityEnabled => _prefs.getBool(_kHighQuality) ?? true;
  Future<void> setHighQuality(bool value) =>
      _prefs.setBool(_kHighQuality, value);

  bool get isSaveOriginalEnabled => _prefs.getBool(_kSaveOriginal) ?? true;
  Future<void> setSaveOriginal(bool value) =>
      _prefs.setBool(_kSaveOriginal, value);

  bool get isSendImmediatelyEnabled =>
      _prefs.getBool(_kSendImmediately) ?? true;
  Future<void> setSendImmediately(bool value) =>
      _prefs.setBool(_kSendImmediately, value);

  bool get isSendToAllEnabled => _prefs.getBool(_kSendToAll) ?? false;
  Future<void> setSendToAll(bool value) => _prefs.setBool(_kSendToAll, value);

  // ИСПРАВЛЕНИЕ: Расширенные настройки
  bool get isAutoReconnectEnabled => _prefs.getBool(_kAutoReconnect) ?? true;
  Future<void> setAutoReconnect(bool value) =>
      _prefs.setBool(_kAutoReconnect, value);

  bool get isThermalProtectionEnabled => _prefs.getBool(_kThermalProtection) ?? true;
  Future<void> setThermalProtection(bool value) =>
      _prefs.setBool(_kThermalProtection, value);

  bool get isAdaptiveQualityEnabled => _prefs.getBool(_kAdaptiveQuality) ?? true;
  Future<void> setAdaptiveQuality(bool value) =>
      _prefs.setBool(_kAdaptiveQuality, value);

  String get defaultQuality => _prefs.getString(_kDefaultQuality) ?? 'medium';
  Future<void> setDefaultQuality(String value) =>
      _prefs.setString(_kDefaultQuality, value);

  int get maxRecordingDuration => _prefs.getInt(_kMaxRecordingDuration) ?? AppConstants.maxRecordingDuration;
  Future<void> setMaxRecordingDuration(int seconds) =>
      _prefs.setInt(_kMaxRecordingDuration, seconds);

  double get photoQuality => _prefs.getDouble(_kPhotoQuality) ?? AppConstants.photoQuality;
  Future<void> setPhotoQuality(double value) =>
      _prefs.setDouble(_kPhotoQuality, value);

  bool get isAutoSaveToGalleryEnabled => _prefs.getBool(_kAutoSaveToGallery) ?? true;
  Future<void> setAutoSaveToGallery(bool value) =>
      _prefs.setBool(_kAutoSaveToGallery, value);

  bool get isShowDebugInfoEnabled => _prefs.getBool(_kShowDebugInfo) ?? false;
  Future<void> setShowDebugInfo(bool value) =>
      _prefs.setBool(_kShowDebugInfo, value);

  bool get isUseHardwareAccelerationEnabled => _prefs.getBool(_kUseHardwareAcceleration) ?? true;
  Future<void> setUseHardwareAcceleration(bool value) =>
      _prefs.setBool(_kUseHardwareAcceleration, value);

  int get connectionTimeoutSeconds => _prefs.getInt(_kConnectionTimeout) ?? AppConstants.connectionTimeout.inSeconds;
  Future<void> setConnectionTimeout(int seconds) =>
      _prefs.setInt(_kConnectionTimeout, seconds);

  int get maxConnections => _prefs.getInt(_kMaxConnections) ?? AppConstants.maxConnections;
  Future<void> setMaxConnections(int value) =>
      _prefs.setInt(_kMaxConnections, value);

  int get compressionLevel => _prefs.getInt(_kCompressionLevel) ?? 6;
  Future<void> setCompressionLevel(int value) =>
      _prefs.setInt(_kCompressionLevel, value);

  // ИСПРАВЛЕНИЕ: Методы для работы с качеством видео
  VideoQuality get defaultVideoQuality {
    final qualityString = defaultQuality;
    switch (qualityString) {
      case 'low':
        return VideoQuality.low;
      case 'medium':
        return VideoQuality.medium;
      case 'high':
        return VideoQuality.high;
      case 'power_save':
        return VideoQuality.powerSave;
      default:
        return VideoQuality.medium;
    }
  }

  Future<void> setDefaultVideoQuality(VideoQuality quality) =>
      setDefaultQuality(quality.value);

  VideoQualityConfig get defaultQualityConfig =>
      AppConstants.videoQualities[defaultQuality] ?? AppConstants.videoQualities['medium']!;

  // ИСПРАВЛЕНИЕ: Получение всех настроек для экспорта/импорта
  Map<String, dynamic> getAllSettings() {
    return {
      'highQuality': isHighQualityEnabled,
      'saveOriginal': isSaveOriginalEnabled,
      'sendImmediately': isSendImmediatelyEnabled,
      'sendToAll': isSendToAllEnabled,
      'autoReconnect': isAutoReconnectEnabled,
      'thermalProtection': isThermalProtectionEnabled,
      'adaptiveQuality': isAdaptiveQualityEnabled,
      'defaultQuality': defaultQuality,
      'maxRecordingDuration': maxRecordingDuration,
      'photoQuality': photoQuality,
      'autoSaveToGallery': isAutoSaveToGalleryEnabled,
      'showDebugInfo': isShowDebugInfoEnabled,
      'useHardwareAcceleration': isUseHardwareAccelerationEnabled,
      'connectionTimeout': connectionTimeoutSeconds,
      'maxConnections': maxConnections,
      'compressionLevel': compressionLevel,
    };
  }

  // ИСПРАВЛЕНИЕ: Импорт настроек
  Future<void> importSettings(Map<String, dynamic> settings) async {
    for (final entry in settings.entries) {
      switch (entry.key) {
        case 'highQuality':
          await setHighQuality(entry.value as bool);
          break;
        case 'saveOriginal':
          await setSaveOriginal(entry.value as bool);
          break;
        case 'sendImmediately':
          await setSendImmediately(entry.value as bool);
          break;
        case 'sendToAll':
          await setSendToAll(entry.value as bool);
          break;
        case 'autoReconnect':
          await setAutoReconnect(entry.value as bool);
          break;
        case 'thermalProtection':
          await setThermalProtection(entry.value as bool);
          break;
        case 'adaptiveQuality':
          await setAdaptiveQuality(entry.value as bool);
          break;
        case 'defaultQuality':
          await setDefaultQuality(entry.value as String);
          break;
        case 'maxRecordingDuration':
          await setMaxRecordingDuration(entry.value as int);
          break;
        case 'photoQuality':
          await setPhotoQuality(entry.value as double);
          break;
        case 'autoSaveToGallery':
          await setAutoSaveToGallery(entry.value as bool);
          break;
        case 'showDebugInfo':
          await setShowDebugInfo(entry.value as bool);
          break;
        case 'useHardwareAcceleration':
          await setUseHardwareAcceleration(entry.value as bool);
          break;
        case 'connectionTimeout':
          await setConnectionTimeout(entry.value as int);
          break;
        case 'maxConnections':
          await setMaxConnections(entry.value as int);
          break;
        case 'compressionLevel':
          await setCompressionLevel(entry.value as int);
          break;
      }
    }
  }

  // ИСПРАВЛЕНИЕ: Сброс к значениям по умолчанию
  Future<void> resetToDefaults() async {
    await _prefs.clear();
    await _setDefaultsIfNeeded();
  }

  // ИСПРАВЛЕНИЕ: Валидация настроек
  bool validateSettings() {
    if (maxRecordingDuration < 30 || maxRecordingDuration > 3600) return false;
    if (photoQuality < 0.1 || photoQuality > 1.0) return false;
    if (connectionTimeoutSeconds < 5 || connectionTimeoutSeconds > 60) return false;
    if (maxConnections < 1 || maxConnections > 20) return false;
    if (compressionLevel < 1 || compressionLevel > 9) return false;
    if (!['low', 'medium', 'high', 'power_save'].contains(defaultQuality)) return false;

    return true;
  }

  // ИСПРАВЛЕНИЕ: Получение оптимальных настроек для текущего устройства
  Future<Map<String, dynamic>> getOptimalSettings() async {
    // Здесь можно добавить логику определения характеристик устройства
    // и возврата оптимальных настроек
    return {
      'highQuality': true,
      'saveOriginal': true,
      'sendImmediately': true,
      'sendToAll': false,
      'autoReconnect': true,
      'thermalProtection': true,
      'adaptiveQuality': true,
      'defaultQuality': 'medium',
      'useHardwareAcceleration': true,
    };
  }
}