// lib/services/error_handling_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

import 'logging_service.dart';
enum ErrorSeverity { low, medium, high, critical }

enum ErrorCategory {
  network,
  webrtc,
  media,
  permission,
  device,
  system,
  user,
  unknown
}

class AppError {
  final String id;
  final String context;
  final String message;
  final String? details;
  final ErrorSeverity severity;
  final ErrorCategory category;
  final DateTime timestamp;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? metadata;

  AppError({
    String? id,
    required this.context,
    required this.message,
    this.details,
    required this.severity,
    required this.category,
    DateTime? timestamp,
    this.stackTrace,
    this.metadata,
  }) :
        id = id ?? _generateId(),
        timestamp = timestamp ?? DateTime.now();

  static String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString();
  }

  String get userFriendlyMessage {
    switch (category) {
      case ErrorCategory.network:
        return 'Проблема с сетевым соединением. Проверьте подключение к Wi-Fi.';
      case ErrorCategory.webrtc:
        return 'Ошибка видеосвязи. Попробуйте переподключиться.';
      case ErrorCategory.media:
        return 'Ошибка при работе с камерой или медиафайлами.';
      case ErrorCategory.permission:
        return 'Необходимо предоставить разрешения в настройках.';
      case ErrorCategory.device:
        return 'Ошибка устройства. Попробуйте перезапустить приложение.';
      case ErrorCategory.system:
        return 'Системная ошибка. Попробуйте позже.';
      case ErrorCategory.user:
        return message; // User errors are already user-friendly
      case ErrorCategory.unknown:
        return 'Произошла неизвестная ошибка. Попробуйте перезапустить приложение.';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'context': context,
      'message': message,
      'details': details,
      'severity': severity.name,
      'category': category.name,
      'timestamp': timestamp.toIso8601String(),
      'stackTrace': stackTrace?.toString(),
      'metadata': metadata,
    };
  }

  @override
  String toString() => '[$context] $message';
}

class ErrorHandlingService with LoggerMixin {
  @override
  String get loggerContext => 'ErrorHandlingService';

  static final ErrorHandlingService _instance = ErrorHandlingService._internal();
  factory ErrorHandlingService() => _instance;
  ErrorHandlingService._internal();

  final StreamController<AppError> _errorController = StreamController<AppError>.broadcast();
  final List<AppError> _errorHistory = [];
  final int _maxHistorySize = 100;

  Stream<AppError> get errorStream => _errorController.stream;
  List<AppError> get errorHistory => List.unmodifiable(_errorHistory);

  void handleError(
      String context,
      dynamic error, {
        String? details,
        ErrorSeverity severity = ErrorSeverity.medium,
        ErrorCategory? category,
        StackTrace? stackTrace,
        Map<String, dynamic>? metadata,
      }) {
    final appError = AppError(
      context: context,
      message: error.toString(),
      details: details,
      severity: severity,
      category: category ?? _categorizeError(error),
      stackTrace: stackTrace,
      metadata: metadata,
    );

    _addToHistory(appError);
    _logError(appError);
    _errorController.add(appError);
  }

  ErrorCategory _categorizeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('wifi')) {
      return ErrorCategory.network;
    }

    if (errorStr.contains('webrtc') ||
        errorStr.contains('ice') ||
        errorStr.contains('peer') ||
        errorStr.contains('sdp')) {
      return ErrorCategory.webrtc;
    }

    if (errorStr.contains('camera') ||
        errorStr.contains('media') ||
        errorStr.contains('track') ||
        errorStr.contains('stream')) {
      return ErrorCategory.media;
    }

    if (errorStr.contains('permission') ||
        errorStr.contains('denied')) {
      return ErrorCategory.permission;
    }

    if (errorStr.contains('device') ||
        errorStr.contains('hardware')) {
      return ErrorCategory.device;
    }

    return ErrorCategory.unknown;
  }

  void _addToHistory(AppError error) {
    _errorHistory.add(error);
    if (_errorHistory.length > _maxHistorySize) {
      _errorHistory.removeRange(0, _errorHistory.length - _maxHistorySize);
    }
  }

  void _logError(AppError error) {
    switch (error.severity) {
      case ErrorSeverity.low:
        logDebug('${error.context}: ${error.message}', error.stackTrace);
        break;
      case ErrorSeverity.medium:
        logWarning('${error.context}: ${error.message}', error.stackTrace);
        break;
      case ErrorSeverity.high:
      case ErrorSeverity.critical:
        logError('${error.context}: ${error.message}', error.stackTrace);
        break;
    }
  }

  // Convenience methods for common error scenarios
  void handleNetworkError(String context, dynamic error, {StackTrace? stackTrace}) {
    handleError(
      context,
      error,
      severity: ErrorSeverity.high,
      category: ErrorCategory.network,
      stackTrace: stackTrace,
    );
  }

  void handleWebRTCError(String context, dynamic error, {StackTrace? stackTrace}) {
    handleError(
      context,
      error,
      severity: ErrorSeverity.high,
      category: ErrorCategory.webrtc,
      stackTrace: stackTrace,
    );
  }

  void handleMediaError(String context, dynamic error, {StackTrace? stackTrace}) {
    handleError(
      context,
      error,
      severity: ErrorSeverity.medium,
      category: ErrorCategory.media,
      stackTrace: stackTrace,
    );
  }

  void handlePermissionError(String context, dynamic error, {StackTrace? stackTrace}) {
    handleError(
      context,
      error,
      severity: ErrorSeverity.critical,
      category: ErrorCategory.permission,
      stackTrace: stackTrace,
    );
  }

  void handleUserError(String context, String message) {
    handleError(
      context,
      message,
      severity: ErrorSeverity.low,
      category: ErrorCategory.user,
    );
  }

  List<AppError> getErrorsByCategory(ErrorCategory category) {
    return _errorHistory.where((error) => error.category == category).toList();
  }

  List<AppError> getErrorsBySeverity(ErrorSeverity severity) {
    return _errorHistory.where((error) => error.severity == severity).toList();
  }

  List<AppError> getRecentErrors({Duration? within}) {
    final cutoff = DateTime.now().subtract(within ?? const Duration(hours: 1));
    return _errorHistory.where((error) => error.timestamp.isAfter(cutoff)).toList();
  }

  void clearErrorHistory() {
    _errorHistory.clear();
    logInfo('Error history cleared');
  }

  String generateErrorReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== ERROR REPORT ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Total errors: ${_errorHistory.length}');
    buffer.writeln();

    // Group by category
    final byCategory = <ErrorCategory, List<AppError>>{};
    for (final error in _errorHistory) {
      byCategory.putIfAbsent(error.category, () => []).add(error);
    }

    for (final entry in byCategory.entries) {
      buffer.writeln('${entry.key.name.toUpperCase()}: ${entry.value.length} errors');
      for (final error in entry.value.take(5)) { // Show latest 5 per category
        buffer.writeln('  [${error.severity.name}] ${error.context}: ${error.message}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void dispose() {
    _errorController.close();
    _errorHistory.clear();
  }
}

// Mixin for easy error handling
mixin ErrorHandlerMixin {
  ErrorHandlingService get _errorHandler => ErrorHandlingService();

  void handleError(
      String context,
      dynamic error, {
        String? details,
        ErrorSeverity severity = ErrorSeverity.medium,
        ErrorCategory? category,
        StackTrace? stackTrace,
        Map<String, dynamic>? metadata,
      }) {
    _errorHandler.handleError(
      context,
      error,
      details: details,
      severity: severity,
      category: category,
      stackTrace: stackTrace,
      metadata: metadata,
    );
  }

  void handleNetworkError(String context, dynamic error, {StackTrace? stackTrace}) {
    _errorHandler.handleNetworkError(context, error, stackTrace: stackTrace);
  }

  void handleWebRTCError(String context, dynamic error, {StackTrace? stackTrace}) {
    _errorHandler.handleWebRTCError(context, error, stackTrace: stackTrace);
  }

  void handleMediaError(String context, dynamic error, {StackTrace? stackTrace}) {
    _errorHandler.handleMediaError(context, error, stackTrace: stackTrace);
  }

  void handlePermissionError(String context, dynamic error, {StackTrace? stackTrace}) {
    _errorHandler.handlePermissionError(context, error, stackTrace: stackTrace);
  }

  void handleUserError(String context, String message) {
    _errorHandler.handleUserError(context, message);
  }
}