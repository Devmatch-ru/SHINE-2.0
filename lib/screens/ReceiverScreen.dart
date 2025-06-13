import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../blocs/receiver/receiver_cubit.dart';
import '../blocs/receiver/receiver_state.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  _ReceiverScreenState createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen>
    with WidgetsBindingObserver {
  final Map<String, RTCVideoRenderer> _renderers = {};
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _startListening();
        break;
      case AppLifecycleState.paused:
        _cleanupRenderers();
        break;
      default:
        break;
    }
  }

  void _startListening() {
    if (!_isDisposed) {
      context.read<ReceiverCubit>().startListening();
    }
  }

  Future<void> _initRenderer(String broadcasterId, MediaStream stream) async {
    if (_isDisposed) return;

    if (!_renderers.containsKey(broadcasterId)) {
      try {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        if (_isDisposed || !mounted) return;

        renderer.onFirstFrameRendered = () {
          print('First frame rendered for broadcaster: $broadcasterId');
        };

        // Set stream directly without null transition
        renderer.srcObject = stream;

        if (_isDisposed || !mounted) {
          renderer.dispose();
          return;
        }

        setState(() {
          _renderers[broadcasterId] = renderer;
        });
      } catch (e) {
        print('Error initializing renderer for $broadcasterId: $e');
        // Try to recover by removing the problematic renderer
        _removeRenderer(broadcasterId);
      }
    } else {
      final renderer = _renderers[broadcasterId]!;
      if (renderer.srcObject != stream) {
        renderer.srcObject = stream;
      }
    }
  }

  void _removeRenderer(String broadcasterId) {
    final renderer = _renderers.remove(broadcasterId);
    if (renderer != null) {
      renderer.srcObject = null;
      renderer.dispose();
    }
  }

  void _cleanupRenderers() {
    for (var renderer in _renderers.values) {
      renderer.srcObject = null;
      renderer.dispose();
    }
    _renderers.clear();
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _cleanupRenderers();
    super.dispose();
  }

  Widget _buildVideoView(String broadcasterId, RTCVideoRenderer renderer) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: false,
              filterQuality: FilterQuality.medium,
            ),
          ),
          _buildVideoOverlay(broadcasterId),
        ],
      ),
    );
  }

  Widget _buildVideoOverlay(String broadcasterId) {
    return Stack(
      children: [
        // Broadcaster info
        Positioned(
          top: 8,
          left: 8,
          right: 8,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Broadcaster: $broadcasterId',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
        // Control buttons
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'photo_$broadcasterId',
                mini: true,
                onPressed: () =>
                    context.read<ReceiverCubit>().requestPhoto(broadcasterId),
                backgroundColor: Colors.white,
                child: Icon(Icons.camera_alt, color: Colors.black),
              ),
              FloatingActionButton(
                heroTag: 'video_$broadcasterId',
                mini: true,
                onPressed: () =>
                    context.read<ReceiverCubit>().requestVideo(broadcasterId),
                backgroundColor: Colors.white,
                child: Icon(Icons.videocam, color: Colors.black),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: BlocBuilder<ReceiverCubit, ReceiverState>(
          builder: (context, state) {
            return Stack(
              children: [
                // Main content
                _buildMainContent(state),

                // Debug logs overlay
                if (kDebugMode) _buildDebugOverlay(state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainContent(ReceiverState state) {
    if (state is ReceiverLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (state is ReceiverError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              state.message,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (state is ReceiverListening) {
      // Handle renderer updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateRenderers(state);
      });

      if (state.connectedBroadcasters.isEmpty) {
        return _buildWaitingView();
      }

      return Stack(
        children: [
          _buildVideoGrid(state),
          _buildTopBar(state),
        ],
      );
    }

    return Container();
  }

  Widget _buildDebugOverlay(ReceiverState state) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.2),
            ),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Debug Logs',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'State: ${state.runtimeType}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                reverse: true,
                itemCount: state.debugLogs.length,
                itemBuilder: (context, index) {
                  final log = state.debugLogs[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: log.contains('Error') || log.contains('error')
                            ? Colors.red[300]
                            : Colors.white.withOpacity(0.7),
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
  }

  void _updateRenderers(ReceiverListening state) {
    if (_isDisposed) return;

    // Add new renderers
    for (var broadcasterId in state.broadcasterStreams.keys) {
      if (!_renderers.containsKey(broadcasterId)) {
        _initRenderer(broadcasterId, state.broadcasterStreams[broadcasterId]!);
      }
    }

    // Remove disconnected renderers
    for (var broadcasterId in _renderers.keys.toList()) {
      if (!state.broadcasterStreams.containsKey(broadcasterId)) {
        _removeRenderer(broadcasterId);
      }
    }
  }

  Widget _buildWaitingView() {
    return Center(
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
    );
  }

  Widget _buildVideoGrid(ReceiverListening state) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: state.connectedBroadcasters.length == 1 ? 1 : 2,
        childAspectRatio: 9 / 16,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: state.connectedBroadcasters.length,
      itemBuilder: (context, index) {
        final broadcasterId = state.connectedBroadcasters[index];
        final renderer = _renderers[broadcasterId];
        final stream = state.broadcasterStreams[broadcasterId];

        if (renderer == null || stream == null) {
          return Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        return _buildVideoView(broadcasterId, renderer);
      },
    );
  }

  Widget _buildTopBar(ReceiverListening state) {
    return Positioned(
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
              const SizedBox(width: 24),
              Text(
                'Подключено: ${state.connectedBroadcasters.length}',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
