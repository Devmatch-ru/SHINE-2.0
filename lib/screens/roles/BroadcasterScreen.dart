import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:shine/theme/app_constant.dart';
import 'dart:ui' as ui;

import '../../blocs/broadcaster/broadcaster_cubit.dart';
import '../../blocs/broadcaster/broadcaster_state.dart';
import '../../utils/service/error_handling_service.dart';
import '../../utils/service/logging_service.dart';

class BroadcasterScreen extends StatefulWidget {
  final String receiverUrl;

  const BroadcasterScreen({
    Key? key,
    required this.receiverUrl,
  }) : super(key: key);

  @override
  State<BroadcasterScreen> createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> with LoggerMixin, TickerProviderStateMixin {
  @override
  String get loggerContext => 'BroadcasterScreen';

  late BroadcasterCubit _cubit;
  Timer? _connectionStatusTimer;
  bool _showControls = true;
  Timer? _controlsTimer;
  bool _isPrimaryBroadcaster = true; // Флаг для определения является ли устройство основным

  // Animations
  late AnimationController _connectionAnimationController;
  late AnimationController _controlsAnimationController;
  late Animation<double> _connectionAnimation;
  late Animation<double> _controlsAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _connectionAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _connectionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _connectionAnimationController, curve: Curves.easeInOut),
    );
    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controlsAnimationController, curve: Curves.easeInOut),
    );

    logInfo('Creating BroadcasterCubit for receiver: ${widget.receiverUrl}');
    _cubit = BroadcasterCubit(receiverUrl: widget.receiverUrl);
    _initializeBroadcaster();
    _startControlsTimer();
  }

  void _initializeBroadcaster() async {
    try {
      await _cubit.initialize();
      // Автоматически начинаем трансляцию после инициализации
      await _cubit.startBroadcast();
      _connectionAnimationController.forward();
    } catch (e, stackTrace) {
      logError('Error initializing broadcaster: $e', stackTrace);
      if (mounted) {
        _showErrorDialog('Ошибка инициализации: $e');
      }
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void showControls() {
    if (!_showControls) {
      setState(() {
        _showControls = true;
      });
      _controlsAnimationController.forward();
    }
    _controlsTimer?.cancel();
    _startControlsTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: BlocProvider(
        create: (context) => _cubit,
        child: BlocConsumer<BroadcasterCubit, BroadcasterState>(
          listener: (context, state) {
            _handleStateChange(state);
          },
          builder: (context, state) {
            return GestureDetector(
              onTap: showControls,
              child: Stack(
                children: [
                  // Видео превью
                  _buildVideoPreview(state),

                  // Статус соединения
                  _buildConnectionStatus(state),

                  // Индикатор множественного подключения
                  if (state is BroadcasterConnected ||
                      (state is BroadcasterReady && state.isConnected))
                    _buildMultiConnectionIndicator(state),

                  // Элементы управления
                  if (_showControls)
                    AnimatedBuilder(
                      animation: _controlsAnimation,
                      builder: (context, child) {
                        return AnimatedOpacity(
                          opacity: _controlsAnimation.value,
                          duration: const Duration(milliseconds: 300),
                          child: _buildControls(state),
                        );
                      },
                    ),

                  // Загрузка
                  if (state is BroadcasterInitializing || state is BroadcasterConnecting)
                    _buildLoadingOverlay(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleStateChange(BroadcasterState state) {
    if (state is BroadcasterError) {
      // Фильтруем ошибки - не показываем "Соединение потеряно" если есть другие подключения
      if (!state.error.contains('Соединение потеряно') ||
          _cubit.manager.connectedReceivers.isEmpty) {
        _showErrorDialog(state.error);
      }
    } else if (state is BroadcasterConnected) {
      _connectionAnimationController.forward();
      // Проверяем, являемся ли мы основным broadcaster
      _checkPrimaryStatus();
    } else if (state is BroadcasterReady && state.isConnected) {
      _connectionAnimationController.forward();
      _checkPrimaryStatus();
    }
  }

  void _checkPrimaryStatus() {
    // Логика определения основного broadcaster
    // Можно определить по ID или порядку подключения
    final broadcasterId = _cubit.manager.broadcasterId;
    logInfo('Checking primary status for broadcaster: $broadcasterId');

    // Предполагаем, что первый подключившийся становится основным
    // Или можно получить эту информацию от receiver
    setState(() {
      _isPrimaryBroadcaster = true; // Пока что считаем всех основными
    });
  }

  Widget _buildVideoPreview(BroadcasterState state) {
    // Показываем видео превью для всех broadcaster'ов
    if (state is BroadcasterReady && state.localStream != null) {
      return Positioned.fill(
        child: RTCVideoView(
          _cubit.localRenderer,
          mirror: false, // Задняя камера не зеркалится
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    } else if (state is BroadcasterConnected && state.localStream != null) {
      return Positioned.fill(
        child: RTCVideoView(
          _cubit.localRenderer,
          mirror: false,
          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
        ),
      );
    }

    // Показываем заглушку если камера недоступна
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.videocam_off,
                color: Colors.white54,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Камера недоступна',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(BroadcasterState state) {
    String statusText = '';
    Color statusColor = Colors.red;
    IconData statusIcon = Icons.signal_wifi_off;

    if (state is BroadcasterReady) {
      if (state.isConnected) {
        statusText = 'Подключено';
        statusColor = Colors.green;
        statusIcon = Icons.signal_wifi_4_bar;
      } else {
        statusText = state.connectionStatus ?? 'Готов к подключению';
        statusColor = Colors.orange;
        statusIcon = Icons.signal_wifi_0_bar;
      }
    } else if (state is BroadcasterConnecting) {
      statusText = 'Подключение...';
      statusColor = Colors.yellow;
      statusIcon = Icons.signal_wifi_0_bar;
    } else if (state is BroadcasterConnected) {
      statusText = 'Подключено';
      statusColor = Colors.green;
      statusIcon = Icons.signal_wifi_4_bar;
    } else if (state is BroadcasterError) {
      statusText = 'Ошибка';
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return AnimatedBuilder(
      animation: _connectionAnimation,
      builder: (context, child) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: Transform.scale(
            scale: 0.8 + (_connectionAnimation.value * 0.2),
            child: AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.3,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: statusColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultiConnectionIndicator(BroadcasterState state) {
    final connectedCount = _cubit.manager.connectedReceivers.length;

    if (connectedCount == 0) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cast_connected,
                color: Colors.white,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Трансляция активна',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!_isPrimaryBroadcaster) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 12,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(BroadcasterState state) {
    final isReady = state is BroadcasterReady || state is BroadcasterConnected;
    final isConnected = (state is BroadcasterReady && state.isConnected) ||
        state is BroadcasterConnected;
    final isRecording = state is BroadcasterReady && state.isRecording;
    final isFlashOn = state is BroadcasterReady && state.isFlashOn;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: MediaQuery.of(context).padding.bottom + 32,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Основные кнопки управления
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Кнопка фонарика
              _buildControlButton(
                icon: isFlashOn ? Icons.flash_on : Icons.flash_off,
                onPressed: isReady ? () => _cubit.toggleFlash() : null,
                backgroundColor: isFlashOn ? Colors.yellow : Colors.black54,
                iconColor: isFlashOn ? Colors.black : Colors.white,
              ),

              // Кнопка фото
              _buildControlButton(
                icon: Icons.camera_alt,
                onPressed: isConnected ? () => _cubit.capturePhoto() : null,
                backgroundColor: isConnected ? Colors.white : Colors.black54,
                iconColor: isConnected ? Colors.black : Colors.white,
                size: 64,
              ),

              // Кнопка записи видео
              _buildControlButton(
                icon: isRecording ? Icons.stop : Icons.videocam,
                onPressed: isConnected ? () => _cubit.toggleRecording() : null,
                backgroundColor: isRecording ? Colors.red : Colors.black54,
                iconColor: Colors.white,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Дополнительные кнопки
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Кнопка фото с таймером
              _buildSmallControlButton(
                icon: Icons.timer,
                label: 'Таймер',
                onPressed: isConnected ? () => _cubit.captureWithTimer() : null,
              ),

              // Индикатор статуса подключения
              _buildSmallControlButton(
                icon: isConnected ? Icons.cast_connected : Icons.cast,
                label: isConnected ? 'Активна' : 'Не подключено',
                onPressed: null, // Информационная кнопка
              ),

              // Кнопка выхода
              _buildSmallControlButton(
                icon: Icons.close,
                label: 'Выход',
                onPressed: () => _handleExit(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color backgroundColor,
    required Color iconColor,
    double size = 56,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(size / 2),
          onTap: onPressed,
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.4,
          ),
        ),
      ),
    );
  }

  Widget _buildSmallControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: onPressed != null ? Colors.black54 : Colors.black26,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: onPressed != null ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: onPressed != null ? Colors.white : Colors.white54,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: onPressed != null ? Colors.white : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(BroadcasterState state) {
    String message = '';
    if (state is BroadcasterInitializing) {
      message = 'Инициализация камеры...';
    } else if (state is BroadcasterConnecting) {
      message = 'Подключение к приемнику...';
    }

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String error) {
    // Не показываем диалог ошибки если это проблема с множественным подключением
    if (error.contains('Соединение потеряно') && _cubit.manager.connectedReceivers.isNotEmpty) {
      logInfo('Connection lost but other receivers still connected, ignoring error dialog');
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (error.contains('инициализации') || error.contains('критическая')) {
                _handleExit();
              }
            },
            child: const Text('OK'),
          ),
          if (!error.contains('инициализации'))
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _retryConnection();
              },
              child: const Text('Повторить'),
            ),
        ],
      ),
    );
  }

  void _retryConnection() {
    logInfo('Retrying connection...');
    _initializeBroadcaster();
  }

  void _handleExit() async {
    try {
      await _cubit.stopBroadcast();
    } catch (e) {
      logError('Error stopping broadcast: $e');
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    logInfo('Disposing broadcaster screen');
    _connectionStatusTimer?.cancel();
    _controlsTimer?.cancel();
    _connectionAnimationController.dispose();
    _controlsAnimationController.dispose();
    _cubit.close();
    super.dispose();
  }
}