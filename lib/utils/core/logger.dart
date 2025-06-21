import 'dart:async';
import 'package:flutter/foundation.dart';

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  final ValueNotifier<List<String>> _messagesNotifier = ValueNotifier([]);

  Stream<LogEntry> get logStream => _logController.stream;
  ValueNotifier<List<String>> get messagesNotifier => _messagesNotifier;
  List<String> get messages => _messagesNotifier.value;

  void log(String context, String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      context: context,
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );

    final formattedMessage = '${entry.timestamp.toString().split('.').first} [$context] $message';

    if (kDebugMode) {
      print(formattedMessage);
    }

    _messagesNotifier.value = [..._messagesNotifier.value, formattedMessage];
    _logController.add(entry);
  }

  void clear() {
    _messagesNotifier.value = [];
  }

  void dispose() {
    _logController.close();
    _messagesNotifier.dispose();
  }
}

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final String context;
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.context,
    required this.message,
    required this.level,
    required this.timestamp,
  });
}
