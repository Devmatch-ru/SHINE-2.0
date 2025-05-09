import 'package:flutter_webrtc/flutter_webrtc.dart';

abstract class WebRtcService {
  Future<MediaStream> initializeLocalStream({bool useFrontCamera});
  Future<RTCPeerConnection> createPeerConnection(MediaStream stream);

  static final WebRtcService instance = _WebRtcServiceImpl();
}

class _WebRtcServiceImpl implements WebRtcService {
  @override
  Future<MediaStream> initializeLocalStream({bool useFrontCamera = false}) async {
    final constraints = {
      'video': {'facingMode': useFrontCamera ? 'user' : 'environment'},
      'audio': false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  @override
  Future<RTCPeerConnection> createPeerConnection(MediaStream stream) async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };
    final pc = await createPeerConnection(config as MediaStream);
    for (var track in stream.getTracks()) {
      pc.addTrack(track, stream);
    }
    return pc;
  }
}
