import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class PermissionsTestScreen extends StatefulWidget {
  const PermissionsTestScreen({super.key});

  @override
  State<PermissionsTestScreen> createState() => _PermissionsTestScreenState();
}

class _PermissionsTestScreenState extends State<PermissionsTestScreen> {
  final List<Permission> _permissions = [
    Permission.camera,
    Permission.locationWhenInUse,
    Permission.nearbyWifiDevices,
    Permission.storage,
  ];

  final Map<Permission, PermissionStatus> _statuses = {};

  ConnectivityResult? _connectivityResult;
  StreamSubscription<ConnectivityResult>? _connectivitySub;

  bool _cameraAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadAllStatuses();
    _initConnectivity();
    _checkCamera();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  Future<void> _loadAllStatuses() async {
    for (final perm in _permissions) {
      final status = await perm.status;
      _statuses[perm] = status;
    }
    setState(() {});
  }

  Future<void> _requestPermission(Permission perm) async {
    final status = await perm.request();
    _statuses[perm] = status;
    setState(() {});
  }

  Future<void> _requestAll() async {
    final statuses = await _permissions.request();
    _statuses.addAll(statuses);
    setState(() {});
  }

  String _statusText(PermissionStatus status) {
    if (status.isGranted) return 'Granted';
    if (status.isDenied) return 'Denied';
    if (status.isPermanentlyDenied) return 'Permanently Denied';
    if (status.isRestricted) return 'Restricted';
    if (status.isLimited) return 'Limited';
    return status.toString();
  }

  Future<void> _initConnectivity() async {
    _connectivityResult = (await Connectivity().checkConnectivity()) as ConnectivityResult?;
    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        _connectivityResult = result as ConnectivityResult?;
      });
    }) as StreamSubscription<ConnectivityResult>?;
    setState(() {});
  }

  Future<void> _checkCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraAvailable = cameras.isNotEmpty;
    } catch (e) {
      _cameraAvailable = false;
    }
    setState(() {});
  }

  String get _wifiText {
    switch (_connectivityResult) {
      case ConnectivityResult.wifi:
        return 'Wi-Fi connected';
      case ConnectivityResult.mobile:
        return 'Mobile network';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.none:
        return 'No network';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Permission & Feature Tester')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connectivity status
            Text('Network: $_wifiText', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // Camera availability
            Text('Camera available: ${_cameraAvailable ? 'Yes' : 'No'}',
                style: Theme.of(context).textTheme.titleMedium),
            const Divider(height: 32),
            ElevatedButton(
              onPressed: _requestAll,
              child: const Text('Request All Permissions'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _permissions.length,
                itemBuilder: (context, index) {
                  final perm = _permissions[index];
                  final status = _statuses[perm];
                  return Card(
                    child: ListTile(
                      title: Text(perm.toString().split('.').last),
                      subtitle: Text(status == null
                          ? 'Unknown'
                          : _statusText(status)),
                      trailing: ElevatedButton(
                        onPressed: () => _requestPermission(perm),
                        child: const Text('Request'),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
