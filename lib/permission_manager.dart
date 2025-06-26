import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static List<Permission> _requiredPermissions = [];
  static int? _androidSdkInt;

  static Future<void> _initializePermissions() async {
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      _androidSdkInt = androidInfo.version.sdkInt;

      _requiredPermissions = [
        Permission.camera,
        Permission.microphone,
        Permission.locationWhenInUse,
        Permission.bluetooth,
        if (_androidSdkInt! >= 33) ...[
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ] else ...[
          Permission.storage,
        ],
        if (_androidSdkInt! >= 31) ...[
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.bluetoothAdvertise,
        ],
      ];
    } else if (Platform.isIOS) {
      _requiredPermissions = [
        Permission.camera,
        Permission.microphone,
        Permission.photosAddOnly,
        Permission.locationWhenInUse,
        Permission.bluetooth,
      ];
    }
  }

  static bool _isPermissionGranted(PermissionStatus status) {
    return status.isGranted ||
        status.isLimited ||
        status.isProvisional;
  }

  static Future<bool> checkPermissions() async {
    await _initializePermissions();

    for (final permission in _requiredPermissions) {
      try {
        final status = await permission.status;
        if (!_isPermissionGranted(status)) {
          return false;
        }
      } catch (e) {
        continue;
      }
    }
    return true;
  }

  static Future<bool> requestPermissions(BuildContext context) async {
    bool granted = await checkPermissions();
    if (granted) return true;

    await _initializePermissions();

    final permissionGroups = _groupPermissions();

    for (final group in permissionGroups) {
      final statuses = await group.request();

      final hasGrantedOrLimited = statuses.values.any((status) =>
          _isPermissionGranted(status));

      if (!hasGrantedOrLimited) {
        final hasPermanentlyDenied = statuses.values.any((status) =>
        status.isPermanentlyDenied);

        if (hasPermanentlyDenied) {
          final shouldOpenSettings = await _showPermissionDialog(context, group);
          if (shouldOpenSettings == true) {
            await openAppSettings();
          }
          return false;
        }
      }
    }

    return await checkPermissions();
  }

  static List<List<Permission>> _groupPermissions() {
    if (Platform.isAndroid) {
      return [
        [Permission.camera, Permission.microphone],
        if (_androidSdkInt! >= 33) ...[
          [Permission.photos, Permission.videos, Permission.audio],
        ] else ...[
          [Permission.storage],
        ],
        [Permission.locationWhenInUse],
        if (_androidSdkInt! >= 31) ...[
          [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.bluetoothAdvertise],
        ] else ...[
          [Permission.bluetooth],
        ],
      ];
    } else {
      return [
        [Permission.camera, Permission.microphone],
        [Permission.photosAddOnly],
        [Permission.locationWhenInUse],
        [Permission.bluetooth],
      ];
    }
  }

  static Future<bool?> _showPermissionDialog(BuildContext context, List<Permission> deniedPermissions) {
    final permissionNames = _getPermissionNames(deniedPermissions);

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Разрешения требуются'),
        content: Text(
          'Для корректной работы приложению необходимы следующие разрешения:\n\n'
              '${permissionNames.join('\n')}\n\n'
              'Пожалуйста, предоставьте разрешения в настройках системы.',
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
    );
  }

  static List<String> _getPermissionNames(List<Permission> permissions) {
    return permissions.map((permission) {
      switch (permission) {
        case Permission.camera:
          return '• Камера';
        case Permission.microphone:
          return '• Микрофон';
        case Permission.storage:
          return '• Хранилище';
        case Permission.photos:
          return '• Фотографии';
        case Permission.videos:
          return '• Видео';
        case Permission.audio:
          return '• Аудио файлы';
        case Permission.photosAddOnly:
          return '• Добавление фото';
        case Permission.locationWhenInUse:
          return '• Местоположение';
        case Permission.bluetooth:
          return '• Bluetooth';
        case Permission.bluetoothScan:
          return '• Поиск Bluetooth устройств';
        case Permission.bluetoothConnect:
          return '• Подключение к Bluetooth';
        case Permission.bluetoothAdvertise:
          return '• Реклама Bluetooth';
        default:
          return '• ${permission.toString()}';
      }
    }).toList();
  }

  static Future<Map<Permission, PermissionStatus>> getPermissionStatuses() async {
    await _initializePermissions();
    final Map<Permission, PermissionStatus> statuses = {};

    for (final permission in _requiredPermissions) {
      try {
        statuses[permission] = await permission.status;
      } catch (e) {
        print('Error getting status for ${permission.toString()}: $e');
      }
    }

    return statuses;
  }

  static Future<bool> checkSpecificPermission(Permission permission) async {
    try {
      final status = await permission.status;
      return _isPermissionGranted(status);
    } catch (e) {
      return false;
    }
  }

  static Future<bool> requestSpecificPermission(Permission permission, BuildContext context) async {
    try {
      final status = await permission.request();
      if (_isPermissionGranted(status)) {
        return true;
      } else if (status.isPermanentlyDenied) {
        final shouldOpenSettings = await _showPermissionDialog(context, [permission]);
        if (shouldOpenSettings == true) {
          await openAppSettings();
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}