import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionManager {
  static final List<Permission> _requiredPermissions = [
    Permission.camera,
    Permission.microphone,
    if (Platform.isIOS) Permission.photosAddOnly,
    if (Platform.isAndroid) Permission.storage,
    Permission.locationWhenInUse,
    Permission.bluetooth,
  ];

  static Future<bool> checkPermissions() async {
    for (final permission in _requiredPermissions) {
      final status = await permission.status;
      if (!status.isGranted) return false;
    }
    return true;
  }

  static Future<bool> requestPermissions(BuildContext context) async {
    bool granted = await checkPermissions();
    if (granted) return true;

    final statuses = await _requiredPermissions.request();

    final permanentlyDenied = statuses.entries
        .where((entry) => entry.value.isPermanentlyDenied)
        .map((e) => e.key)
        .toList();

    final stillDenied = statuses.values.any((s) => !s.isGranted);

    if (stillDenied) {
      final shouldOpenSettings = await _showPermissionDialog(context);
      if (shouldOpenSettings == true) {
        await openAppSettings();
      }
      return false;
    }

    return true;
  }

  static Future<bool?> _showPermissionDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'To function properly, the app needs access to camera, microphone, storage, and location. Please grant permissions in system settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
