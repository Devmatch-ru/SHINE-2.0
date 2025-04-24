import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../services/webrtc_service.dart';
import '../services/signaling_service.dart';
import '../widgets/video_view.dart';
import '../widgets/capture_button.dart';
import '../utils/constants.dart';

class HostScreen extends StatefulWidget {
  @override
  _HostScreenState createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  MediaStream? _localStream;
  RTCPeerConnection? _peerConnection;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  Future<void> _setupStream() async {
    _localStream = await WebRtcService.instance.initializeLocalStream();
    setState(() {});
  }

  Future<void> _startSession() async {
    await SignalingService.instance.connect(
      role: 'host',
      roomId: Constants.defaultRoomId,
    );
    _peerConnection = await WebRtcService.instance.createPeerConnection(_localStream!);
    setState(() => _connected = true);
  }

  Future<void> _capture() async {
    // TODO: send capture request and gather client responses
  }

  @override
  void dispose() {
    _peerConnection?.close();
    SignalingService.instance.disconnect();
    _localStream?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Host')),
      body: Column(children: [
        Expanded(child: VideoView(stream: _localStream)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          ElevatedButton(
            onPressed: _connected ? null : _startSession,
            child: Text('Start'),
          ),
          SizedBox(width: 16),
          CaptureButton(onPressed: _connected ? _capture : null),
        ]),
      ]),
    );
  }
}
