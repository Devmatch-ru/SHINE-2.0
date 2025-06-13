import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:camera/camera.dart';
import '../utils/broadcaster_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/broadcaster/broadcaster_cubit.dart';
import '../blocs/broadcaster/broadcaster_state.dart';

class BroadcasterScreen extends StatefulWidget {
  final String receiverUrl;

  const BroadcasterScreen({super.key, required this.receiverUrl});

  @override
  _BroadcasterScreenState createState() => _BroadcasterScreenState();
}

class _BroadcasterScreenState extends State<BroadcasterScreen> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  bool _isTimerActive = false;
  int _countdown = 3;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _localRenderer.initialize();
    context.read<BroadcasterCubit>().initialize();
  }

  void _startTimerCapture() {
    if (_isTimerActive) return;

    setState(() {
      _isTimerActive = true;
      _countdown = 3;
    });

    Future.doWhile(() async {
      if (_countdown == 0) {
        await context.read<BroadcasterCubit>().capturePhoto();
        setState(() => _isTimerActive = false);
        return false;
      }
      await Future.delayed(Duration(seconds: 1));
      setState(() => _countdown--);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: BlocBuilder<BroadcasterCubit, BroadcasterState>(
          builder: (context, state) {
            if (state is BroadcasterLoading) {
              return Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (state is BroadcasterError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    SizedBox(height: 16),
                    Text(
                      state.message,
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            if (state is BroadcasterReady) {
              // Update local renderer
              if (_localRenderer.srcObject != state.localStream) {
                _localRenderer.srcObject = state.localStream;
              }

              return Stack(
                children: [
                  // Full-screen video view
                  Positioned.fill(
                    child: RTCVideoView(
                      _localRenderer,
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
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: Icon(
                                state.isBroadcasting
                                    ? Icons.cast_connected
                                    : Icons.cast,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                if (state.isBroadcasting) {
                                  context
                                      .read<BroadcasterCubit>()
                                      .stopBroadcast();
                                } else {
                                  context
                                      .read<BroadcasterCubit>()
                                      .startBroadcast(widget.receiverUrl);
                                }
                              },
                            ),
                            Text(
                              state.isBroadcasting
                                  ? 'Подключено к: ${state.connectedReceiver}'
                                  : 'Камера',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 18),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Quality selector
                  Positioned(
                    top: 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PopupMenuButton<String>(
                              onSelected: (deviceId) => context
                                  .read<BroadcasterCubit>()
                                  .selectVideoInput(deviceId),
                              icon: const Icon(
                                Icons.switch_camera,
                                color: Colors.white,
                              ),
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: 'front',
                                  child: Text('Фронтальная камера'),
                                ),
                                PopupMenuItem<String>(
                                  value: 'back',
                                  child: Text('Задняя камера'),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (fps) => context
                                  .read<BroadcasterCubit>()
                                  .selectVideoFps(fps),
                              icon: const Icon(Icons.menu, color: Colors.white),
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: '30',
                                  child: Text('30 FPS'),
                                ),
                                PopupMenuItem<String>(
                                  value: '60',
                                  child: Text('60 FPS'),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (size) => context
                                  .read<BroadcasterCubit>()
                                  .selectVideoSize(size),
                              icon: const Icon(
                                Icons.screenshot_monitor,
                                color: Colors.white,
                              ),
                              itemBuilder: (context) => [
                                PopupMenuItem<String>(
                                  value: '1280x720',
                                  child: Text('HD (720p)'),
                                ),
                                PopupMenuItem<String>(
                                  value: '1920x1080',
                                  child: Text('Full HD (1080p)'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bottom control panel
                  Positioned(
                    bottom: 30,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        // Control buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            FloatingActionButton(
                              heroTag: 'photo',
                              onPressed: () => context
                                  .read<BroadcasterCubit>()
                                  .capturePhoto(),
                              backgroundColor: Colors.white,
                              child:
                                  Icon(Icons.camera_alt, color: Colors.black),
                            ),
                            FloatingActionButton(
                              heroTag: 'video',
                              onPressed: () => context
                                  .read<BroadcasterCubit>()
                                  .toggleVideoRecording(),
                              backgroundColor:
                                  state.isRecording ? Colors.red : Colors.white,
                              child: Icon(
                                state.isRecording ? Icons.stop : Icons.videocam,
                                color: state.isRecording
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                            FloatingActionButton(
                              heroTag: 'timer',
                              onPressed: _startTimerCapture,
                              backgroundColor:
                                  _isTimerActive ? Colors.amber : Colors.white,
                              child: _isTimerActive
                                  ? Text(
                                      '$_countdown',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : Icon(Icons.timer, color: Colors.black),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return Container(); // Fallback
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    super.dispose();
  }
}
