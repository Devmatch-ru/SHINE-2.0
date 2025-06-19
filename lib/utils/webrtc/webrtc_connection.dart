import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import './types.dart';

class WebRTCConnection {
  static const int _maxChunkSize = 16 * 1024; // 16KB chunks
  static const int _maxRetries = 3;
  static const int _chunkDelayMs = 50;
  static const int _retryDelayBaseMs = 100;

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
  final void Function(String command)? onCommandReceived;
  final void Function(String quality)? onQualityChangeRequested;
  final void Function(String fileName, String mediaType, int sentChunks,
      int totalChunks, bool isCompleted)? onTransferProgress;

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
    this.onCommandReceived,
    this.onQualityChangeRequested,
    this.onTransferProgress,
  }) : _onLog = onLog;

  RTCSessionDescription? get offer => _offer;
  List<RTCIceCandidate> get candidates => _candidates;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected {
    final isConnected = _pc?.connectionState ==
        RTCPeerConnectionState.RTCPeerConnectionStateConnected;
    final hasOpenDataChannel = _dataChannels.values.any(
        (channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);
    return isConnected && hasOpenDataChannel;
  }

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
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
        'iceCandidatePoolSize': 0,
        'enableDtlsSrtp': true,
        'optional': [
          {'DtlsSrtpKeyAgreement': true},
        ]
      };

      _onLog('Initializing peer connection with config: $config');
      _pc = await createPeerConnection(config);
      _onLog('Peer connection created successfully');
      _setupConnectionHandlers();

      if (isBroadcaster && localStream != null) {
        _onLog('Adding tracks to connection...');
        final tracks = localStream.getTracks();
        _onLog('Local stream tracks: ${tracks.length}');

        for (var track in tracks) {
          _onLog('Adding track: ${track.kind}, enabled: ${track.enabled}');
          var rtpSender = await _pc!.addTrack(track, localStream);
          _senders.add(rtpSender!);
        }

        _onLog('Creating reliable data channel for commands...');
        final dataChannel = await _pc!.createDataChannel(
          'commands',
          RTCDataChannelInit()
            ..ordered = true
            ..maxRetransmits = 0
            ..protocol = 'sctp'
            ..negotiated = true
            ..id = 1,
        );

        _dataChannels[_pc!] = dataChannel;
        _setupDataChannel(dataChannel);

        _onLog('Creating optimized offer...');
        _offer = await _pc!.createOffer({
          'offerToReceiveVideo': true,
          'offerToReceiveAudio': false,
        });

        var sdp = _offer!.sdp;
        sdp = _modifySdpForLowLatency(sdp!);
        _onLog('Modified SDP for low latency: $sdp');
        await _pc!
            .setLocalDescription(RTCSessionDescription(sdp, _offer!.type));
        _onLog('Local description set for broadcaster');
      } else {
        _onLog('Setting up as receiver...');
        await _pc!.createOffer({
          'offerToReceiveVideo': true,
          'offerToReceiveAudio': true,
        });
        _onLog('Receiver offer created');
      }
    } catch (e) {
      _onLog('Error creating connection: $e');
      throw e;
    }
  }

  String _modifySdpForLowLatency(String sdp) {
    var lines = sdp.split('\r\n');
    var newLines = <String>[];
    bool isVideoSection = false;

    for (var line in lines) {
      if (line.startsWith('m=video')) {
        isVideoSection = true;
        newLines.add(line);
        newLines.add('b=AS:2500');
        newLines.add('a=content:main');
        continue;
      }

      if (isVideoSection && line.startsWith('a=fmtp:')) {
        if (line.contains('VP8')) {
          newLines.add('$line;max-fs=12288;max-fr=30');
          continue;
        } else if (line.contains('H264')) {
          newLines.add('$line;profile-level-id=42e01f;packetization-mode=1');
          continue;
        }
      }

      if (line.startsWith('m=audio')) {
        isVideoSection = false;
      }

      newLines.add(line);
    }

    return newLines.join('\r\n');
  }

  void _setupDataChannel(RTCDataChannel channel) {
    _onLog('Setting up data channel: ${channel.label}');

    channel.onDataChannelState = (state) {
      _onLog('Data channel state changed to: $state');
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _onLog('Data channel is now OPEN and ready for communication');
        _sendTestMessage(channel);
      } else if (state == RTCDataChannelState.RTCDataChannelClosed ||
          state == RTCDataChannelState.RTCDataChannelClosing) {
        _onLog('Data channel is closing/closed');
        if (_pc?.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _recreateDataChannel();
        }
      }
    };

    channel.onMessage = (message) {
      if (message.type == MessageType.text) {
        try {
          _onLog('Received message: ${message.text}');
          final data = jsonDecode(message.text);

          if (data['type'] == 'command') {
            final command = data['action'];
            _onLog('Received command: $command');
            onCommandReceived?.call(command);

            switch (command) {
              case 'capture_photo':
                onCapturePhoto?.call();
                break;
              case 'toggle_video':
                break;
              case 'toggle_flashlight':
                break;
              case 'start_timer':
                break;
            }
          } else if (data['type'] == 'quality_change') {
            final quality = data['quality'];
            _onLog('Received quality change request: $quality');
            onQualityChangeRequested?.call(quality);
          } else if (data['type'] == 'media') {
            onMediaReceived?.call(
              data['mediaType'] == 'photo' ? MediaType.photo : MediaType.video,
              data['data'],
            );
          }
        } catch (e) {
          _onLog('Error processing message: $e');
        }
      }
    };
  }

  Future<void> _recreateDataChannel() async {
    try {
      _onLog('Attempting to recreate data channel...');

      for (var channel in _dataChannels.values) {
        await channel.close();
      }
      _dataChannels.clear();

      int attempts = 0;
      const maxAttempts = 3;
      bool success = false;

      while (!success && attempts < maxAttempts) {
        try {
          final dataChannel = await _pc!.createDataChannel(
            'commands',
            RTCDataChannelInit()
              ..ordered = true
              ..maxRetransmits = 3
              ..protocol = 'sctp'
              ..negotiated = false,
          );

          _dataChannels[_pc!] = dataChannel;
          _setupDataChannel(dataChannel);

          int waitAttempts = 0;
          while (dataChannel.state != RTCDataChannelState.RTCDataChannelOpen &&
              waitAttempts < 50) {
            await Future.delayed(const Duration(milliseconds: 100));
            waitAttempts++;
          }

          if (dataChannel.state == RTCDataChannelState.RTCDataChannelOpen) {
            _onLog('Data channel recreated and opened successfully');
            success = true;
          } else {
            throw Exception('Data channel did not open in time');
          }
        } catch (e) {
          attempts++;
          _onLog('Attempt $attempts failed: $e');
          if (attempts < maxAttempts) {
            await Future.delayed(Duration(seconds: attempts));
          }
        }
      }

      if (!success) {
        _onLog('Failed to recreate data channel after $maxAttempts attempts');
        onConnectionFailed?.call();
      }
    } catch (e) {
      _onLog('Error recreating data channel: $e');
      onConnectionFailed?.call();
    }
  }

  Future<void> _sendTestMessage(RTCDataChannel channel) async {
    try {
      final testMessage = jsonEncode({
        'type': 'test',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await channel.send(RTCDataChannelMessage(testMessage));
      _onLog('Test message sent successfully');
    } catch (e) {
      _onLog('Error sending test message: $e');
    }
  }

  Future<bool> sendMedia(MediaType type, XFile media) async {
    try {
      final bytes = await media.readAsBytes();
      final int totalChunks = (bytes.length / _maxChunkSize).ceil();

      _onLog('Sending ${type.name} in $totalChunks chunks...');

      final metadataMessage = jsonEncode({
        'type': 'media_metadata',
        'mediaType': type == MediaType.photo ? 'photo' : 'video',
        'fileName': media.name,
        'fileSize': bytes.length,
        'totalChunks': totalChunks,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      bool sentToAny = false;

      for (var channel in _dataChannels.values) {
        if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
          try {
            await channel.send(RTCDataChannelMessage(metadataMessage));
            _onLog('Sent metadata for ${type.name}');

            for (var i = 0; i < totalChunks; i++) {
              var retryCount = 0;
              bool chunkSent = false;

              while (!chunkSent && retryCount < _maxRetries) {
                try {
                  final start = i * _maxChunkSize;
                  final end = (i + 1) * _maxChunkSize;
                  final chunk = bytes.sublist(
                      start, end > bytes.length ? bytes.length : end);

                  await channel.send(RTCDataChannelMessage.fromBinary(chunk));
                  _onLog('Sent chunk ${i + 1}/$totalChunks');

                  onTransferProgress?.call(
                    media.name,
                    type == MediaType.photo ? 'photo' : 'video',
                    i + 1,
                    totalChunks,
                    i + 1 == totalChunks,
                  );

                  chunkSent = true;
                } catch (e) {
                  retryCount++;
                  _onLog(
                      'Error sending chunk ${i + 1}, attempt $retryCount: $e');

                  if (retryCount >= _maxRetries) {
                    throw Exception(
                        'Failed to send chunk after $_maxRetries attempts');
                  }

                  await Future.delayed(
                      Duration(milliseconds: _retryDelayBaseMs * retryCount));
                }
              }

              await Future.delayed(Duration(milliseconds: _chunkDelayMs));
            }

            _onLog('${type.name} sent successfully');
            sentToAny = true;
          } catch (e) {
            _onLog('Error sending to channel: $e');
            continue;
          }
        }
      }

      if (!sentToAny) {
        _onLog('No open data channels available for sending media');
        return false;
      }

      return true;
    } catch (e) {
      _onLog('Error sending media: $e');
      return false;
    }
  }

  void _setupConnectionHandlers() {
    _pc?.onIceCandidate = (candidate) {
      _onLog('New ICE candidate: ${candidate.candidate}');
      _candidates.add(candidate);
      onIceCandidate?.call(candidate);
    };

    _pc?.onIceConnectionState = (state) {
      _onLog('ICE Connection State changed to: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        onConnectionFailed?.call();
      }
    };

    _pc?.onConnectionState = (state) {
      _onLog('Connection State changed to: $state');
      onStateChange?.call();
    };

    _pc?.onTrack = (track) {
      _onLog('Received remote track: ${track.track.kind}');
      if (track.track.kind == 'video') {
        _remoteStream = track.streams[0];
        onRemoteStream?.call(_remoteStream!);
        onStateChange?.call();
      }
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
    try {
      _onLog('Updating track: ${newTrack.kind}');

      var sender = _senders
          .firstWhereOrNull((sender) => sender.track?.kind == newTrack.kind);

      if (sender != null) {
        _onLog(
            'Found existing sender for ${newTrack.kind}, replacing track...');

        var params = sender.parameters;

        params.degradationPreference =
            RTCDegradationPreference.MAINTAIN_RESOLUTION;

        await sender.setParameters(params);

        await sender.replaceTrack(newTrack);

        _onLog('Track replaced successfully: ${newTrack.kind}');
        _onLog('New track settings: ${newTrack.getSettings()}');
      } else {
        _onLog('No existing sender found for ${newTrack.kind}');
      }
    } catch (e) {
      _onLog('Error updating track: $e');
      throw e;
    }
  }

  Future<void> updateStream(MediaStream newStream) async {
    try {
      _onLog('Updating entire stream...');

      final newTracks = newStream.getTracks();
      _onLog('New stream has ${newTracks.length} tracks');

      for (var track in newTracks) {
        await updateTrack(track);
      }

      _onLog('Stream updated successfully');
    } catch (e) {
      _onLog('Error updating stream: $e');
      throw e;
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

  Future<bool> sendCommand(String command, Map<String, dynamic> data) async {
    try {
      for (var channel in _dataChannels.values) {
        if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
          final message = jsonEncode(data);
          await channel.send(RTCDataChannelMessage(message));
          _onLog('Sent command via data channel: $command');
          return true;
        }
      }
      _onLog('No open data channels available for sending command');
      return false;
    } catch (e) {
      _onLog('Error sending command via data channel: $e');
      return false;
    }
  }

  Future<void> _verifyDataChannelState() async {
    if (_dataChannels.isEmpty) {
      _onLog('No data channels exist, creating new one...');
      await _recreateDataChannel();
      return;
    }

    final hasOpenChannel = _dataChannels.values.any(
        (channel) => channel.state == RTCDataChannelState.RTCDataChannelOpen);

    if (!hasOpenChannel) {
      _onLog('No open data channels found, recreating...');
      await _recreateDataChannel();
    } else {
      _onLog('Data channel verified and open');
    }
  }

  List<RTCRtpSender> getSenders() {
    return _senders;
  }
}
