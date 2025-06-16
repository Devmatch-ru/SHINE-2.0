import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../blocs/receiver/receiver_cubit.dart';
import '../blocs/receiver/receiver_state.dart';

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
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // Full-screen video view
                Positioned.fill(
                  child: state.isInitializing
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                          ),
                        )
                      : state.isConnected && state.remoteStream != null
                          ? RTCVideoView(
                              context.read<ReceiverCubit>().remoteRenderer,
                              objectFit: RTCVideoViewObjectFit
                                  .RTCVideoViewObjectFitCover,
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

                // Top bar with title and close button
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const SizedBox(width: 24),
                              Text(
                                state.connectedBroadcaster != null
                                    ? 'Основной: ${state.connectedBroadcaster}'
                                    : 'Ожидание подключения',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),

                          // Показываем количество подключенных устройств
                          if (context
                                  .read<ReceiverCubit>()
                                  .connectedBroadcasters
                                  .length >
                              1)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Подключено устройств: ${context.read<ReceiverCubit>().connectedBroadcasters.length}/7',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Control buttons
                if (state.isConnected)
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Debug button
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ElevatedButton.icon(
                            onPressed: () {
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
                            icon: const Icon(Icons.bug_report),
                            label: const Text('Отладка'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                        ),

                        // Quality selector
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Качество: ',
                                style: TextStyle(color: Colors.white),
                              ),
                              DropdownButton<StreamQuality>(
                                value: state.streamQuality,
                                dropdownColor: Colors.black87,
                                style: const TextStyle(color: Colors.white),
                                underline: Container(),
                                items: const [
                                  DropdownMenuItem(
                                    value: StreamQuality.low,
                                    child: Text('Низкое (640x360)'),
                                  ),
                                  DropdownMenuItem(
                                    value: StreamQuality.medium,
                                    child: Text('Среднее (1280x720)'),
                                  ),
                                  DropdownMenuItem(
                                    value: StreamQuality.high,
                                    child: Text('Высокое (1920x1080, 25fps)'),
                                  ),
                                ],
                                onChanged: (quality) {
                                  if (quality != null) {
                                    context
                                        .read<ReceiverCubit>()
                                        .changeStreamQuality(quality);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Изменение качества на ${_getQualityName(quality)}'),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),

                        // Command buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FloatingActionButton(
                              heroTag: 'photo',
                              onPressed: () {
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
                              backgroundColor: Colors.white,
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.black),
                            ),
                            FloatingActionButton(
                              heroTag: 'video',
                              onPressed: () {
                                context
                                    .read<ReceiverCubit>()
                                    .sendCommand(CommandType.video);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        '🎥 Команда: Переключить видеозапись'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              backgroundColor: Colors.white,
                              child: const Icon(Icons.videocam,
                                  color: Colors.black),
                            ),
                            FloatingActionButton(
                              heroTag: 'flashlight',
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
                              backgroundColor: Colors.white,
                              child: const Icon(Icons.flashlight_on,
                                  color: Colors.black),
                            ),
                            FloatingActionButton(
                              heroTag: 'timer',
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
                              backgroundColor: Colors.white,
                              child:
                                  const Icon(Icons.timer, color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
}
