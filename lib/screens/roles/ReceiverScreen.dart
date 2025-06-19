import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/theme/main_design.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

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

  double _getIconSize(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.07;
  double _getShutterSize(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.18;
  double _getControlsPadding(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.1;


  void _handleError(BuildContext context, String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showConnectionStatus(BuildContext context, ReceiverState state) {
    final messages = context.read<ReceiverCubit>().debugMessages;
    if (messages.isNotEmpty) {
      print('Last debug message: ${messages.last}');
    }

    String status = 'Статус подключения:\n';
    status +=
        state.isConnected ? '✅ Соединение активно\n' : '❌ Нет соединения\n';
    status += state.remoteStream != null
        ? '✅ Видео поток активен\n'
        : '❌ Нет видео потока\n';
    status += state.connectedBroadcaster != null
        ? '✅ Broadcaster подключен (${state.connectedBroadcaster})\n'
        : '❌ Нет подключенного broadcaster\n';
    status +=
        'Качество потока: ${state.streamQuality.toString().split('.').last}\n';
    status +=
        'Качество соединения: ${state.connectionQuality ?? "Неизвестно"}\n';
    status += 'Задержка: ${state.connectionLatency ?? "Неизвестно"} мс\n';
    status += 'Разрешение: ${state.videoResolution ?? "Неизвестно"}\n';
    status += 'Битрейт: ${state.videoBitrate ?? "Неизвестно"} кбит/с\n';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Статус подключения',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(status),
                const Divider(),
                const Text(
                  'Последние события:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: messages.length,
                      reverse: true,
                      itemBuilder: (context, index) {
                        final msg = messages[messages.length - 1 - index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            '• $msg',
                            style: TextStyle(
                              fontSize: 12,
                              color: msg.contains('Error') ||
                                      msg.contains('ошибка')
                                  ? Colors.red
                                  : msg.contains('успешно') ||
                                          msg.contains('connected')
                                      ? Colors.green
                                      : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: const Text('Копировать'),
                      onPressed: () {
                        final debugInfo = status + "\n" + messages.join("\n");
                        Clipboard.setData(ClipboardData(text: debugInfo));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Скопировано в буфер обмена')),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Закрыть'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
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
        print('Building UI with state: $state');
        print('isConnected: ${state.isConnected}, remoteStream: ${state.remoteStream}');
        final size = MediaQuery.of(context).size;
        final isPortrait = size.height > size.width;

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
              Positioned.fill(
                child: state.isConnected && state.remoteStream != null
                    ? RTCVideoView(
                        context.read<ReceiverCubit>().remoteRenderer,
                        key: ValueKey(state.remoteStream.toString()),
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.wifi_tethering,
                              color: Colors.white54,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              state.isConnected
                                  ? 'Подключено, ожидание видео потока...'
                                  : 'Ожидание подключения...',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // TextButton(
                            //   onPressed: () => _showConnectionStatus(context, state),
                            //   child: const Text(
                            //     'Показать статус подключения',
                            //     style: TextStyle(color: Colors.blue),
                            //   ),
                            // ),
                          ],
                        ),
                      ),
              ),
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
                              Text( 'Camera',
                                style: AppTextStyles.lead.copyWith(color: Colors.white),
                              ),
                              if (context.read<ReceiverCubit>().connectedBroadcasters.length > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
              if (state.isConnected)
                Positioned(
                  top: size.height * 0.12,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
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
                                context.read<ReceiverCubit>().sendCommand(CommandType.flashlight);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Команда: Переключить фонарик'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                            GestureDetector(
                              onTap: () {
                                context.read<ReceiverCubit>().sendCommand(CommandType.photo);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Команда: Сделать фото'),
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
                            IconButton(
                              icon: Image.asset(
                                'assets/icons/camera/thunder.png',
                                width: _getIconSize(context),
                                height: _getIconSize(context),
                                color: Colors.white,
                              ),
                              onPressed: () {
                                context.read<ReceiverCubit>().sendCommand(CommandType.timer);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Команда: Запустить таймер'),
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
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 60,
                child: GestureDetector(
                  // onTap: () => _showConnectionStatus(context, state),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          state.isConnected ? Icons.link : Icons.link_off,
                          color: state.isConnected ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          state.remoteStream != null ? Icons.videocam : Icons.videocam_off,
                          color: state.remoteStream != null ? Colors.green : Colors.red,
                          size: 16,
                        ),
                      ],
                    ),
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