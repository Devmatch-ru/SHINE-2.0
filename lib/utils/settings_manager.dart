import 'package:shared_preferences/shared_preferences.dart';

class SettingsManager {
  static const String _kHighQuality = 'high_quality';
  static const String _kSaveOriginal = 'save_original';
  static const String _kSendImmediately = 'send_immediately';
  static const String _kSendToAll = 'send_to_all';

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
  }

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
}
