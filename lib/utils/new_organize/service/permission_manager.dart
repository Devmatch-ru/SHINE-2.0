// lib/services/permission_manager.dart (Updated)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import './logging_service.dart';
import './error_handling_service.dart';

enum PermissionType {
  camera('Камера', 'для съемки фото и видео'),
  microphone('Микрофон', 'для записи видео со звуком'),
  photos('Галерея', 'для сохранения фото и видео'),
  storage('Хранилище', 'для сохранения файлов'),
  location('Местоположение', 'для обнаружения устройств в сети'),
  bluetooth('Bluetooth', 'для улучшенного сетевого обнаружения');

  const PermissionType(this.displayName, this.description);
  final String displayName;
  final String description;
}

class PermissionResult {
  final PermissionType type;
  final PermissionStatus status;
  final bool isRequired;

  PermissionResult({
    required this.type,
    required this.status,
    required this.isRequired,
  });

  bool get isGranted => status.isGranted;
  bool get isDenied => status.isDenied;
  bool get isPermanentlyDenied => status.isPermanentlyDenied;
  bool get isBlocked => !isGranted && isRequired;
}

class PermissionManager with LoggerMixin, ErrorHandlerMixin {
  @override
  String get loggerContext => 'PermissionManager';

  static final PermissionManager _instance = PermissionManager._internal();
  factory PermissionManager() => _instance;
  PermissionManager._internal();

  static const Map<PermissionType, bool> _requiredPermissions = {
    PermissionType.camera: true,
    PermissionType.microphone: false, // Optional for video recording
    PermissionType.photos: true,
    PermissionType.storage: true,
    PermissionType.location: false, // Optional for discovery
    PermissionType.bluetooth: false, // Optional for discovery
  };

  Map<PermissionType, Permission> get _permissionMap => {
    PermissionType.camera: Permission.camera,
    PermissionType.microphone: Permission.microphone,
    PermissionType.photos: Platform.isIOS ? Permission.photosAddOnly : Permission.storage,
    PermissionType.storage: Permission.storage,
    PermissionType.location: Permission.locationWhenInUse,
    PermissionType.bluetooth: Permission.bluetooth,
  };

  Future<List<PermissionResult>> checkAllPermissions() async {
    try {
      logInfo('Checking all permissions...');

      final results = <PermissionResult>[];

      for (final entry in _requiredPermissions.entries) {
        final permission = _permissionMap[entry.key]!;
        final status = await permission.status;

        results.add(PermissionResult(
          type: entry.key,
          status: status,
          isRequired: entry.value,
        ));

        logDebug('${entry.key.displayName}: ${status.name}');
      }

      logInfo('Permission check completed');
      return results;
    } catch (e, stackTrace) {
      handlePermissionError('checkAllPermissions', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> areRequiredPermissionsGranted() async {
    try {
      final results = await checkAllPermissions();
      final blockedPermissions = results.where((r) => r.isBlocked).toList();

      if (blockedPermissions.isEmpty) {
        logInfo('All required permissions are granted');
        return true;
      }

      logWarning('Missing required permissions: ${blockedPermissions.map((p) => p.type.displayName).join(', ')}');
      return false;
    } catch (e, stackTrace) {
      handlePermissionError('areRequiredPermissionsGranted', e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<List<PermissionResult>> requestAllPermissions() async {
    try {
      logInfo('Requesting all permissions...');

      final permissions = _permissionMap.values.toList();
      final statuses = await permissions.request();

      final results = <PermissionResult>[];

      for (final entry in _requiredPermissions.entries) {
        final permission = _permissionMap[entry.key]!;
        final status = statuses[permission] ?? PermissionStatus.denied;

        results.add(PermissionResult(
          type: entry.key,
          status: status,
          isRequired: entry.value,
        ));

        logInfo('${entry.key.displayName}: ${status.name}');
      }

      logInfo('Permission request completed');
      return results;
    } catch (e, stackTrace) {
      handlePermissionError('requestAllPermissions', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<PermissionResult> requestSinglePermission(PermissionType type) async {
    try {
      logInfo('Requesting ${type.displayName} permission...');

      final permission = _permissionMap[type]!;
      final status = await permission.request();

      final result = PermissionResult(
        type: type,
        status: status,
        isRequired: _requiredPermissions[type] ?? false,
      );

      logInfo('${type.displayName} permission: ${status.name}');
      return result;
    } catch (e, stackTrace) {
      handlePermissionError('requestSinglePermission', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> requestPermissionsWithUI(BuildContext context) async {
    try {
      logInfo('Requesting permissions with UI...');

      bool allGranted = await areRequiredPermissionsGranted();
      if (allGranted) {
        logInfo('All permissions already granted');
        return true;
      }

      // Show permission explanation dialog
      final shouldProceed = await _showPermissionExplanationDialog(context);
      if (!shouldProceed) {
        logInfo('User declined permission request');
        return false;
      }

      // Request permissions
      final results = await requestAllPermissions();

      // Check for permanently denied permissions
      final permanentlyDenied = results
          .where((r) => r.isPermanentlyDenied && r.isRequired)
          .toList();

      if (permanentlyDenied.isNotEmpty) {
        logWarning('Some permissions permanently denied');
        final shouldOpenSettings = await _showPermanentlyDeniedDialog(context, permanentlyDenied);
        if (shouldOpenSettings) {
          await openAppSettings();
        }
        return false;
      }

      // Check if all required permissions are granted
      final stillDenied = results
          .where((r) => r.isDenied && r.isRequired)
          .toList();

      if (stillDenied.isNotEmpty) {
        logWarning('Some required permissions still denied');
        _showDeniedPermissionsDialog(context, stillDenied);
        return false;
      }

      logInfo('All required permissions granted successfully');
      return true;
    } catch (e, stackTrace) {
      handlePermissionError('requestPermissionsWithUI', e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> _showPermissionExplanationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Разрешения приложения'),
        content: const Text(
          'Для корректной работы приложению необходимы следующие разрешения:\n\n'
              '• Камера - для съемки фото и видео\n'
              '• Галерея - для сохранения медиафайлов\n'
              '• Хранилище - для работы с файлами\n\n'
              'Вы можете предоставить эти разрешения сейчас.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Предоставить'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  Future<bool> _showPermanentlyDeniedDialog(
      BuildContext context,
      List<PermissionResult> deniedPermissions,
      ) {
    final permissionNames = deniedPermissions
        .map((p) => p.type.displayName)
        .join(', ');

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Необходимы разрешения'),
        content: Text(
          'Следующие разрешения были отклонены навсегда: $permissionNames.\n\n'
              'Для работы приложения необходимо предоставить эти разрешения в настройках системы.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  void _showDeniedPermissionsDialog(
      BuildContext context,
      List<PermissionResult> deniedPermissions,
      ) {
    final permissionNames = deniedPermissions
        .map((p) => p.type.displayName)
        .join(', ');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Разрешения не предоставлены'),
        content: Text(
          'Следующие разрешения необходимы для работы приложения: $permissionNames.\n\n'
              'Некоторые функции могут работать некорректно.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<bool> shouldRequestPermissions() async {
    try {
      final results = await checkAllPermissions();

      // Check if any required permission is not granted and not permanently denied
      final shouldRequest = results.any((r) =>
      r.isRequired &&
          !r.isGranted &&
          !r.isPermanentlyDenied
      );

      logDebug('Should request permissions: $shouldRequest');
      return shouldRequest;
    } catch (e, stackTrace) {
      handlePermissionError('shouldRequestPermissions', e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<Map<PermissionType, PermissionStatus>> getPermissionStatuses() async {
    try {
      final statuses = <PermissionType, PermissionStatus>{};

      for (final entry in _permissionMap.entries) {
        statuses[entry.key] = await entry.value.status;
      }

      return statuses;
    } catch (e, stackTrace) {
      handlePermissionError('getPermissionStatuses', e, stackTrace: stackTrace);
      return {};
    }
  }

  String getPermissionSummary(List<PermissionResult> results) {
    final granted = results.where((r) => r.isGranted).length;
    final total = results.length;
    final required = results.where((r) => r.isRequired).length;
    final requiredGranted = results.where((r) => r.isRequired && r.isGranted).length;

    return 'Разрешения: $granted/$total (обязательных: $requiredGranted/$required)';
  }
}