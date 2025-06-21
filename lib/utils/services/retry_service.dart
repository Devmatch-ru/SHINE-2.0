import 'dart:async';
import 'dart:math';
import '../core/error_handler.dart';
import '../core/logger.dart';

class RetryService {
  static final RetryService _instance = RetryService._internal();
  factory RetryService() => _instance;
  RetryService._internal();

  final Logger _logger = Logger();
  final ErrorHandler _errorHandler = ErrorHandler();

  Future<T> retry<T>(
      String context,
      Future<T> Function() operation, {
        int maxAttempts = 3,
        Duration initialDelay = const Duration(seconds: 1),
        double backoffMultiplier = 2.0,
        Duration? maxDelay,
        bool Function(dynamic error)? retryIf,
      }) async {
    dynamic lastError;

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _logger.log('RetryService', '$context - Attempt $attempt/$maxAttempts');
        return await operation();
      } catch (error) {
        lastError = error;

        if (retryIf != null && !retryIf(error)) {
          _logger.log('RetryService', '$context - Error not retryable: $error');
          break;
        }

        if (attempt == maxAttempts) {
          _logger.log('RetryService', '$context - Max attempts reached');
          break;
        }

        final delay = _calculateDelay(attempt, initialDelay, backoffMultiplier, maxDelay);
        _logger.log('RetryService', '$context - Attempt $attempt failed: $error. Retrying in ${delay.inMilliseconds}ms');

        await Future.delayed(delay);
      }
    }

    _errorHandler.handleError('RetryService.$context', lastError);
    throw lastError;
  }

  Duration _calculateDelay(
      int attempt,
      Duration initialDelay,
      double backoffMultiplier,
      Duration? maxDelay,
      ) {
    final calculatedDelay = Duration(
      milliseconds: (initialDelay.inMilliseconds * pow(backoffMultiplier, attempt - 1)).round(),
    );

    if (maxDelay != null && calculatedDelay > maxDelay) {
      return maxDelay;
    }

    return calculatedDelay;
  }
}