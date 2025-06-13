import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import './types.dart';

class WebRTCConnection {
  RTCPeerConnection? _pc;
  final List<RTCIceCandidate> _candidates = [];
  RTCSessionDescription? _offer;
  final List<RTCRtpSender> _senders = [];
  final Map<RTCPeerConnection, RTCDataChannel> _dataChannels = {};
  MediaStream? _remoteStream;
  final void Function(String) _onLog;
  final VoidCallback? onStateChange;
  final VoidCallback? onCapturePhoto;
  final VoidCallback? onStartVideo;
  final VoidCallback? onStopVideo;
  final void Function(RTCIceCandidate)? onIceCandidate;
  final void Function()? onConnectionFailed;
  final void Function(MediaType type, String base64Data)? onMediaReceived;
  final void Function(MediaStream)? onRemoteStream;

  WebRTCConnection({
    required void Function(String) onLog,
    this.onStateChange,
    this.onCapturePhoto,
    this.onStartVideo,
    this.onStopVideo,
    this.onIceCandidate,
    this.onConnectionFailed,
    this.onMediaReceived,
    this.onRemoteStream,
  }) : _onLog = onLog;

  RTCSessionDescription? get offer => _offer;
  List<RTCIceCandidate> get candidates => _candidates;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected =>
      _pc?.connectionState ==
      RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  Future<void> createConnection(MediaStream? localStream,
      {bool isBroadcaster = true}) async {
    try {
      _onLog('Creating WebRTC connection (isBroadcaster: $isBroadcaster)');

      final config = {
        'iceServers': [
          {
            'urls': [
              'stun:stun1.l.google.com:19302',
              'stun:stun2.l.google.com:19302',
            ],
          }
        ],
        'sdpSemantics': 'unified-plan',
        'iceTransportPolicy': 'all',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': true,
        },
      };

      _onLog('Creating peer connection with config: $config');
      _pc = await createPeerConnection(config);
      _setupConnectionHandlers();

      if (isBroadcaster && localStream != null) {
        _onLog('Adding tracks to connection...');
        final tracks = localStream.getTracks();
        _onLog('Local stream tracks: ${tracks.length}');

        for (var track in tracks) {
          _onLog(
              'Adding track: ${track.kind}, enabled: ${track.enabled}, muted: ${track.muted}');
          _onLog('Track settings: ${track.getSettings()}');
          var rtpSender = await _pc!.addTrack(track, localStream);
          _senders.add(rtpSender!);
        }

        _onLog('Creating offer...');
        _offer = await _pc!.createOffer({
          'offerToReceiveVideo': true,
          'offerToReceiveAudio': true,
          'voiceActivityDetection': true,
          'iceRestart': true,
        });

        _onLog('Setting local description...');
        await _pc!.setLocalDescription(_offer!);
        _onLog('Local description set successfully');

        final dataChannel = await _pc!.createDataChannel(
          'media',
          RTCDataChannelInit()
            ..ordered = true
            ..maxRetransmits = 30
            ..protocol = 'sctp'
            ..negotiated = false,
        );
        _dataChannels[_pc!] = dataChannel;
        _setupDataChannel(dataChannel);
        _onLog('Data channel created');
      }
    } catch (e) {
      _onLog('Error creating connection: $e');
      throw e;
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    channel.onMessage = (message) {
      if (message.type == MessageType.text) {
        try {
          if (message.text == 'capture_photo') {
            onCapturePhoto?.call();
          } else if (message.text == 'start_video') {
            onStartVideo?.call();
          } else if (message.text == 'stop_video') {
            onStopVideo?.call();
          } else {
            final data = jsonDecode(message.text);
            if (data['type'] == 'media') {
              onMediaReceived?.call(
                data['mediaType'] == 'photo'
                    ? MediaType.photo
                    : MediaType.video,
                data['data'],
              );
            }
          }
        } catch (e) {
          _onLog('Error processing message: $e');
        }
      }
    };
  }

  Future<bool> sendMedia(MediaType type, XFile media) async {
    try {
      final bytes = await media.readAsBytes();
      final base64Data = base64Encode(bytes);

      for (var channel in _dataChannels.values) {
        if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
          await channel.send(RTCDataChannelMessage(jsonEncode({
            'type': 'media',
            'mediaType': type == MediaType.photo ? 'photo' : 'video',
            'data': base64Data,
          })));
        }
      }
      return true;
    } catch (e) {
      _onLog('Error sending media: $e');
      return false;
    }
  }

  void _setupConnectionHandlers() {
    _pc!.onConnectionState = (state) {
      _onLog('Connection state changed to: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _onLog('Successfully connected');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _onLog('Connection failed or disconnected');
        onConnectionFailed?.call();
      }
      onStateChange?.call();
    };

    _pc!.onIceConnectionState = (state) {
      _onLog('ICE connection state changed to: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _onLog('ICE connection failed');
        onConnectionFailed?.call();
      }
    };

    _pc!.onIceGatheringState = (state) {
      _onLog('ICE gathering state changed to: $state');
    };

    _pc!.onIceCandidate = (candidate) {
      if (candidate != null) {
        _onLog('New ICE candidate: ${candidate.candidate}');
        _candidates.add(candidate);
        onIceCandidate?.call(candidate);
      } else {
        _onLog('ICE gathering completed');
      }
    };

    _pc!.onTrack = (event) {
      _onLog('Track received: ${event.track.kind}');
      _onLog(
          'Track enabled: ${event.track.enabled}, muted: ${event.track.muted}');
      _onLog('Track settings: ${event.track.getSettings()}');
      _onLog('Streams count: ${event.streams.length}');

      if (event.track.kind == 'video') {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _onLog('Remote stream set with ID: ${_remoteStream!.id}');
          _onLog('Remote stream active: ${_remoteStream!.active}');
          _onLog('Remote stream tracks: ${_remoteStream!.getTracks().length}');
          onRemoteStream?.call(_remoteStream!);
        } else {
          _onLog('Warning: Received video track without stream');
        }
      }
    };

    _pc!.onDataChannel = (channel) {
      _onLog('Data channel received');
      _dataChannels[_pc!] = channel;
      _setupDataChannel(channel);
    };
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');
      _onLog('Setting remote description (answer)...');

      if (_pc!.signalingState !=
          RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        _onLog(
            'Warning: Unexpected signaling state for answer: ${_pc!.signalingState}');
      }

      await _pc!.setRemoteDescription(answer);
      _onLog('Remote description set successfully');

      for (var candidate in _candidates) {
        _onLog('Adding pending ICE candidate: ${candidate.candidate}');
        await _pc!.addCandidate(candidate);
      }
      _candidates.clear();
    } catch (e) {
      _onLog('Error handling answer: $e');
      throw e;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_pc == null) throw Exception('PeerConnection not initialized');

    try {
      _onLog('Creating answer...');
      final answer = await _pc!.createAnswer({
        'offerToReceiveVideo': true,
        'offerToReceiveAudio': true,
        'voiceActivityDetection': true,
      });

      _onLog('Setting local description (answer)...');
      await _pc!.setLocalDescription(answer);

      return answer;
    } catch (e) {
      _onLog('Error creating answer: $e');
      throw e;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _pc?.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');
      _onLog('Adding ICE candidate: ${candidate.candidate}');
      await _pc!.addCandidate(candidate);
      _onLog('ICE candidate added successfully');
    } catch (e) {
      _onLog('Error adding ICE candidate: $e');
      throw e;
    }
  }

  Future<void> updateTrack(MediaStreamTrack newTrack) async {
    var sender = _senders
        .firstWhereOrNull((sender) => sender.track?.kind == newTrack.kind);
    if (sender != null) {
      var params = sender.parameters;
      params.degradationPreference =
          RTCDegradationPreference.MAINTAIN_RESOLUTION;
      await sender.setParameters(params);
      await sender.replaceTrack(newTrack);
      _onLog('Track replaced: ${newTrack.kind}');
    }
  }

  Future<void> close() async {
    _onLog('Closing WebRTC connection...');
    for (var channel in _dataChannels.values) {
      _onLog('Closing data channel');
      await channel.close();
    }
    _dataChannels.clear();

    if (_remoteStream != null) {
      _onLog('Cleaning up remote stream');
      _remoteStream!.getTracks().forEach((track) {
        _onLog('Stopping track: ${track.kind}');
        track.stop();
      });
      _remoteStream = null;
    }

    if (_pc != null) {
      _onLog('Closing peer connection');
      await _pc!.close();
      _pc = null;
    }
    _onLog('WebRTC connection closed');
  }
}
