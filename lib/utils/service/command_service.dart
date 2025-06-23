// lib/services/command_service.dart
import 'dart:convert';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import './logging_service.dart';

enum CommandType {
  photo('capture_photo'),
  flashlight('toggle_flashlight'),
  timer('start_timer'),
  video('toggle_video'),
  qualityChange('quality_change');

  const CommandType(this.value);
  final String value;

  static CommandType? fromString(String value) {
    for (final type in CommandType.values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

class AppCommand {
  final CommandType type;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  AppCommand({
    required this.type,
    this.data = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'type': 'command',
      'action': type.value,
      'data': data,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory AppCommand.fromJson(Map<String, dynamic> json) {
    final type = CommandType.fromString(json['action'] ?? '');
    if (type == null) {
      throw ArgumentError('Unknown command type: ${json['action']}');
    }

    return AppCommand(
      type: type,
      data: json['data'] ?? {},
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        json['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  static AppCommand photo() => AppCommand(type: CommandType.photo);
  static AppCommand flashlight() => AppCommand(type: CommandType.flashlight);
  static AppCommand timer() => AppCommand(type: CommandType.timer);
  static AppCommand video() => AppCommand(type: CommandType.video);
  static AppCommand qualityChange(String quality) => AppCommand(
    type: CommandType.qualityChange,
    data: {'quality': quality},
  );
}

class QualityChangeCommand {
  final String quality;

  QualityChangeCommand(this.quality);

  Map<String, dynamic> toJson() {
    return {
      'type': 'quality_change',
      'quality': quality,
    };
  }

  factory QualityChangeCommand.fromJson(Map<String, dynamic> json) {
    return QualityChangeCommand(json['quality'] ?? 'medium');
  }
}

class CommandService with LoggerMixin {
  @override
  String get loggerContext => 'CommandService';

  Future<bool> sendCommand(RTCDataChannel? dataChannel, AppCommand command) async {
    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      logError('Data channel is not open');
      return false;
    }

    try {
      final message = jsonEncode(command.toJson());
      await dataChannel!.send(RTCDataChannelMessage(message));
      logInfo('Command sent successfully: ${command.type.value}');
      return true;
    } catch (e, stackTrace) {
      logError('Failed to send command: $e', stackTrace);
      return false;
    }
  }

  Future<bool> sendQualityChange(RTCDataChannel? dataChannel, String quality) async {
    if (dataChannel?.state != RTCDataChannelState.RTCDataChannelOpen) {
      logError('Data channel is not open for quality change');
      return false;
    }

    try {
      final command = QualityChangeCommand(quality);
      final message = jsonEncode(command.toJson());
      await dataChannel!.send(RTCDataChannelMessage(message));
      logInfo('Quality change command sent: $quality');
      return true;
    } catch (e, stackTrace) {
      logError('Failed to send quality change: $e', stackTrace);
      return false;
    }
  }

  AppCommand? parseCommand(String messageText) {
    try {
      final data = jsonDecode(messageText);
      if (data['type'] == 'command') {
        return AppCommand.fromJson(data);
      }
      return null;
    } catch (e, stackTrace) {
      logError('Failed to parse command: $e', stackTrace);
      return null;
    }
  }

  QualityChangeCommand? parseQualityChange(String messageText) {
    try {
      final data = jsonDecode(messageText);
      if (data['type'] == 'quality_change') {
        return QualityChangeCommand.fromJson(data);
      }
      return null;
    } catch (e, stackTrace) {
      logError('Failed to parse quality change: $e', stackTrace);
      return null;
    }
  }

  Future<bool> sendCommandToMultipleChannels(
      Map<String, RTCDataChannel> dataChannels,
      AppCommand command,
      ) async {
    if (dataChannels.isEmpty) {
      logError('No data channels available');
      return false;
    }

    bool sentToAny = false;
    final errors = <String>[];

    for (final entry in dataChannels.entries) {
      try {
        if (entry.value.state == RTCDataChannelState.RTCDataChannelOpen) {
          final success = await sendCommand(entry.value, command);
          if (success) {
            sentToAny = true;
            logInfo('Command sent to ${entry.key}: ${command.type.value}');
          } else {
            errors.add('Failed to send to ${entry.key}');
          }
        } else {
          errors.add('Data channel not open for ${entry.key}');
        }
      } catch (e) {
        errors.add('Error sending to ${entry.key}: $e');
      }
    }

    if (!sentToAny) {
      final errorMessage = 'Failed to send command: ${errors.join(", ")}';
      logError(errorMessage);
      throw Exception(errorMessage);
    }

    return sentToAny;
  }
}