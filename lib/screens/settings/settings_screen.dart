import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shine/screens/settings/about_tabs_screen.dart';
import '../../theme/main_design.dart';
import '../../utils/settings_manager.dart';
import 'faq_screen.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _highQuality = false;
  bool _saveOriginal = false;
  bool _sendImmediately = false;
  bool _sendToAll = false;
  bool _loading = true;

  late final SettingsManager _settings;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _openEmailClient(BuildContext context) async {
    final email = Email(
      recipients: ['isip_s.a.komkov@mpt.ru'],
      subject: 'Отзыв о приложении',
      body: '',
    );

    try {
      await FlutterEmailSender.send(email);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть почтовый клиент:\n$e')),
      );
    }
  }

  Future<void> _loadSettings() async {
    _settings = await SettingsManager.getInstance();
    setState(() {
      _highQuality = _settings.isHighQualityEnabled;
      _saveOriginal = _settings.isSaveOriginalEnabled;
      _sendImmediately = _settings.isSendImmediatelyEnabled;
      _sendToAll = _settings.isSendToAllEnabled;
      _loading = false;
    });
  }

  void _onToggle(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'high_quality':
          _highQuality = value;
          _settings.setHighQuality(value);
          break;
        case 'save_original':
          _saveOriginal = value;
          _settings.setSaveOriginal(value);
          break;
        case 'send_immediately':
          _sendImmediately = value;
          _settings.setSendImmediately(value);
          break;
        case 'send_to_all':
          _sendToAll = value;
          _settings.setSendToAll(value);
          break;
      }
    });
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
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppColors.bgMain,
        previousPageTitle: 'Назад',
        middle: Text('Настройки', style: AppTextStyles.lead),
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Padding(
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
                      'КАЧЕСТВО СЪЁМКИ',
                      style: AppTextStyles.hintAccent,
                    ),
                  ),
                  _buildSwitchRow(
                    label: 'Высокое качество трансляции',
                    value: _highQuality,
                    onChanged: (v) => _onToggle('high_quality', v),
                  ),
                  const SizedBox(height: AppSpacing.xs / 2),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.m, 0, AppSpacing.s, 0),
                    child: Text(
                      'Советуем включить при активном WiFi соединении\n'
                      '(только для режима «Я фотографирую»)',
                      style: AppTextStyles.hintMain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.s),
                    child: Text(
                      'ОСНОВНЫЕ',
                      style: AppTextStyles.hintAccent,
                    ),
                  ),
                  _buildSwitchRow(
                    label: 'Сохранять оригинал',
                    value: _saveOriginal,
                    onChanged: (v) => _onToggle('save_original', v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.xs / 2,
                      AppSpacing.s,
                      AppSpacing.m,
                    ),
                    child: Text(
                      'Сохранять фото и видео на снимающем устройстве',
                      textAlign: TextAlign.start,
                      style: AppTextStyles.hintMain,
                    ),
                  ),
                  _buildSwitchRow(
                    label: 'Отправлять сразу',
                    value: _sendImmediately,
                    onChanged: (v) => _onToggle('send_immediately', v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.xs / 2,
                      AppSpacing.s,
                      AppSpacing.m,
                    ),
                    child: Text(
                      'Отправлять фото и видео владельцу во время съёмки',
                      textAlign: TextAlign.start,
                      style: AppTextStyles.hintMain,
                    ),
                  ),
                  _buildSwitchRow(
                    label: 'Отправлять всем',
                    value: _sendToAll,
                    onChanged: (v) => _onToggle('send_to_all', v),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.m,
                      AppSpacing.xs / 2,
                      AppSpacing.s,
                      0,
                    ),
                    child: Text(
                      'На всех подключённых устройствах (более 2-х устройств)',
                      textAlign: TextAlign.start,
                      style: AppTextStyles.hintMain,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                'ОБРАТНАЯ СВЯЗЬ И КОНТАКТЫ',
                style: AppTextStyles.hintAccent,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: AppBorderRadius.xs,
                ),
                child: Column(
                  children: [
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
                    _buildNavTile('Написать нам', () {
                      showDialog(
                        context: context,
                        barrierColor: Colors.black12, // чуть затемнённый фон
                        builder: (ctx) => Center(
                          child: Material(
                            color: Colors.transparent,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                                    'Если возникли вопросы, трудности или пожелания,\nнапишите нам на adress@mail',
                                    style: AppTextStyles.body,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        _openEmailClient(context);
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: AppColors.primaryLight,
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                      ),
                                      child: const Text('Написать',
                                          style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              child: Text(
                'Нам важен каждый отзыв, чтобы мы могли сделать приложение лучше',
                style: AppTextStyles.hintMain,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
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
              Share.share(text); // системное меню share
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
