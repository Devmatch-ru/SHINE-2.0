import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/blocs/receiver/receiver_state.dart';
import 'package:shine/theme/app_constant.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shine/blocs/receiver/receiver_cubit.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  late final ReceiverCubit _cubit;
  late final RTCVideoRenderer _remoteRenderer;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _remoteRenderer = RTCVideoRenderer();
    _cubit = ReceiverCubit();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _remoteRenderer.initialize();
      await _cubit.initialize();
      setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка инициализации: $e')),
        );
      }
    }
  }

  double _getIconSize(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.07;
  double _getShutterSize(BuildContext context) =>
      MediaQuery.of(context).size.width * 0.18;

  void _showConnectionStatus() {
    final state = _cubit.state;
    final messages = _cubit.messages;
    String status = 'Статус подключения:\n';
    status +=
        state.isConnected ? '✅ Соединение активно\n' : '❌ Нет соединения\n';
    status += state.remoteStream != null
        ? '✅ Видео поток активен\n'
        : '❌ Нет видео потока\n';
    status += state.connectedBroadcasters.isNotEmpty
        ? '✅ Broadcaster подключен (${state.connectedBroadcasters.first})\n'
        : '❌ Нет подключенного broadcaster\n';
    // Stream quality, connection quality, latency, resolution, and bitrate not supported in ReceiverManager
    status += 'Качество потока: Неизвестно\n';
    status += 'Качество соединения: Неизвестно\n';
    status += 'Задержка: Неизвестно мс\n';
    status += 'Разрешение: Неизвестно\n';
    status += 'Битрейт: Неизвестно кбит/с\n';

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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                              horizontal: 8, vertical: 4),
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
                        final debugInfo = "$status\n${messages.join("\n")}";
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
  void dispose() {
    _remoteRenderer.srcObject = null;
    _remoteRenderer.dispose();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return BlocBuilder<ReceiverCubit, ReceiverState>(
      bloc: _cubit,
      builder: (context, state) {
        _remoteRenderer.srcObject = state.remoteStream;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: RTCVideoView(
                        _remoteRenderer,
                        key: ValueKey(state.remoteStream.toString()),
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      )
                    //  Center(
                    //     child: Column(
                    //       mainAxisAlignment: MainAxisAlignment.center,
                    //       children: [
                    //         const Icon(
                    //           Icons.wifi_tethering,
                    //           color: Colors.white54,
                    //           size: 48,
                    //         ),
                    //         const SizedBox(height: 16),
                    //         Text(
                    //           state.isConnected
                    //               ? 'Подключено, ожидание видео потока...'
                    //               : 'Ожидание подключения...',
                    //           style: const TextStyle(
                    //             color: Colors.white54,
                    //             fontSize: 16,
                    //           ),
                    //         ),
                    //         const SizedBox(height: 8),
                    //         TextButton(
                    //           onPressed: _showConnectionStatus,
                    //           child: const Text(
                    //             'Показать статус подключения',
                    //             style: TextStyle(color: Colors.blue),
                    //           ),
                    //         ),
                    //       ],
                    //     ),
                    //   ),
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
                              Text(
                                'Camera',
                                style: AppTextStyles.lead
                                    .copyWith(color: Colors.white),
                              ),
                              if (state.connectedBroadcasters.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '📱 ${state.connectedBroadcasters.length}/7',
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
                          _buildQualityButton(context, 'Низкое', 'low', false),
                          _buildQualityButton(
                              context, 'Среднее', 'medium', true),
                          _buildQualityButton(
                              context, 'Высокое', 'high', false),
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
                    onPressed: () async {
                      await _cubit.close();
                      if (mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.1, vertical: 20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Image.asset(
                              'assets/icons/camera/_flash.png',
                              width: _getIconSize(context),
                              height: _getIconSize(context),
                              color: Colors.white,
                            ),
                            onPressed: () {
                              _cubit.sendCommand('flashlight');
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
                              _cubit.sendCommand('photo');
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
                              _cubit.sendCommand('timer');
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
                  onTap: _showConnectionStatus,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                          state.remoteStream != null
                              ? Icons.videocam
                              : Icons.videocam_off,
                          color: state.remoteStream != null
                              ? Colors.green
                              : Colors.red,
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

  Widget _buildQualityButton(
      BuildContext context, String text, String quality, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _cubit.sendCommand(quality);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Изменение качества на $text'),
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
