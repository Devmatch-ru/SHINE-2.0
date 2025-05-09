// lib/screens/settings_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _highQuality = false;
  bool _saveOriginal = false;
  bool _sendImmediately = false;
  bool _sendToAll = false;

  void _onToggle(String key, bool value) {
    setState(() {
      switch (key) {
        case 'high_quality':
          _highQuality = value;
          break;
        case 'save_original':
          _saveOriginal = value;
          break;
        case 'send_immediately':
          _sendImmediately = value;
          break;
        case 'send_to_all':
          _sendToAll = value;
          break;
      }
    });
    // TODO: persist via SharedPreferences or Bloc event
  }

  @override
  Widget build(BuildContext context) {
    const borderRadius = 8.0;
    const sectionPadding = EdgeInsets.symmetric(horizontal: 12);
    const itemVerticalPadding = 8.0;
    const titleFontSize = 16.0;
    const subtitleFontSize = 12.0;
    const helperFontSize = 12.0;

    final titleStyle = TextStyle(
      color: CupertinoColors.black,
      fontSize: titleFontSize,
    );
    final subtitleStyle = TextStyle(
      color: CupertinoColors.systemGrey,
      fontSize: subtitleFontSize,
    );
    final headerStyle = TextStyle(
      color: CupertinoColors.systemGrey,
      fontSize: helperFontSize,
      fontWeight: FontWeight.bold,
    );

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        middle: Text('Настройки', style: TextStyle(color: CupertinoColors.black)),
        previousPageTitle: 'Назад',
      ),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 20),

            // Качество съёмки
            Padding(
              padding: sectionPadding,
              child: Text('КАЧЕСТВО СЪЁМКИ', style: headerStyle),
            ),
            const SizedBox(height: 8),
            // Toggle item
            Padding(
              padding: sectionPadding,
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: itemVerticalPadding,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Высокое качество трансляции', style: titleStyle)),
                    CupertinoSwitch(
                      value: _highQuality,
                      onChanged: (v) => _onToggle('high_quality', v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 16, 0),
              child: Text(
                'Советуем включить при активном WiFi соединении\n(только для режима «Я фотографирую»)',
                style: subtitleStyle,
              ),
            ),

            const SizedBox(height: 24),

            // Основные
            Padding(
              padding: sectionPadding,
              child: Text('ОСНОВНЫЕ', style: headerStyle),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: sectionPadding,
              child: Column(
                children: [
                  _buildSwitchItem(
                    label: 'Сохранять оригинал',
                    value: _saveOriginal,
                    onChanged: (v) => _onToggle('save_original', v),
                    titleStyle: titleStyle,
                    borderRadius: borderRadius,
                    padding: itemVerticalPadding,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 4, 16, 16),
                    child: Text(
                      'Сохранять фото и видео на снимающем устройстве',
                      style: subtitleStyle,
                    ),
                  ),
                  _buildSwitchItem(
                    label: 'Отправлять сразу',
                    value: _sendImmediately,
                    onChanged: (v) => _onToggle('send_immediately', v),
                    titleStyle: titleStyle,
                    borderRadius: borderRadius,
                    padding: itemVerticalPadding,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 4, 16, 16),
                    child: Text(
                      'Отправлять фото и видео владельцу во время съёмки',
                      style: subtitleStyle,
                    ),
                  ),
                  _buildSwitchItem(
                    label: 'Отправлять всем',
                    value: _sendToAll,
                    onChanged: (v) => _onToggle('send_to_all', v),
                    titleStyle: titleStyle,
                    borderRadius: borderRadius,
                    padding: itemVerticalPadding,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 4, 16, 0),
                    child: Text(
                      'На всех подключённых устройствах (более 2-х устройств)',
                      style: subtitleStyle,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Обратная связь и контакты
            Padding(
              padding: sectionPadding,
              child: Text('ОБРАТНАЯ СВЯЗЬ И КОНТАКТЫ', style: headerStyle),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: sectionPadding,
              child: Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: Column(
                  children: [
                    _buildNavTile('FAQ', () {/* TODO */}, titleStyle),
                    _buildDivider(),
                    _buildNavTile('Рассказать друзьям', () {/* TODO */}, titleStyle),
                    _buildDivider(),
                    _buildNavTile('Оценить приложение', () {/* TODO */}, titleStyle),
                    _buildDivider(),
                    _buildNavTile('О приложении', () {/* TODO */}, titleStyle),
                    _buildDivider(),
                    _buildNavTile('Написать нам', () {/* TODO */}, titleStyle),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: sectionPadding,
              child: Text(
                'Нам важен каждый отзыв, чтобы мы могли сделать приложение лучше',
                style: subtitleStyle,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required TextStyle titleStyle,
    required double borderRadius,
    required double padding,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: padding),
      child: Row(
        children: [
          Expanded(child: Text(label, style: titleStyle)),
          CupertinoSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildNavTile(String title, VoidCallback onTap, TextStyle titleStyle) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: titleStyle),
            const Icon(CupertinoIcons.chevron_forward, color: CupertinoColors.systemGrey),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => const Divider(height: 0, thickness: 0.5, indent: 16, endIndent: 0);
}
