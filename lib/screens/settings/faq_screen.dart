import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../theme/app_constant.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  static const _items = <_FaqItem>[
    _FaqItem(
      question: 'Как подключиться к другому устройству?',
      answer:
      'Подключайся к одной точке доступа, чтобы видеть все устройства в сети',
    ),
    _FaqItem(
      question: 'Приложение вылетает при соединении',
      answer:
      'Возможно, приложение не получило доступ к камере. Разрешить доступ к приложению можно в настройках телефона',
    ),
    _FaqItem(
      question: 'Плохое качество трансляции',
      answer:
      'Можно изменить качество трансляции во время съёмки, выбрав более высокое или более низкое. '
          'Это не отобразится на качестве фото и видео. Также в настройках приложения доступно управление качеством трансляции',
    ),
    _FaqItem(
      question: 'Приложение вылетает при трансляции. Что делать?',
      answer:
      'Иногда такое случается. Попробуй подключиться с другим устройством. Некоторые устройства могут вести себя '
          'нестабильно друг с другом, что может влиять на трансляцию изображений и видео',
    ),
    _FaqItem(
      question: 'Где сохраняется фото и видео после съёмки?',
      answer:
      'Сохраняй фото и видео на свой телефон или на все подключённые устройства сразу — управляй доступом в настройках',
    ),
  ];

  @override
  Widget build(BuildContext context) {

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        previousPageTitle: 'Назад',
        middle: Text('FAQ', style: AppTextStyles.lead),
        backgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      child: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s),
          separatorBuilder: (_, __) => const Divider(
            height: 0,
            thickness: 0.1,
            indent: AppSpacing.s,
            endIndent: AppSpacing.s,
          ),
          itemCount: _items.length,
          itemBuilder: (context, i) {
            final item = _items[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.s, AppSpacing.xs, AppSpacing.s, AppSpacing.s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.question, style: AppTextStyles.lead),
                  const SizedBox(height: AppSpacing.s),
                  Text(item.answer, style: AppTextStyles.body),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}
