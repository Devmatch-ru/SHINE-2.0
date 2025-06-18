import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/theme/main_design.dart';
import 'dart:ui' as ui;

import '../../blocs/broadcaster/broadcaster_cubit.dart';
import '../../blocs/broadcaster/broadcaster_state.dart';

class BroadcasterScreen extends StatelessWidget {
  final String receiverUrl;

  const BroadcasterScreen({
    super.key,
    required this.receiverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = BroadcasterCubit(receiverUrl: receiverUrl);
        // Initialize asynchronously
        Future.microtask(() => cubit.initialize());
        return cubit;
      },
      child: const _BroadcasterScreenContent(),
    );
  }
}

class _BroadcasterScreenContent extends StatelessWidget {
  const _BroadcasterScreenContent();

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
    return BlocConsumer<BroadcasterCubit, BroadcasterState>(
      listener: (context, state) {
        if (state is BroadcasterError) {
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

        if (state is BroadcasterInitial) {
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
              Positioned.fill(
                child: state.isInitializing
                    ? Container(color: Colors.black)
                    : RTCVideoView(
                        context.read<BroadcasterCubit>().localRenderer,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
              ),

              // Хэдэр
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
                                'Camera',
                                style: AppTextStyles.lead
                                    .copyWith(color: Colors.white),
                              ),

                              // Индикаторы состояния
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (state.isPowerSaveMode)
                                    Container(
                                      margin: const EdgeInsets.only(
                                          top: 2, right: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '🔋',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  if (state.isRecording)
                                    Container(
                                      margin: const EdgeInsets.only(
                                          top: 2, right: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '🔴',
                                        style: TextStyle(fontSize: 10),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    onPressed: () async {
                      await context.read<BroadcasterCubit>().disconnect();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ),

              // Таймер в центре экрана
              if (state.isTimerActive)
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Center(
                      child: Text(
                        '${state.timerSeconds}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Сообщение команды
              if (state.commandMessage != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      state.commandMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // Нижние элементы управления
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
                      // Переключатель режимов
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.read<BroadcasterCubit>().setPhotoMode(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: !state.isVideoMode
                                    ? Colors.black.withOpacity(0.4)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'ФОТОГРАФИЯ',
                                style: AppTextStyles.body.copyWith(
                                  color: !state.isVideoMode
                                      ? Colors.amber
                                      : Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                context.read<BroadcasterCubit>().setVideoMode(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: state.isVideoMode
                                    ? Colors.black.withOpacity(0.4)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                'ВИДЕОЗАПИСЬ',
                                style: AppTextStyles.body.copyWith(
                                  color: state.isVideoMode
                                      ? Colors.amber
                                      : Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Основные элементы управления
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Кнопка фонарика
                          BlocBuilder<BroadcasterCubit, BroadcasterState>(
                            builder: (context, state) {
                              final isFlashOn =
                                  context.read<BroadcasterCubit>().isFlashOn;
                              final iconSize = _getIconSize(context);

                              return IconButton(
                                icon: Image.asset(
                                  isFlashOn
                                      ? 'assets/icons/camera/flash.png'
                                      : 'assets/icons/camera/_flash.png',
                                  width: iconSize,
                                  height: iconSize,
                                ),
                                onPressed: () => context
                                    .read<BroadcasterCubit>()
                                    .toggleFlash(),
                              );
                            },
                          ),

                          // Центральная кнопка
                          GestureDetector(
                            onTap: state.isTimerActive
                                ? null
                                : () {
                                    if (state.isVideoMode) {
                                      context
                                          .read<BroadcasterCubit>()
                                          .toggleRecording();
                                    } else {
                                      context
                                          .read<BroadcasterCubit>()
                                          .capturePhoto();
                                    }
                                  },
                            child: Image.asset(
                              (state.isVideoMode && state.isRecording)
                                  ? 'assets/icons/camera/shutter.png'
                                  : 'assets/icons/camera/_shutter.png',
                              width: _getShutterSize(context),
                              height: _getShutterSize(context),
                              color: state.isTimerActive ? Colors.grey : null,
                            ),
                          ),

                          // Кнопка таймера
                          IconButton(
                            icon: Image.asset(
                              'assets/icons/camera/thunder.png',
                              width: _getIconSize(context),
                              height: _getIconSize(context),
                              color: state.isTimerActive
                                  ? Colors.grey
                                  : Colors.white,
                            ),
                            onPressed: state.isTimerActive
                                ? null
                                : () => context
                                    .read<BroadcasterCubit>()
                                    .startTimerCapture(),
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
}
