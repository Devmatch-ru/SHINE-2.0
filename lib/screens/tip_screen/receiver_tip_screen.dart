import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shine/screens/user/receiver/receiver_screen.dart';
import '../../blocs/wifi/wifi_cubit.dart';
import '../../blocs/wifi/wifi_state.dart';
import '../../theme/app_constant.dart';

class HostTipScreen extends StatelessWidget {
  const HostTipScreen({super.key});

  static const _prefsKey = 'host_tip_seen';

  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_prefsKey) ?? false);
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(() => HostTipScreen.markSeen());

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/tips/client_tip.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primary),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<WifiCubit, WifiState>(
                builder: (context, state) {
                  final baseSubtitle = 'Доступ к просмотру изображения с камеры другого устройства. Снижайте качество трансляции для более стабильной работы';
                  final errorSubtitle = switch (state) {
                    WifiDisconnected() => 'Кажется, отсутствует соединение.\nДля работы подключитесь к точке доступа Wi-Fi',
                    //WifiConnectedStable() || WifiDisconnected() => 'Кажется, соединение нестабильно.\nПроверьте подключение к точке доступа Wi-Fi',
                    _ => '',
                  };
                  final errorMessage = state is WifiDisconnected ? 'Отсутствует соединение' : '';

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.l,
                          vertical: AppSpacing.l,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              children: [
                                const SizedBox(height: 332),
                                const Text(
                                  'Меня фотографируют',
                                  style: AppTextStyles.h2,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.s),
                                Text(
                                  baseSubtitle,
                                  style: AppTextStyles.body,
                                  textAlign: TextAlign.center,
                                ),
                                if (errorSubtitle.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.s),
                                  Text(
                                    errorSubtitle,
                                    style: AppTextStyles.body,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                if ( state is WifiDisconnected) ...[
                                  const SizedBox(height: AppSpacing.m),
                                  if (errorMessage.isNotEmpty)
                                    Text(
                                      errorMessage,
                                      style: AppTextStyles.body,
                                      textAlign: TextAlign.center,
                                    ),
                                  const CircularProgressIndicator(),
                                ],
                                const Spacer(),
                                if ( state is! WifiDisconnected) ...[
                                  ElevatedButton(
                                    onPressed: () async => await Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        transitionDuration: const Duration(milliseconds: 300),
                                        pageBuilder: (context, animation, secondaryAnimation) => const ReceiverScreen(),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return SlideTransition(
                                            position: animation.drive(
                                              Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                                                  .chain(CurveTween(curve: Curves.easeInOut)),
                                            ),
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppColors.primary,
                                      shape: const StadiumBorder(),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      minimumSize: const Size.fromHeight(50),
                                    ),
                                    child: const Text(
                                      'Хорошо',
                                      style: TextStyle(fontSize: 17, color: Colors.black),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 100),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}