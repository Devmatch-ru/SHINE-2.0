import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:camera/camera.dart';
import '../utils/broadcaster_manager.dart';
import '../utils/video_size.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/broadcaster/broadcaster_cubit.dart';
import '../blocs/broadcaster/broadcaster_state.dart';

class BroadcasterScreen extends StatelessWidget {
  final String receiverUrl;

  const BroadcasterScreen({
    super.key,
    required this.receiverUrl,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BroadcasterCubit(receiverUrl: receiverUrl)..initialize(),
      child: const _BroadcasterScreenContent(),
    );
  }
}

class _BroadcasterScreenContent extends StatelessWidget {
  const _BroadcasterScreenContent();

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
                      : RTCVideoView(
                          context.read<BroadcasterCubit>().localRenderer,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 24),
                          Column(
                            children: [
                              Text(
                                state.connectedReceivers.isNotEmpty
                                    ? 'Подключено к: ${state.connectedReceivers.join(", ")}'
                                    : 'Ожидание подключения...',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18),
                              ),

                              // Индикатор энергосберегающего режима
                              if (state.isPowerSaveMode)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '🔋 Энергосбережение',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),

                              // Индикатор записи видео
                              if (state.isRecording)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '🔴 Запись видео',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          Row(
                            children: [
                              // Индикатор фонарика
                              BlocBuilder<BroadcasterCubit, BroadcasterState>(
                                builder: (context, state) {
                                  // Получаем состояние фонарика из cubit
                                  final isFlashOn = context
                                      .read<BroadcasterCubit>()
                                      .isFlashOn;

                                  return Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isFlashOn
                                          ? Colors.yellow.withOpacity(0.8)
                                          : Colors.grey.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.flashlight_on,
                                      color: isFlashOn
                                          ? Colors.black
                                          : Colors.white54,
                                      size: 20,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Timer overlay
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

                // Command message overlay
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

                // Bottom controls
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      FloatingActionButton(
                        heroTag: 'timer',
                        onPressed: state.isTimerActive
                            ? null
                            : () => context
                                .read<BroadcasterCubit>()
                                .startTimerCapture(),
                        backgroundColor:
                            state.isTimerActive ? Colors.grey : Colors.white,
                        child: const Icon(Icons.timer, color: Colors.black),
                      ),
                      FloatingActionButton(
                        heroTag: 'capture',
                        onPressed: state.isTimerActive
                            ? null
                            : () =>
                                context.read<BroadcasterCubit>().capturePhoto(),
                        backgroundColor:
                            state.isTimerActive ? Colors.grey : Colors.white,
                        child: const Icon(Icons.camera, color: Colors.black),
                      ),
                      FloatingActionButton(
                        heroTag: 'video',
                        onPressed: state.isTimerActive
                            ? null
                            : () => context
                                .read<BroadcasterCubit>()
                                .toggleRecording(),
                        backgroundColor: state.isRecording
                            ? Colors.red
                            : (state.isTimerActive
                                ? Colors.grey
                                : Colors.white),
                        child: Icon(
                          state.isRecording ? Icons.stop : Icons.videocam,
                          color:
                              state.isRecording ? Colors.white : Colors.black,
                        ),
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
}
