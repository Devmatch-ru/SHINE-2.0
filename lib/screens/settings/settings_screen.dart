import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shine/screens/settings/about_tabs_screen.dart';
import '../../theme/app_constant.dart';
import '../../utils/settings_manager.dart';
import 'faq_screen.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingItem {
  final String key;
  final String label;
  final String? description;
  final bool value;

  SettingItem({
    required this.key,
    required this.label,
    this.description,
    required this.value,
  });
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsManager _settings;
  bool _loading = true;
  bool _canSendEmail = false;

  final Map<String, bool> _settingsValues = {};

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _checkEmailCapability(),
      _loadSettings(),
    ]);
  }

  Future<void> _checkEmailCapability() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'help.me0shine@gmail.com',
      query: 'subject=Отзыв о приложении',
    );

    final canLaunch = await canLaunchUrl(emailLaunchUri);
    if (mounted) {
      setState(() => _canSendEmail = canLaunch);
    }
  }

  Future<void> _loadSettings() async {
    _settings = await SettingsManager.getInstance();
    setState(() {
      _settingsValues['high_quality'] = _settings.isHighQualityEnabled;
      _settingsValues['save_original'] = _settings.isSaveOriginalEnabled;
      _settingsValues['send_immediately'] = _settings.isSendImmediatelyEnabled;
      _settingsValues['send_to_all'] = _settings.isSendToAllEnabled;
      _loading = false;
    });
  }

  void _onToggle(String key, bool value) {
    setState(() => _settingsValues[key] = value);

    switch (key) {
      case 'high_quality':
        _settings.setHighQuality(value);
        break;
      case 'save_original':
        _settings.setSaveOriginal(value);
        break;
      case 'send_immediately':
        _settings.setSendImmediately(value);
        break;
      case 'send_to_all':
        _settings.setSendToAll(value);
        break;
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
            _AnimatedSection(
              delay: 0,
              child: _QualitySection(
                value: _settingsValues['high_quality']!,
                onChanged: (v) => _onToggle('high_quality', v),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _AnimatedSection(
              delay: 200,
              child: _MainSettingsSection(
                settings: _getMainSettings(),
                onToggle: _onToggle,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _AnimatedSection(
              delay: 400,
              child: _ContactSection(canSendEmail: _canSendEmail),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  List<SettingItem> _getMainSettings() => [
    SettingItem(
      key: 'save_original',
      label: 'Сохранять оригинал',
      description: 'Сохранять фото и видео на снимающем устройстве',
      value: _settingsValues['save_original']!,
    ),
    SettingItem(
      key: 'send_immediately',
      label: 'Отправлять сразу',
      description: 'Отправлять фото и видео владельцу во время съёмки',
      value: _settingsValues['send_immediately']!,
    ),
    SettingItem(
      key: 'send_to_all',
      label: 'Отправлять всем',
      description: 'На всех подключённых устройствах (более 2-х устройств)',
      value: _settingsValues['send_to_all']!,
    ),
  ];
}

class _AnimatedSection extends StatefulWidget {
  final int delay;
  final Widget child;

  const _AnimatedSection({
    required this.delay,
    required this.child,
  });

  @override
  State<_AnimatedSection> createState() => _AnimatedSectionState();
}

class _AnimatedSectionState extends State<_AnimatedSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slideY;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutQuart,
    );
    _slideY = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slideY.value),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _QualitySection extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _QualitySection({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'КАЧЕСТВО СЪЁМКИ'),
          _SwitchRow(
            label: 'Высокое качество трансляции',
            value: value,
            onChanged: onChanged,
          ),
          const SizedBox(height: AppSpacing.xs / 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.m, 0, AppSpacing.s, 0),
            child: Text(
              'Советуем включить при активном WiFi соединении\n'
                  '(только для режима «Я фотографирую»)',
              style: AppTextStyles.hintMain,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainSettingsSection extends StatelessWidget {
  final List<SettingItem> settings;
  final Function(String, bool) onToggle;

  const _MainSettingsSection({
    required this.settings,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: 'ОСНОВНЫЕ'),
          ...settings.expand((setting) => [
            _SwitchRow(
              label: setting.label,
              value: setting.value,
              onChanged: (v) => onToggle(setting.key, v),
            ),
            if (setting.description != null) ...[
              const SizedBox(height: AppSpacing.xs / 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.m,
                  0,
                  AppSpacing.s,
                  AppSpacing.m,
                ),
                child: Text(
                  setting.description!,
                  style: AppTextStyles.hintMain,
                ),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final bool canSendEmail;

  const _ContactSection({required this.canSendEmail});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionHeader(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          title: 'ОБРАТНАЯ СВЯЗЬ И КОНТАКТЫ',
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
                _NavTile('FAQ', () => _navigateToFAQ(context)),
                _buildDivider(),
                _NavTile('Рассказать друзьям', () => _shareApp(context)),
                _buildDivider(),
                _NavTile('Оценить приложение', () {}),
                _buildDivider(),
                _NavTile('О приложении', () => _navigateToAbout(context)),
                _buildDivider(),
                _NavTile('Написать нам', () => _showEmailDialog(context, canSendEmail)),
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
      ],
    );
  }

  Widget _buildDivider() => const Divider(
    height: 0,
    thickness: 0.5,
    indent: AppSpacing.s,
    color: Color(0xFFE0E0E0),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry? padding;

  const _SectionHeader({
    required this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(
        AppSpacing.m,
        0,
        AppSpacing.m,
        6,
      ),
      child: Text(title, style: AppTextStyles.hintAccent),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppBorderRadius.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _NavTile(this.title, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        alignment: Alignment.center,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
        child: Text(
          title,
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

void _navigateToFAQ(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const FAQScreen()),
  );
}

void _navigateToAbout(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AboutTabsScreen()),
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
              Share.share(text);
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Скопировать ссылку'),
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: link));
              Navigator.pop(context);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ссылка скопирована')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

void _showEmailDialog(BuildContext context, bool canSendEmail) {
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
              Text('Отзыв о приложении', style: AppTextStyles.h2),
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
                  onPressed: canSendEmail
                      ? () => _openEmailClient(context)
                      : () => _copyEmailToClipboard(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryLight,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    canSendEmail ? 'Написать' : 'Скопировать адрес',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _openEmailClient(BuildContext context) async {
  try {
    final email = Email(
      recipients: ['help.me0shine@gmail.com'],
      subject: 'Отзыв о приложении',
      body: '',
    );
    await FlutterEmailSender.send(email);
  } catch (e) {
    if (context.mounted) {
      await _copyEmailToClipboard(context);
    }
  }
}

Future<void> _copyEmailToClipboard(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: 'help.me0shine@gmail.com'));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Адрес скопирован в буфер обмена')),
    );
    Navigator.pop(context);
  }
}