// lib/utils/webrtc/webrtc_connection.dart (Updated)
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

import '../../webrtc/types.dart';
import '../service/command_service.dart';
import '../service/logging_service.dart';
import '../service/media_service.dart';
import '../service/webrtc_service.dart';


class WebRTCConnection with LoggerMixin {
  @override
  String get loggerContext => 'WebRTCConnection';

  // Services
  final CommandService _commandService = CommandService();
  final WebRTCService _webrtcService = WebRTCService();
  final MediaService _mediaService = MediaService();

  // WebRTC state
  RTCPeerConnection? _pc;
  final List<RTCIceCandidate> _candidates = [];
  RTCSessionDescription? _offer;
  final List<RTCRtpSender> _senders = [];
  final Map<RTCPeerConnection, RTCDataChannel> _dataChannels = {};
  MediaStream? _remoteStream;

  // Callbacks
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
  });

  // Getters
  RTCSessionDescription? get offer => _offer;
  List<RTCIceCandidate> get candidates => _candidates;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected =>
      _pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected;

  Future<void> createConnection(MediaStream? localStream, {bool isBroadcaster = true}) async {
    try {
      logInfo('Creating WebRTC connection (isBroadcaster: $isBroadcaster)');

      _pc = await _webrtcService.createPeerConnection();
      _setupConnectionHandlers();

      if (isBroadcaster && localStream != null) {
        await _setupBroadcasterConnection(localStream);
      }

      logInfo('WebRTC connection created successfully');
    } catch (e, stackTrace) {
      logError('Error creating connection: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _setupBroadcasterConnection(MediaStream localStream) async {
    try {
      logInfo('Setting up broadcaster connection...');

      // Add tracks to connection
      await _webrtcService.addStreamTracks(_pc!, localStream, _senders);

      // Create data channel for commands
      final dataChannel = await _webrtcService.createDataChannel(_pc!, 'commands');
      _dataChannels[_pc!] = dataChannel;
      _setupDataChannel(dataChannel);

      // Create optimized offer
      logInfo('Creating optimized offer...');
      _offer = await _pc!.createOffer(_webrtcService.defaultOfferConstraints);

      if (_offer != null) {
        // Modify SDP for high quality
        final modifiedSdp = _webrtcService.modifySdpForHighQuality(_offer!.sdp!);
        _offer = RTCSessionDescription(modifiedSdp, _offer!.type);

        logInfo('Setting local description...');
        await _pc!.setLocalDescription(_offer!);
        logInfo('Local description set successfully');
      }
    } catch (e, stackTrace) {
      logError('Error setting up broadcaster connection: $e', stackTrace);
      rethrow;
    }
  }

  void _setupConnectionHandlers() {
    if (_pc == null) return;

    // Setup connection state handlers
    _webrtcService.setupConnectionStateHandlers(
      _pc!,
      onConnected: () {
        logInfo('Successfully connected');
        onStateChange?.call();
      },
      onDisconnected: () {
        logWarning('Connection disconnected');
        onConnectionFailed?.call();
      },
      onFailed: () {
        logError('Connection failed');
        onConnectionFailed?.call();
      },
    );

    // Setup ICE connection state handlers
    _webrtcService.setupIceConnectionStateHandlers(
      _pc!,
      onConnected: () {
        logInfo('ICE connection established');
      },
      onDisconnected: () {
        logWarning('ICE connection disconnected');
        onConnectionFailed?.call();
      },
      onFailed: () {
        logError('ICE connection failed');
        onConnectionFailed?.call();
      },
    );

    // Setup ICE candidate handler
    _webrtcService.setupIceCandidateHandler(
      _pc!,
      onCandidate: (candidate) {
        _candidates.add(candidate);
        onIceCandidate?.call(candidate);
      },
      onGatheringComplete: () {
        logInfo('ICE gathering completed');
      },
    );

    // Setup track handler
    _webrtcService.setupTrackHandler(
      _pc!,
      onTrack: (track, streams) {
        logInfo('Track received: ${track.kind}');

        if (track.kind == 'video' && streams.isNotEmpty) {
          _remoteStream = streams[0];
          logInfo('Remote stream set with ID: ${_remoteStream!.id}');
          onRemoteStream?.call(_remoteStream!);
        }
      },
    );

    // Setup data channel handler
    _pc!.onDataChannel = (channel) {
      logInfo('Data channel received: ${channel.label}');
      _dataChannels[_pc!] = channel;
      _setupDataChannel(channel);
    };
  }

  void _setupDataChannel(RTCDataChannel channel) {
    logInfo('Setting up data channel: ${channel.label}');

    channel.onDataChannelState = (state) {
      logInfo('Data channel state changed to: $state');

      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        logInfo('Data channel is now OPEN and ready for communication');
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        logWarning('Data channel is now CLOSED');
        if (_pc?.connectionState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _recreateDataChannel();
        }
      }
    };

    channel.onMessage = (message) {
      _handleDataChannelMessage(message);
    };
  }

  void _handleDataChannelMessage(RTCDataChannelMessage message) {
    if (message.type == MessageType.text) {
      try {
        logDebug('Received message: ${message.text}');

        // Try to parse as command
        final command = _commandService.parseCommand(message.text);
        if (command != null) {
          _handleCommand(command);
          return;
        }

        // Try to parse as quality change
        final qualityChange = _commandService.parseQualityChange(message.text);
        if (qualityChange != null) {
          logInfo('Received quality change request: ${qualityChange.quality}');
          onQualityChangeRequested?.call(qualityChange.quality);
          return;
        }

        // Try to parse as media
        final data = jsonDecode(message.text);
        if (data['type'] == 'media') {
          onMediaReceived?.call(
            data['mediaType'] == 'photo' ? MediaType.photo : MediaType.video,
            data['data'],
          );
        }
      } catch (e, stackTrace) {
        logError('Error processing message: $e', stackTrace);
      }
    }
  }

  void _handleCommand(AppCommand command) {
    logInfo('Received command: ${command.type.value}');
    onCommandReceived?.call(command.type.value);

    switch (command.type) {
      case CommandType.photo:
        onCapturePhoto?.call();
        break;
      case CommandType.video:
      // Toggle video recording
        break;
      case CommandType.flashlight:
      // Toggle flashlight
        break;
      case CommandType.timer:
      // Start timer
        break;
      case CommandType.qualityChange:
        final quality = command.data['quality'] as String? ?? 'medium';
        onQualityChangeRequested?.call(quality);
        break;
    }
  }

  Future<void> _recreateDataChannel() async {
    try {
      logInfo('Attempting to recreate data channel...');

      final dataChannel = await _webrtcService.createDataChannel(_pc!, 'commands');
      _dataChannels[_pc!] = dataChannel;
      _setupDataChannel(dataChannel);

      logInfo('Data channel recreated successfully');
    } catch (e, stackTrace) {
      logError('Error recreating data channel: $e', stackTrace);
    }
  }

  Future<bool> sendMedia(MediaType type, XFile media) async {
    try {
      logInfo('Preparing to send ${type.name}...');

      bool sentToAny = false;

      for (final channel in _dataChannels.values) {
        if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
          try {
            final success = await _mediaService.sendMediaThroughDataChannel(
              channel,
              type,
              media,
              onProgress: onTransferProgress,
            );

            if (success) {
              logInfo('${type.name} sent successfully through data channel');
              sentToAny = true;
            }
          } catch (e) {
            logError('Error sending to channel: $e');
            continue;
          }
        }
      }

      if (!sentToAny) {
        logWarning('No open data channels available for sending media');
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      logError('Error sending media: $e', stackTrace);
      return false;
    }
  }

  Future<void> handleAnswer(RTCSessionDescription answer) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');

      logInfo('Setting remote description (answer)...');

      if (_pc!.signalingState != RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
        logWarning('Unexpected signaling state for answer: ${_pc!.signalingState}');
      }

      await _pc!.setRemoteDescription(answer);
      logInfo('Remote description set successfully');

      // Add pending ICE candidates
      for (final candidate in _candidates) {
        logDebug('Adding pending ICE candidate: ${candidate.candidate}');
        await _pc!.addCandidate(candidate);
      }
      _candidates.clear();
    } catch (e, stackTrace) {
      logError('Error handling answer: $e', stackTrace);
      rethrow;
    }
  }

  Future<RTCSessionDescription> createAnswer() async {
    if (_pc == null) throw Exception('PeerConnection not initialized');

    try {
      logInfo('Creating answer...');

      final answer = await _pc!.createAnswer(_webrtcService.defaultAnswerConstraints);
      if (answer == null) throw Exception('Failed to create answer');

      logInfo('Setting local description (answer)...');
      await _pc!.setLocalDescription(answer);

      return answer;
    } catch (e, stackTrace) {
      logError('Error creating answer: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');

      logInfo('Setting remote description...');
      await _pc!.setRemoteDescription(description);
      logInfo('Remote description set successfully');
    } catch (e, stackTrace) {
      logError('Error setting remote description: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> addIceCandidate(RTCIceCandidate candidate) async {
    try {
      if (_pc == null) throw Exception('PeerConnection not initialized');

      logInfo('Adding ICE candidate: ${candidate.candidate}');
      await _pc!.addCandidate(candidate);
      logInfo('ICE candidate added successfully');
    } catch (e, stackTrace) {
      logError('Error adding ICE candidate: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> updateTrack(MediaStreamTrack newTrack) async {
    try {
      logInfo('Updating track: ${newTrack.kind}');

      final sender = _senders.firstWhereOrNull(
            (sender) => sender.track?.kind == newTrack.kind,
      );

      if (sender != null) {
        logInfo('Found existing sender for ${newTrack.kind}, replacing track...');

        // Optimize sender parameters
        await _webrtcService.optimizeSenderParameters(sender);

        // Replace track
        await sender.replaceTrack(newTrack);

        logInfo('Track replaced successfully: ${newTrack.kind}');
        logDebug('New track settings: ${newTrack.getSettings()}');
      } else {
        logWarning('No existing sender found for ${newTrack.kind}');
      }
    } catch (e, stackTrace) {
      logError('Error updating track: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> updateStream(MediaStream newStream) async {
    try {
      logInfo('Updating entire stream...');

      final newTracks = newStream.getTracks();
      logInfo('New stream has ${newTracks.length} tracks');

      for (final track in newTracks) {
        await updateTrack(track);
      }

      logInfo('Stream updated successfully');
    } catch (e, stackTrace) {
      logError('Error updating stream: $e', stackTrace);
      rethrow;
    }
  }

  Future<bool> sendCommand(String command, Map<String, dynamic> data) async {
    try {
      for (final channel in _dataChannels.values) {
        if (channel.state == RTCDataChannelState.RTCDataChannelOpen) {
          final message = jsonEncode(data);
          await channel.send(RTCDataChannelMessage(message));
          logInfo('Sent command via data channel: $command');
          return true;
        }
      }

      logWarning('No open data channels available for sending command');
      return false;
    } catch (e, stackTrace) {
      logError('Error sending command via data channel: $e', stackTrace);
      return false;
    }
  }

  Future<void> close() async {
    try {
      logInfo('Closing WebRTC connection...');

      // Close data channels
      for (final channel in _dataChannels.values) {
        await _webrtcService.closeDataChannel(channel);
      }
      _dataChannels.clear();

      // Clean up remote stream
      if (_remoteStream != null) {
        logInfo('Cleaning up remote stream');
        _remoteStream!.getTracks().forEach((track) {
          logDebug('Stopping track: ${track.kind}');
          track.stop();
        });
        _remoteStream = null;
      }

      // Close peer connection
      await _webrtcService.closeConnection(_pc);
      _pc = null;

      // Clear state
      _senders.clear();
      _candidates.clear();
      _offer = null;

      logInfo('WebRTC connection closed successfully');
    } catch (e, stackTrace) {
      logError('Error closing WebRTC connection: $e', stackTrace);
    }
  }
}