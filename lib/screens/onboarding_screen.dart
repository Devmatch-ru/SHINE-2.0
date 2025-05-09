import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/onboarding/onboarding_cubit.dart';

class OnboardingPageData {
  final String title;
  final String description;
  final String backgroundImage;
  OnboardingPageData({
    required this.title,
    required this.description,
    required this.backgroundImage,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentIndex = 0;

  final _pages = <OnboardingPageData>[
    OnboardingPageData(
      title: 'Создавай лучшие фото вместе с Shine',
      description:
          'Изображение камеры одного устройства транслируется на другое,\nчто позволяет управлять съёмкой',
      backgroundImage: 'assets/images/onboarding/onboard1.png',
    ),
    OnboardingPageData(
      title: 'Подключайся через WiFi',
      description:
          'Подключай устройства через точку доступа WiFi для просмотра трансляции камеры',
      backgroundImage: 'assets/images/onboarding/onboard2.png',
    ),
    OnboardingPageData(
      title: 'Управляй съёмкой',
      description:
          'Меняй качество трансляции во время съёмки и сохраняй фото и видео',
      backgroundImage: 'assets/images/onboarding/onboard3.png',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentIndex < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.read<OnboardingCubit>().complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _controller,
        itemCount: _pages.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, i) {
          final page = _pages[i];
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                page.backgroundImage,
                fit: BoxFit.cover,
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildProgressBar(context),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        page.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        page.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ElevatedButton(
                        onPressed: _onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: const StadiumBorder(),
                          minimumSize: const Size.fromHeight(48),
                          padding: EdgeInsets.zero,
                        ),
                        child: Text(
                          i < _pages.length - 1 ? 'Продолжить' : 'Начать',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final count = _pages.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(count, (j) {
          final filled = j <= _currentIndex;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: filled ? Colors.white : Colors.white.withOpacity(0.4),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          );
        }),
      ),
    );
  }
}
