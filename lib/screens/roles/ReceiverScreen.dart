import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/theme/main_design.dart';
import 'dart:ui' as ui;

import '../../blocs/receiver/receiver_cubit.dart';
import '../../blocs/receiver/receiver_state.dart';

class ReceiverScreen extends StatelessWidget {
  const ReceiverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ReceiverCubit()..initialize(),
      child: const _ReceiverScreenContent(),
    );
  }
}

class _ReceiverScreenContent extends StatelessWidget {
  const _ReceiverScreenContent();

  // Adaptive sizes
  double _getIconSize(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.07;
  double _getShutterSize(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.18;
  double _getControlsPadding(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.1;

  void _handleError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReceiverCubit, ReceiverState>(
      listener: (context, state) {
        if (state is ReceiverError) {
          _handleError(context, state.error!);
        }
      },
      builder: (context, state) {
        final size = MediaQuery.of(context).size;
        final isPortrait = size.height > size.width;

        // Проверка ориентации экрана
        if (!isPortrait) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'Поверните устройство вертикально',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          );
        }

        // Show loading state during initialization
        if (state.isInitializing) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Полноэкранное видео
              Positioned.fill(
                child: state.isConnected && state.remoteStream != null
                    ? RTCVideoView(
                        context.read<ReceiverCubit>().remoteRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.wifi_tethering,
                              color: Colors.white54,
                              size: 48,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Ожидание подключения...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Размытый заголовок (10% от высоты экрана)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.1,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      color: AppColors.blur.withOpacity(0.3),
                      child: SafeArea(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                state.connectedBroadcaster != null
                                    ? 'Основной: ${state.connectedBroadcaster}'
                                    : 'Ожидание подключения',
                                style: AppTextStyles.lead
                                    .copyWith(color: Colors.white),
                              ),

                              // Индикатор подключенных устройств
                              if (context
                                      .read<ReceiverCubit>()
                                      .connectedBroadcasters
                                      .length >
                                  0)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '📱 ${context.read<ReceiverCubit>().connectedBroadcasters.length}/7',
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Новый селектор качества под шапкой
              if (state.isConnected)
                Positioned(
                  top: size.height * 0.12, // Располагаем под шапкой
                  left: 20,
                  right: 20,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQualityButton(
                            context,
                            'Низкое',
                            StreamQuality.low,
                            state.streamQuality == StreamQuality.low,
                          ),
                          _buildQualityButton(
                            context,
                            'Среднее',
                            StreamQuality.medium,
                            state.streamQuality == StreamQuality.medium,
                          ),
                          _buildQualityButton(
                            context,
                            'Высокое',
                            StreamQuality.high,
                            state.streamQuality == StreamQuality.high,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Кнопка закрытия в правом верхнем углу
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: IconButton(
                    icon: Image.asset(
                      'assets/icons/camera/trailing.png',
                      width: _getIconSize(context),
                      height: _getIconSize(context),
                      color: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),

              // Нижние элементы управления
              if (state.isConnected)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.1,
                      vertical: 20,
                    ),
                    child: Column(
                      children: [
                        // Кнопка отладки
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.black87,
                                builder: (ctx) => Container(
                                  padding: const EdgeInsets.all(16),
                                  height:
                                      MediaQuery.of(context).size.height * 0.5,
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Отладочные сообщения',
                                        style: TextStyle(
                                            color: Colors.white, fontSize: 18),
                                      ),
                                      const SizedBox(height: 16),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: context
                                              .read<ReceiverCubit>()
                                              .debugMessages
                                              .length,
                                          reverse: true,
                                          itemBuilder: (context, index) {
                                            final messages = context
                                                .read<ReceiverCubit>()
                                                .debugMessages;
                                            final message = messages[
                                                messages.length - 1 - index];
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 2),
                                              child: Text(
                                                message,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'ОТЛАДКА',
                                style: AppTextStyles.body.copyWith(
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Основные элементы управления в новом порядке
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Кнопка фонарика с динамической иконкой
                            IconButton(
                              icon: Image.asset(
                                context.read<ReceiverCubit>().isFlashOn
                                    ? 'assets/icons/camera/flash.png'
                                    : 'assets/icons/camera/_flash.png',
                                width: _getIconSize(context),
                                height: _getIconSize(context),
                                color: Colors.white,
                              ),
                              onPressed: () {
                                context
                                    .read<ReceiverCubit>()
                                    .sendCommand(CommandType.flashlight);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('🔦 Команда: Переключить фонарик'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),

                            // Центральная кнопка фото
                            GestureDetector(
                              onTap: () {
                                context
                                    .read<ReceiverCubit>()
                                    .sendCommand(CommandType.photo);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('📸 Команда: Сделать фото'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: Image.asset(
                                'assets/icons/camera/_shutter.png',
                                width: _getShutterSize(context),
                                height: _getShutterSize(context),
                              ),
                            ),

                            // Кнопка таймера
                            IconButton(
                              icon: Image.asset(
                                'assets/icons/camera/thunder.png',
                                width: _getIconSize(context),
                                height: _getIconSize(context),
                                color: Colors.white,
                              ),
                              onPressed: () {
                                context
                                    .read<ReceiverCubit>()
                                    .sendCommand(CommandType.timer);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('⏱️ Команда: Запустить таймер'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _getQualityName(StreamQuality quality) {
    switch (quality) {
      case StreamQuality.low:
        return 'Низкое (640x360)';
      case StreamQuality.medium:
        return 'Среднее (1280x720)';
      case StreamQuality.high:
        return 'Высокое (1920x1080, 25fps)';
    }
  }

  // Вспомогательный метод для создания кнопки качества
  Widget _buildQualityButton(
    BuildContext context,
    String text,
    StreamQuality quality,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        context.read<ReceiverCubit>().changeStreamQuality(quality);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Изменение качества на ${_getQualityName(quality)}'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
