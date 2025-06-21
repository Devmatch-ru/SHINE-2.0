import 'dart:async';
import 'package:flutter/foundation.dart';

class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final StreamController<AppError> _errorController = StreamController<AppError>.broadcast();
  Stream<AppError> get errorStream => _errorController.stream;

  void handleError(String context, dynamic error, {StackTrace? stackTrace}) {
    final appError = AppError(
      context: context,
      message: error.toString(),
      timestamp: DateTime.now(),
      stackTrace: stackTrace,
    );

    debugPrint('ERROR [$context]: ${error.toString()}');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }

    _errorController.add(appError);
  }

  void dispose() {
    _errorController.close();
  }
}

class AppError {
  final String context;
  final String message;
  final DateTime timestamp;
  final StackTrace? stackTrace;

  AppError({
    required this.context,
    required this.message,
    required this.timestamp,
    this.stackTrace,
  });

  @override
  String toString() => '[$context] $message';
}