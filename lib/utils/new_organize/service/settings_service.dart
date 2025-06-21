// lib/services/settings_service.dart (Enhanced)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './logging_service.dart';
import './error_handling_service.dart';

enum SettingKey {
  // Quality settings
  highQuality('high_quality'),
  saveOriginal('save_original'),
  sendImmediately('send_immediately'),
  sendToAll('send_to_all'),

  // Video settings
  defaultVideoQuality('default_video_quality'),
  defaultVideoFPS('default_video_fps'),
  defaultVideoSize('default_video_size'),
  autoAdjustQuality('auto_adjust_quality'),

  // Network settings
  connectionTimeout('connection_timeout'),
  maxRetries('max_retries'),
  discoveryInterval('discovery_interval'),

  // UI settings
  showDebugInfo('show_debug_info'),
  enableHapticFeedback('enable_haptic_feedback'),
  darkMode('dark_mode'),

  // Permission settings
  autoRequestPermissions('auto_request_permissions'),

  // Advanced settings
  enableLowPowerMode('enable_low_power_mode'),
  thermalManagement('thermal_management'),
  enableLogging('enable_logging'),
  logLevel('log_level'),

  // First-time setup
  firstLaunch('first_launch'),
  onboardingCompleted('onboarding_completed'),
  tipScreensShown('tip_screens_shown');

  const SettingKey(this.key);
  final String key;
}

class SettingDefinition<T> {
  final SettingKey key;
  final T defaultValue;
  final String displayName;
  final String? description;
  final List<T>? allowedValues;
  final T? Function(dynamic)? parser;
  final bool isAdvanced;

  const SettingDefinition({
    required this.key,
    required this.defaultValue,
    required this.displayName,
    this.description,
    this.allowedValues,
    this.parser,
    this.isAdvanced = false,
  });
}

class SettingsService with LoggerMixin, ErrorHandlerMixin {
  @override
  String get loggerContext => 'SettingsService';

  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;
  final StreamController<SettingKey> _settingsChangeController =
  StreamController<SettingKey>.broadcast();

  Stream<SettingKey> get settingsChangeStream => _settingsChangeController.stream;

  // Settings definitions
  static const Map<SettingKey, SettingDefinition> _definitions = {
    // Quality settings
    SettingKey.highQuality: SettingDefinition<bool>(
      key: SettingKey.highQuality,
      defaultValue: true,
      displayName: 'Высокое качество трансляции',
      description: 'Использовать максимальное качество видео при стабильном соединении',
    ),

    SettingKey.saveOriginal: SettingDefinition<bool>(
      key: SettingKey.saveOriginal,
      defaultValue: true,
      displayName: 'Сохранять оригинал',
      description: 'Сохранять фото и видео на снимающем устройстве',
    ),

    SettingKey.sendImmediately: SettingDefinition<bool>(
      key: SettingKey.sendImmediately,
      defaultValue: true,
      displayName: 'Отправлять сразу',
      description: 'Отправлять медиафайлы сразу после создания',
    ),

    SettingKey.sendToAll: SettingDefinition<bool>(
      key: SettingKey.sendToAll,
      defaultValue: false,
      displayName: 'Отправлять всем',
      description: 'Отправлять команды и медиа всем подключенным устройствам',
    ),

    // Video settings
    SettingKey.defaultVideoQuality: SettingDefinition<String>(
      key: SettingKey.defaultVideoQuality,
      defaultValue: 'medium',
      displayName: 'Качество видео по умолчанию',
      allowedValues: ['low', 'medium', 'high'],
    ),

    SettingKey.defaultVideoFPS: SettingDefinition<String>(
      key: SettingKey.defaultVideoFPS,
      defaultValue: '30',
      displayName: 'Частота кадров по умолчанию',
      allowedValues: ['15', '24', '30', '60'],
    ),

    SettingKey.autoAdjustQuality: SettingDefinition<bool>(
      key: SettingKey.autoAdjustQuality,
      defaultValue: true,
      displayName: 'Автоматическое изменение качества',
      description: 'Автоматически снижать качество при проблемах с сетью',
    ),

    // Network settings
    SettingKey.connectionTimeout: SettingDefinition<int>(
      key: SettingKey.connectionTimeout,
      defaultValue: 15,
      displayName: 'Таймаут подключения (сек)',
      isAdvanced: true,
    ),

    SettingKey.maxRetries: SettingDefinition<int>(
      key: SettingKey.maxRetries,
      defaultValue: 3,
      displayName: 'Максимум попыток повтора',
      isAdvanced: true,
    ),

    // UI settings
    SettingKey.showDebugInfo: SettingDefinition<bool>(
      key: SettingKey.showDebugInfo,
      defaultValue: false,
      displayName: 'Показывать отладочную информацию',
      isAdvanced: true,
    ),

    SettingKey.enableHapticFeedback: SettingDefinition<bool>(
      key: SettingKey.enableHapticFeedback,
      defaultValue: true,
      displayName: 'Тактильная обратная связь',
    ),

    // Advanced settings
    SettingKey.enableLowPowerMode: SettingDefinition<bool>(
      key: SettingKey.enableLowPowerMode,
      defaultValue: true,
      displayName: 'Режим энергосбережения',
      description: 'Автоматически снижать производительность для экономии батареи',
      isAdvanced: true,
    ),

    SettingKey.thermalManagement: SettingDefinition<bool>(
      key: SettingKey.thermalManagement,
      defaultValue: true,
      displayName: 'Управление температурой',
      description: 'Снижать производительность при нагреве устройства',
      isAdvanced: true,
    ),

    SettingKey.enableLogging: SettingDefinition<bool>(
      key: SettingKey.enableLogging,
      defaultValue: kDebugMode,
      displayName: 'Включить логирование',
      isAdvanced: true,
    ),

    // First-time setup
    SettingKey.firstLaunch: SettingDefinition<bool>(
      key: SettingKey.firstLaunch,
      defaultValue: true,
      displayName: 'Первый запуск',
      isAdvanced: true,
    ),

    SettingKey.onboardingCompleted: SettingDefinition<bool>(
      key: SettingKey.onboardingCompleted,
      defaultValue: false,
      displayName: 'Онбординг завершен',
      isAdvanced: true,
    ),
  };

  Future<void> init() async {
    try {
      logInfo('Initializing settings service...');
      _prefs = await SharedPreferences.getInstance();

      // Migrate old settings if needed
      await _migrateOldSettings();

      logInfo('Settings service initialized successfully');
    } catch (e, stackTrace) {
      handleError('init', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> _migrateOldSettings() async {
    try {
      // Migration logic for old setting keys
      final oldKeys = [
        '_kHighQuality',
        '_kSaveOriginal',
        '_kSendImmediately',
        '_kSendToAll',
      ];

      final newKeys = [
        SettingKey.highQuality.key,
        SettingKey.saveOriginal.key,
        SettingKey.sendImmediately.key,
        SettingKey.sendToAll.key,
      ];

      for (int i = 0; i < oldKeys.length; i++) {
        if (_prefs!.containsKey(oldKeys[i])) {
          final value = _prefs!.getBool(oldKeys[i]);
          if (value != null) {
            await _prefs!.setBool(newKeys[i], value);
            await _prefs!.remove(oldKeys[i]);
            logInfo('Migrated setting: ${oldKeys[i]} -> ${newKeys[i]}');
          }
        }
      }
    } catch (e, stackTrace) {
      handleError('_migrateOldSettings', e, stackTrace: stackTrace);
    }
  }

  // Generic getter
  T getSetting<T>(SettingKey key) {
    try {
      final definition = _definitions[key] as SettingDefinition<T>?;
      if (definition == null) {
        throw ArgumentError('Unknown setting key: $key');
      }

      final prefs = _prefs;
      if (prefs == null) {
        logWarning('SharedPreferences not initialized, using default value for $key');
        return definition.defaultValue;
      }

      switch (T) {
        case bool:
          return (prefs.getBool(key.key) ?? definition.defaultValue) as T;
        case int:
          return (prefs.getInt(key.key) ?? definition.defaultValue) as T;
        case double:
          return (prefs.getDouble(key.key) ?? definition.defaultValue) as T;
        case String:
          return (prefs.getString(key.key) ?? definition.defaultValue) as T;
        default:
          final stringValue = prefs.getString(key.key);
          if (stringValue != null && definition.parser != null) {
            final parsed = definition.parser!(stringValue);
            return parsed ?? definition.defaultValue;
          }
          return definition.defaultValue;
      }
    } catch (e, stackTrace) {
      handleError('getSetting', e, stackTrace: stackTrace);
      final definition = _definitions[key] as SettingDefinition<T>?;
      return definition?.defaultValue ?? (false as T);
    }
  }

  // Generic setter
  Future<void> setSetting<T>(SettingKey key, T value) async {
    try {
      final definition = _definitions[key] as SettingDefinition<T>?;
      if (definition == null) {
        throw ArgumentError('Unknown setting key: $key');
      }

      // Validate allowed values
      if (definition.allowedValues != null && !definition.allowedValues!.contains(value)) {
        throw ArgumentError('Value $value not allowed for setting $key');
      }

      final prefs = _prefs;
      if (prefs == null) {
        throw StateError('SharedPreferences not initialized');
      }

      switch (T) {
        case bool:
          await prefs.setBool(key.key, value as bool);
          break;
        case int:
          await prefs.setInt(key.key, value as int);
          break;
        case double:
          await prefs.setDouble(key.key, value as double);
          break;
        case String:
          await prefs.setString(key.key, value as String);
          break;
        default:
          await prefs.setString(key.key, jsonEncode(value));
          break;
      }

      logDebug('Setting updated: $key = $value');
      _settingsChangeController.add(key);
    } catch (e, stackTrace) {
      handleError('setSetting', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Convenience getters for common settings
  bool get isHighQualityEnabled => getSetting<bool>(SettingKey.highQuality);
  bool get isSaveOriginalEnabled => getSetting<bool>(SettingKey.saveOriginal);
  bool get isSendImmediatelyEnabled => getSetting<bool>(SettingKey.sendImmediately);
  bool get isSendToAllEnabled => getSetting<bool>(SettingKey.sendToAll);
  String get defaultVideoQuality => getSetting<String>(SettingKey.defaultVideoQuality);
  String get defaultVideoFPS => getSetting<String>(SettingKey.defaultVideoFPS);
  bool get isAutoAdjustQualityEnabled => getSetting<bool>(SettingKey.autoAdjustQuality);
  bool get isDebugInfoEnabled => getSetting<bool>(SettingKey.showDebugInfo);
  bool get isHapticFeedbackEnabled => getSetting<bool>(SettingKey.enableHapticFeedback);
  bool get isLowPowerModeEnabled => getSetting<bool>(SettingKey.enableLowPowerMode);
  bool get isThermalManagementEnabled => getSetting<bool>(SettingKey.thermalManagement);
  bool get isLoggingEnabled => getSetting<bool>(SettingKey.enableLogging);
  bool get isFirstLaunch => getSetting<bool>(SettingKey.firstLaunch);
  bool get isOnboardingCompleted => getSetting<bool>(SettingKey.onboardingCompleted);

  // Convenience setters
  Future<void> setHighQuality(bool value) => setSetting(SettingKey.highQuality, value);
  Future<void> setSaveOriginal(bool value) => setSetting(SettingKey.saveOriginal, value);
  Future<void> setSendImmediately(bool value) => setSetting(SettingKey.sendImmediately, value);
  Future<void> setSendToAll(bool value) => setSetting(SettingKey.sendToAll, value);
  Future<void> setDefaultVideoQuality(String value) => setSetting(SettingKey.defaultVideoQuality, value);
  Future<void> setDefaultVideoFPS(String value) => setSetting(SettingKey.defaultVideoFPS, value);
  Future<void> setAutoAdjustQuality(bool value) => setSetting(SettingKey.autoAdjustQuality, value);
  Future<void> setDebugInfo(bool value) => setSetting(SettingKey.showDebugInfo, value);
  Future<void> setHapticFeedback(bool value) => setSetting(SettingKey.enableHapticFeedback, value);
  Future<void> setLowPowerMode(bool value) => setSetting(SettingKey.enableLowPowerMode, value);
  Future<void> setThermalManagement(bool value) => setSetting(SettingKey.thermalManagement, value);
  Future<void> setLogging(bool value) => setSetting(SettingKey.enableLogging, value);
  Future<void> setFirstLaunch(bool value) => setSetting(SettingKey.firstLaunch, value);
  Future<void> setOnboardingCompleted(bool value) => setSetting(SettingKey.onboardingCompleted, value);

  // Bulk operations
  Future<void> resetToDefaults({List<SettingKey>? keys}) async {
    try {
      logInfo('Resetting settings to defaults...');

      final keysToReset = keys ?? SettingKey.values;

      for (final key in keysToReset) {
        final definition = _definitions[key];
        if (definition != null) {
          await _prefs?.remove(key.key);
          _settingsChangeController.add(key);
        }
      }

      logInfo('Settings reset completed');
    } catch (e, stackTrace) {
      handleError('resetToDefaults', e, stackTrace: stackTrace);
    }
  }

  Future<void> exportSettings() async {
    try {
      logInfo('Exporting settings...');

      final settings = <String, dynamic>{};

      for (final key in SettingKey.values) {
        final definition = _definitions[key];
        if (definition != null) {
          settings[key.key] = _prefs?.get(key.key) ?? definition.defaultValue;
        }
      }

      // Could save to file or return as string
      final exported = jsonEncode(settings);
      logInfo('Settings exported: ${exported.length} characters');

    } catch (e, stackTrace) {
      handleError('exportSettings', e, stackTrace: stackTrace);
    }
  }

  Future<void> importSettings(Map<String, dynamic> settings) async {
    try {
      logInfo('Importing settings...');

      for (final entry in settings.entries) {
        final settingKey = SettingKey.values.where((k) => k.key == entry.key).firstOrNull;
        if (settingKey != null) {
          final definition = _definitions[settingKey];
          if (definition != null) {
            // Type-safe import based on definition
            try {
              if (definition.defaultValue is bool && entry.value is bool) {
                await setSetting(settingKey, entry.value as bool);
              } else if (definition.defaultValue is int && entry.value is int) {
                await setSetting(settingKey, entry.value as int);
              } else if (definition.defaultValue is String && entry.value is String) {
                await setSetting(settingKey, entry.value as String);
              }
            } catch (e) {
              logWarning('Failed to import setting ${entry.key}: $e');
            }
          }
        }
      }

      logInfo('Settings import completed');
    } catch (e, stackTrace) {
      handleError('importSettings', e, stackTrace: stackTrace);
    }
  }

  List<SettingDefinition> getSettingsForCategory({bool advancedOnly = false}) {
    return _definitions.values
        .where((def) => advancedOnly ? def.isAdvanced : !def.isAdvanced)
        .toList();
  }

  void dispose() {
    _settingsChangeController.close();
  }
}

// Extension for legacy compatibility
extension LegacySettingsManager on SettingsService {
  static Future<SettingsService> getInstance() async {
    final service = SettingsService();
    await service.init();
    return service;
  }
}