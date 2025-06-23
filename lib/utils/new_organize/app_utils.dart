// lib/utils/app_utils.dart
import 'dart:io';
import 'dart:math';

import 'package:shine/utils/new_organize/service/logging_service.dart';
import 'package:shine/utils/new_organize/service/network_service.dart';

class UserNameGenerator with LoggerMixin {
  @override
  String get loggerContext => 'UserNameGenerator';

  static const List<String> _coolWords = [
    'Linker', 'Signal', 'Wave', 'Beam', 'Echo',
    'Pulse', 'Relay', 'Nimbus', 'Channel', 'Bridge',
    'Node', 'Spark', 'Flash', 'Stream', 'Flow',
    'Sync', 'Link', 'Net', 'Hub', 'Core',
  ];

  static const List<String> _adjectives = [
    'Swift', 'Bright', 'Quick', 'Sharp', 'Smart',
    'Fast', 'Clear', 'Pure', 'Strong', 'Bold',
    'Cool', 'Hot', 'Fresh', 'New', 'Prime',
  ];

  final NetworkService _networkService = NetworkService();

  String generateFromReceiverInfo(String receiverMessage) {
    try {
      if (!_networkService.isReceiverResponse(receiverMessage)) {
        logWarning('Invalid receiver message format: $receiverMessage');
        return 'Unknown';
      }

      final info = _networkService.parseReceiverInfo(receiverMessage);
      final ip = info['ip']!;

      return generateFromIP(ip);
    } catch (e, stackTrace) {
      logError('Error generating name from receiver info: $e', stackTrace);
      return 'Unknown';
    }
  }

  String generateFromIP(String ip) {
    try {
      final parts = ip.split('.');
      if (parts.length != 4) {
        logWarning('Invalid IP format: $ip');
        return 'Unknown';
      }

      final lastOctet = parts.last;
      final lastDigits = lastOctet.replaceAll(RegExp(r'[^0-9]'), '');

      if (lastDigits.isEmpty) {
        logWarning('No digits found in last octet: $lastOctet');
        return 'Unknown';
      }

      final index = int.tryParse(lastDigits) ?? 0;
      final word = _coolWords[index % _coolWords.length];

      final name = '$word$lastDigits';
      logDebug('Generated name "$name" from IP $ip');

      return name;
    } catch (e, stackTrace) {
      logError('Error generating name from IP: $e', stackTrace);
      return 'Unknown';
    }
  }

  String generateWithAdjective(String ip) {
    try {
      final baseName = generateFromIP(ip);
      if (baseName == 'Unknown') return baseName;

      final random = Random();
      final adjective = _adjectives[random.nextInt(_adjectives.length)];

      return '$adjective $baseName';
    } catch (e, stackTrace) {
      logError('Error generating name with adjective: $e', stackTrace);
      return 'Unknown';
    }
  }

  String generateRandom() {
    try {
      final random = Random();
      final word = _coolWords[random.nextInt(_coolWords.length)];
      final number = random.nextInt(999) + 1;

      return '$word$number';
    } catch (e, stackTrace) {
      logError('Error generating random name: $e', stackTrace);
      return 'Unknown';
    }
  }
}

class TimeFormatter {
  static String formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  static String formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}д назад';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}ч назад';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}м назад';
    } else {
      return 'только что';
    }
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes Б';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГБ';
    }
  }

  static String formatTransferSpeed(int bytesPerSecond) {
    return '${formatFileSize(bytesPerSecond)}/с';
  }
}

class DeviceInfoHelper with LoggerMixin {
  @override
  String get loggerContext => 'DeviceInfoHelper';

  static String getDeviceType() {
    // Since we can't import device_info_plus in this context,
    // we'll use Platform information
    if (Platform.isIOS) {
      return 'iOS Device';
    } else if (Platform.isAndroid) {
      return 'Android Device';
    } else {
      return 'Unknown Device';
    }
  }

  static String getPlatformName() {
    if (Platform.isIOS) {
      return 'iOS';
    } else if (Platform.isAndroid) {
      return 'Android';
    } else if (Platform.isWindows) {
      return 'Windows';
    } else if (Platform.isMacOS) {
      return 'macOS';
    } else if (Platform.isLinux) {
      return 'Linux';
    } else {
      return 'Unknown';
    }
  }

  static bool get isMobile => Platform.isIOS || Platform.isAndroid;
  static bool get isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;
}

class UrlValidator {
  static bool isValidHttpUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.scheme == 'http' || uri.scheme == 'https';
    } catch (e) {
      return false;
    }
  }

  static bool isValidIP(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  static bool isLocalIP(String ip) {
    if (!isValidIP(ip)) return false;

    final parts = ip.split('.').map(int.parse).toList();

    // Check for private IP ranges
    // 10.0.0.0/8
    if (parts[0] == 10) return true;

    // 172.16.0.0/12
    if (parts[0] == 172 && parts[1] >= 16 && parts[1] <= 31) return true;

    // 192.168.0.0/16
    if (parts[0] == 192 && parts[1] == 168) return true;

    // 127.0.0.0/8 (localhost)
    if (parts[0] == 127) return true;

    return false;
  }
}

class RetryHelper with LoggerMixin {
  @override
  String get loggerContext => 'RetryHelper';

  static Future<T> withRetry<T>(
      Future<T> Function() operation, {
        int maxAttempts = 3,
        Duration delay = const Duration(seconds: 1),
        Duration? backoffMultiplier,
        bool Function(dynamic error)? shouldRetry,
      }) async {
    int attempt = 0;
    Duration currentDelay = delay;

    while (attempt < maxAttempts) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        if (attempt >= maxAttempts) {
          rethrow;
        }

        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        await Future.delayed(currentDelay);

        if (backoffMultiplier != null) {
          currentDelay = Duration(
            milliseconds: (currentDelay.inMilliseconds * backoffMultiplier.inMilliseconds).round(),
          );
        }
      }
    }

    throw StateError('This should never be reached');
  }

  static Future<List<T>> withRetryBatch<T>(
      List<Future<T> Function()> operations, {
        int maxAttempts = 3,
        Duration delay = const Duration(seconds: 1),
        bool failFast = false,
      }) async {
    final results = <T>[];
    final errors = <dynamic>[];

    for (int i = 0; i < operations.length; i++) {
      try {
        final result = await withRetry(
          operations[i],
          maxAttempts: maxAttempts,
          delay: delay,
        );
        results.add(result);
      } catch (e) {
        errors.add(e);
        if (failFast) {
          rethrow;
        }
      }
    }

    if (errors.isNotEmpty && results.isEmpty) {
      throw Exception('All operations failed: ${errors.join(", ")}');
    }

    return results;
  }
}

class DebugHelper {
  static String getMemoryUsage() {
    // This would require platform-specific implementation
    return 'Memory usage not available';
  }

  static Map<String, dynamic> getSystemInfo() {
    return {
      'platform': DeviceInfoHelper.getPlatformName(),
      'isMobile': DeviceInfoHelper.isMobile,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  static String formatException(dynamic exception, [StackTrace? stackTrace]) {
    final buffer = StringBuffer();
    buffer.writeln('Exception: $exception');

    if (stackTrace != null) {
      buffer.writeln('Stack trace:');
      buffer.writeln(stackTrace.toString());
    }

    return buffer.toString();
  }
}