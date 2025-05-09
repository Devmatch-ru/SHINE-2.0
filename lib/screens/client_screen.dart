// import 'package:flutter/material.dart';
// import 'package:flutter_webrtc/flutter_webrtc.dart';
// import '../services/webrtc_service.dart';
// import '../services/signaling_service.dart';
// import '../widgets/video_view.dart';
// import '../utils/constants.dart';
//
// class ClientScreen extends StatefulWidget {
//   const ClientScreen({super.key});
//
//   @override
//   _ClientScreenState createState() => _ClientScreenState();
// }
//
// class _ClientScreenState extends State<ClientScreen> {
//   MediaStream? _localStream;
//   MediaStream? _remoteStream;
//   RTCPeerConnection? _peerConnection;
//
//   @override
//   void initState() {
//     super.initState();
//     _initSession();
//   }
//
//   Future<void> _initSession() async {
//     _localStream = await WebRtcService.instance.initializeLocalStream();
//     await SignalingService.instance.connect(
//       role: 'client',
//       roomId: Constants.defaultRoomId,
//     );
//     _peerConnection = await WebRtcService.instance.createPeerConnection(_localStream!);
//     _peerConnection?.onTrack = (event) {
//       setState(() => _remoteStream = event.streams.first);
//     };
//   }
//
//   @override
//   void dispose() {
//     _peerConnection?.close();
//     SignalingService.instance.disconnect();
//     _localStream?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Client')),
//       body: _remoteStream != null
//           ? VideoView(stream: _remoteStream)
//           : Center(child: Text('Waiting for host...')),
//     );
//   }
// }
