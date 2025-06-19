import 'package:flutter/material.dart';

import '../../theme/main_design.dart';

class AboutTabsScreen extends StatelessWidget {
  const AboutTabsScreen({Key? key}) : super(key: key);

  static const _aboutText = '''
Shine Remote Camera — камера, позволяющая транслировать изображение
с камеры телефона на другие устройства в одной Wi-Fi сети.
Управляй съёмкой дистанционно и сохраняй фото на выбранное устройство — быстро и просто.
''';

  static const _termsText = '''
Тут будет шаблон политики

Устанавливая и используя приложение Shine,
Вы принимаете данные условия использования:

1.  Общие положения
''';

  static const _policyText = '''
Тут будет шаблон политики

Устанавливая и используя приложение Shine,
Вы принимаете данные условия использования:

1.  Общие положения
''';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bgMain,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.bgMain,
          leading: const BackButton(color: AppColors.primary),
          title: const Text('О приложении', style: AppTextStyles.lead),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                labelPadding: const EdgeInsets.symmetric(horizontal: 20),

                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.gray.withOpacity(.6),

                labelStyle: AppTextStyles.body,
                unselectedLabelStyle:
                AppTextStyles.body.copyWith(color: AppColors.gray.withOpacity(.6)),

                indicatorSize: TabBarIndicatorSize.label,
                indicator: const UnderlineTabIndicator(
                  borderSide: BorderSide(width: 2, color: AppColors.primary),
                ),

                indicatorWeight: 2,
                tabs: const [
                  Tab(text: 'О приложении'),
                  Tab(text: 'Условия использования'),
                  Tab(text: 'Политика конфиденциальности'),
                ],
              ),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _Page(text: _aboutText),
            _Page(text: _termsText),
            _Page(text: _policyText),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  final String text;
  const _Page({required this.text});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Text(
        text,
        style: AppTextStyles.body,
      ),
    );
  }
}
