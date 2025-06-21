// lib/screens/settings/settings_screen.dart (Updated)
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_constant.dart';
import '../../utils/new_organize/service/error_handling_service.dart';
import '../../utils/new_organize/service/logging_service.dart';
import '../../utils/new_organize/service/settings_service.dart';
import './about_tabs_screen.dart';
import './faq_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with LoggerMixin, ErrorHandlerMixin {

  @override
  String get loggerContext => 'SettingsScreen';

  late final SettingsService _settingsService;
  bool _loading = true;
  bool _canSendEmail = false;
  bool _showAdvancedSettings = false;

  // Settings values
  bool _highQuality = false;
  bool _saveOriginal = false;
  bool _sendImmediately = false;
  bool _sendToAll = false;
  bool _autoAdjustQuality = false;
  bool _hapticFeedback = false;
  bool _debugInfo = false;
  bool _lowPowerMode = false;
  bool _thermalManagement = false;
  String _defaultVideoQuality = 'medium';
  String _defaultVideoFPS = '30';

  @override
  void initState() {
    super.initState();
    _initializeSettings();
    _checkEmailCapability();
  }

  Future<void> _initializeSettings() async {
    try {
      logInfo('Initializing settings screen...');

      _settingsService = SettingsService();
      await _settingsService.init();

      _loadSettings();

      setState(() {
        _loading = false;
      });

      logInfo('Settings screen initialized');
    } catch (e, stackTrace) {
      handleError('_initializeSettings', e, stackTrace: stackTrace);
      setState(() {
        _loading = false;
      });
    }
  }

  void _loadSettings() {
    setState(() {
      _highQuality = _settingsService.isHighQualityEnabled;
      _saveOriginal = _settingsService.isSaveOriginalEnabled;
      _sendImmediately = _settingsService.isSendImmediatelyEnabled;
      _sendToAll = _settingsService.isSendToAllEnabled;
      _autoAdjustQuality = _settingsService.isAutoAdjustQualityEnabled;
      _hapticFeedback = _settingsService.isHapticFeedbackEnabled;
      _debugInfo = _settingsService.isDebugInfoEnabled;
      _lowPowerMode = _settingsService.isLowPowerModeEnabled;
      _thermalManagement = _settingsService.isThermalManagementEnabled;
      _defaultVideoQuality = _settingsService.defaultVideoQuality;
      _defaultVideoFPS = _settingsService.defaultVideoFPS;
    });
  }

  Future<void> _checkEmailCapability() async {
    try {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: 'help.me0shine@gmail.com',
        query: 'subject=Отзыв о приложении',
      );

      final canLaunch = await canLaunchUrl(emailLaunchUri);
      if (mounted) {
        setState(() {
          _canSendEmail = canLaunch;
        });
      }
    } catch (e, stackTrace) {
      handleError('_checkEmailCapability', e, stackTrace: stackTrace);
    }
  }

  Future<void> _openEmailClient() async {
    try {
      final email = Email(
        recipients: ['help.me0shine@gmail.com'],
        subject: 'Отзыв о приложении',
        body: '',
      );
      await FlutterEmailSender.send(email);
    } catch (e) {
      if (mounted) {
        await _copyToClipboard();
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(
        const ClipboardData(text: 'help.me0shine@gmail.com'));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Адрес скопирован в буфер обмена')),
      );
    }
    Navigator.pop(context);
  }

  Future<void> _updateSetting<T>(SettingKey key, T value) async {
    try {
      await _settingsService.setSetting(key, value);
      logDebug('Setting updated: $key = $value');
    } catch (e, stackTrace) {
      handleError('_updateSetting', e, stackTrace: stackTrace);

      // Revert the UI state
      _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения настроек: $e')),
        );
      }
    }
  }

  void _onToggle(SettingKey key, bool value) async {
    setState(() {
      switch (key) {
        case SettingKey.highQuality:
          _highQuality = value;
          break;
        case SettingKey.saveOriginal:
          _saveOriginal = value;
          break;
        case SettingKey.sendImmediately:
          _sendImmediately = value;
          break;
        case SettingKey.sendToAll:
          _sendToAll = value;
          break;
        case SettingKey.autoAdjustQuality:
          _autoAdjustQuality = value;
          break;
        case SettingKey.enableHapticFeedback:
          _hapticFeedback = value;
          break;
        case SettingKey.showDebugInfo:
          _debugInfo = value;
          break;
        case SettingKey.enableLowPowerMode:
          _lowPowerMode = value;
          break;
        case SettingKey.thermalManagement:
          _thermalManagement = value;
          break;
        default:
          break;
      }
    });

    await _updateSetting(key, value);
  }

  void _onStringSettingChanged(SettingKey key, String value) async {
    setState(() {
      switch (key) {
        case SettingKey.defaultVideoQuality:
          _defaultVideoQuality = value;
          break;
        case SettingKey.defaultVideoFPS:
          _defaultVideoFPS = value;
          break;
        default:
          break;
      }
    });

    await _updateSetting(key, value);
  }

  void _showDebugInfo() {
    final errorService = ErrorHandlingService();
    final report = errorService.generateErrorReport();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отладочная информация'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: SingleChildScrollView(
            child: Text(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: const Text('Копировать'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: report));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Отчет скопирован в буфер обмена')),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сброс настроек'),
        content: const Text('Все настройки будут сброшены к значениям по умолчанию. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Сбросить'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _settingsService.resetToDefaults();
        _loadSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Настройки сброшены')),
          );
        }
      } catch (e, stackTrace) {
        handleError('_resetSettings', e, stackTrace: stackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgMain,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.bgMain,
        previousPageTitle: 'Назад',
        middle: const Text('Настройки', style: AppTextStyles.lead),
        trailing: _debugInfo
            ? CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.info),
          onPressed: _showDebugInfo,
        )
            : null,
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // Quality settings section
            _buildSection(
              'КАЧЕСТВО СЪЁМКИ',
              [
                _buildSwitchRow(
                  label: 'Высокое качество трансляции',
                  value: _highQuality,
                  onChanged: (v) => _onToggle(SettingKey.highQuality, v),
                ),
                _buildHintText(
                  'Советуем включить при активном WiFi соединении\n'
                      '(только для режима «Я фотографирую»)',
                ),

                if (_showAdvancedSettings) ...[
                  _buildSwitchRow(
                    label: 'Автоматическое изменение качества',
                    value: _autoAdjustQuality,
                    onChanged: (v) => _onToggle(SettingKey.autoAdjustQuality, v),
                  ),
                  _buildHintText('Автоматически снижать качество при проблемах с сетью'),

                  _buildPickerRow(
                    label: 'Качество по умолчанию',
                    value: _defaultVideoQuality,
                    options: const ['low', 'medium', 'high'],
                    displayNames: const ['Низкое', 'Среднее', 'Высокое'],
                    onChanged: (v) => _onStringSettingChanged(SettingKey.defaultVideoQuality, v),
                  ),

                  _buildPickerRow(
                    label: 'Частота кадров',
                    value: _defaultVideoFPS,
                    options: const ['15', '24', '30', '60'],
                    displayNames: const ['15 fps', '24 fps', '30 fps', '60 fps'],
                    onChanged: (v) => _onStringSettingChanged(SettingKey.defaultVideoFPS, v),
                  ),
                ],
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Main settings section
            _buildSection(
              'ОСНОВНЫЕ',
              [
                _buildSwitchRow(
                  label: 'Сохранять оригинал',
                  value: _saveOriginal,
                  onChanged: (v) => _onToggle(SettingKey.saveOriginal, v),
                ),
                _buildHintText('Сохранять фото и видео на снимающем устройстве'),

                _buildSwitchRow(
                  label: 'Отправлять сразу',
                  value: _sendImmediately,
                  onChanged: (v) => _onToggle(SettingKey.sendImmediately, v),
                ),
                _buildHintText('Отправлять фото и видео владельцу во время съёмки'),

                _buildSwitchRow(
                  label: 'Отправлять всем',
                  value: _sendToAll,
                  onChanged: (v) => _onToggle(SettingKey.sendToAll, v),
                ),
                _buildHintText('На всех подключённых устройствах (более 2-х устройств)'),

                if (_showAdvancedSettings) ...[
                  _buildSwitchRow(
                    label: 'Тактильная обратная связь',
                    value: _hapticFeedback,
                    onChanged: (v) => _onToggle(SettingKey.enableHapticFeedback, v),
                  ),
                ],
              ],
            ),

            // Advanced settings section
            if (_showAdvancedSettings) ...[
              const SizedBox(height: AppSpacing.xl),
              _buildSection(
                'ДОПОЛНИТЕЛЬНЫЕ',
                [
                  _buildSwitchRow(
                    label: 'Режим энергосбережения',
                    value: _lowPowerMode,
                    onChanged: (v) => _onToggle(SettingKey.enableLowPowerMode, v),
                  ),
                  _buildHintText('Автоматически снижать производительность для экономии батареи'),

                  _buildSwitchRow(
                    label: 'Управление температурой',
                    value: _thermalManagement,
                    onChanged: (v) => _onToggle(SettingKey.thermalManagement, v),
                  ),
                  _buildHintText('Снижать производительность при нагреве устройства'),

                  _buildSwitchRow(
                    label: 'Отладочная информация',
                    value: _debugInfo,
                    onChanged: (v) => _onToggle(SettingKey.showDebugInfo, v),
                  ),
                  _buildHintText('Показывать техническую информацию для диагностики'),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Feedback section
            _buildSection(
              'ОБРАТНАЯ СВЯЗЬ И КОНТАКТЫ',
              [
                _buildNavTile('FAQ', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FAQScreen()),
                  );
                }),
                _buildDivider(),
                _buildNavTile(
                    'Рассказать друзьям', () => _shareApp(context)),
                _buildDivider(),
                _buildNavTile('Оценить приложение', () {/* TODO */}),
                _buildDivider(),
                _buildNavTile('О приложении', () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AboutTabsScreen()),
                  );
                }),
                _buildDivider(),
                _buildNavTile('Написать нам', _showContactDialog),
              ],
            ),

            const SizedBox(height: AppSpacing.xs),

            // Help text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Text(
                'Нам важен каждый отзыв, чтобы мы могли сделать приложение лучше',
                style: AppTextStyles.hintMain,
                textAlign: TextAlign.center,
              ),
            ),

            // Advanced settings toggle
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: CupertinoButton(
                onPressed: () {
                  setState(() {
                    _showAdvancedSettings = !_showAdvancedSettings;
                  });
                },
                child: Text(
                  _showAdvancedSettings ? 'Скрыть дополнительные настройки' : 'Показать дополнительные настройки',
                  style: AppTextStyles.hintAccent,
                ),
              ),
            ),

            // Reset button (only in advanced mode)
            if (_showAdvancedSettings) ...[
              const SizedBox(height: AppSpacing.m),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                child: CupertinoButton(
                  onPressed: _resetSettings,
                  child: const Text(
                    'Сбросить все настройки',
                    style: TextStyle(color: CupertinoColors.destructiveRed),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.m,
              0,
              AppSpacing.m,
              6,
            ),
            child: Text(
              title,
              style: AppTextStyles.hintAccent,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: AppBorderRadius.xs,
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppBorderRadius.xs,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.body),
          ),
          CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required List<String> options,
    required List<String> displayNames,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppBorderRadius.xs,
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s, vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTextStyles.body),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            child: Text(
              displayNames[options.indexOf(value)],
              style: const TextStyle(color: AppColors.primary),
            ),
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => Container(
                  height: 200,
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  child: CupertinoPicker(
                    itemExtent: 32,
                    onSelectedItemChanged: (index) {
                      onChanged(options[index]);
                    },
                    children: displayNames.map((name) => Text(name)).toList(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHintText(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.m, AppSpacing.xs / 2, AppSpacing.s, AppSpacing.m),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: AppTextStyles.hintMain,
      ),
    );
  }

  Widget _buildNavTile(String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => const Divider(
    height: 0,
    thickness: 0.5,
    indent: AppSpacing.s,
    color: Color(0xFFE0E0E0),
  );

  void _showContactDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Отзыв о приложении',
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 16),
                Text(
                  'Если возникли вопросы, трудности или пожелания,\nнапишите нам на help.me0shine@gmail.com',
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canSendEmail ? _openEmailClient : _copyToClipboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.primaryLight,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _canSendEmail ? 'Написать' : 'Скопировать адрес',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _copyToClipboard,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      foregroundColor: AppColors.primary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Скопировать адрес', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _shareApp(BuildContext context) {
  const link = 'https://shine-app.example';
  const text = 'Попробуй Shine – приложение для совместной съёмки ➡ $link';

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Поделиться…'),
            onTap: () {
              Navigator.pop(context);
              Share.share(text);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Скопировать ссылку'),
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: link));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ссылка скопирована')),
              );
            },
          ),
        ],
      ),
    ),
  );
}