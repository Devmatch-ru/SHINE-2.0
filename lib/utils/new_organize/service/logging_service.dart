// lib/services/logging_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class LogEntry {
  final String context;
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  LogEntry({
    required this.context,
    required this.message,
    required this.level,
    required this.timestamp,
    this.stackTrace,
  });

  @override
  String toString() => '${timestamp.toString().split('.').first} [$context] $message';
}

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  final ValueNotifier<List<LogEntry>> _entriesNotifier = ValueNotifier([]);
  final int _maxEntries = 1000;

  Stream<LogEntry> get logStream => _logController.stream;
  ValueNotifier<List<LogEntry>> get entriesNotifier => _entriesNotifier;
  List<LogEntry> get entries => _entriesNotifier.value;
  List<String> get messages => _entriesNotifier.value.map((e) => e.toString()).toList();

  void debug(String context, String message, [StackTrace? stackTrace]) {
    _log(LogLevel.debug, context, message, stackTrace);
  }

  void info(String context, String message, [StackTrace? stackTrace]) {
    _log(LogLevel.info, context, message, stackTrace);
  }

  void warning(String context, String message, [StackTrace? stackTrace]) {
    _log(LogLevel.warning, context, message, stackTrace);
  }

  void error(String context, String message, [StackTrace? stackTrace]) {
    _log(LogLevel.error, context, message, stackTrace);
  }

  void _log(LogLevel level, String context, String message, [StackTrace? stackTrace]) {
    final entry = LogEntry(
      context: context,
      message: message,
      level: level,
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );

    if (kDebugMode) {
      switch (level) {
        case LogLevel.debug:
          debugPrint('[DEBUG] ${entry.toString()}');
          break;
        case LogLevel.info:
          debugPrint('[INFO] ${entry.toString()}');
          break;
        case LogLevel.warning:
          debugPrint('[WARNING] ${entry.toString()}');
          break;
        case LogLevel.error:
          debugPrint('[ERROR] ${entry.toString()}');
          if (stackTrace != null) {
            debugPrint('Stack trace: $stackTrace');
          }
          break;
      }
    }

    // Add to entries with size limit
    final currentEntries = List<LogEntry>.from(_entriesNotifier.value);
    currentEntries.add(entry);

    if (currentEntries.length > _maxEntries) {
      currentEntries.removeRange(0, currentEntries.length - _maxEntries);
    }

    _entriesNotifier.value = currentEntries;
    _logController.add(entry);
  }

  void clear() {
    _entriesNotifier.value = [];
  }

  String getFormattedLogs({LogLevel? minLevel}) {
    var logs = _entriesNotifier.value;

    if (minLevel != null) {
      logs = logs.where((entry) => entry.level.index >= minLevel.index).toList();
    }

    return logs.map((entry) => entry.toString()).join('\n');
  }

  void dispose() {
    _logController.close();
    _entriesNotifier.dispose();
  }
}

// Mixin for easy logging
mixin LoggerMixin {
  LoggingService get _logger => LoggingService();
  String get loggerContext;

  void logDebug(String message, [StackTrace? stackTrace]) {
    _logger.debug(loggerContext, message, stackTrace);
  }

  void logInfo(String message, [StackTrace? stackTrace]) {
    _logger.info(loggerContext, message, stackTrace);
  }

  void logWarning(String message, [StackTrace? stackTrace]) {
    _logger.warning(loggerContext, message, stackTrace);
  }

  void logError(String message, [StackTrace? stackTrace]) {
    _logger.error(loggerContext, message, stackTrace);
  }
}