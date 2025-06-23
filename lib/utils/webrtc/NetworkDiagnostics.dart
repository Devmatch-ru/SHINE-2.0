import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

import 'NetworkUtils.dart';

/// Класс для диагностики сетевых проблем
class NetworkDiagnostics {
  static Future<NetworkDiagnosticResult> runFullDiagnostic() async {
    final result = NetworkDiagnosticResult();

    try {
      // 1. Проверка сетевых интерфейсов
      result.debugInfo = await NetworkUtils.getNetworkDebugInfo();

      // 2. Получение оптимального IP
      result.optimalIP = await NetworkUtils.getOptimalWiFiIP();

      // 3. Проверка доступности локальной сети
      if (result.optimalIP != null) {
        result.networkReachable = await _testNetworkConnectivity(result.optimalIP!);
        result.gatewayReachable = await _testGatewayConnectivity(result.optimalIP!);
      }

      // 4. Проверка портов
      result.discoveryPortAvailable = await _testPortAvailability(9000);
      result.signalingPortAvailable = await _testPortAvailability(8080);

      // 5. Анализ результатов
      result.overallStatus = _analyzeResults(result);
      result.recommendations = _generateRecommendations(result);

    } catch (e) {
      result.error = e.toString();
      result.overallStatus = NetworkStatus.error;
    }

    return result;
  }

  static Future<bool> _testNetworkConnectivity(String localIP) async {
    try {
      // Пингуем соседние адреса в сети
      final baseIP = localIP.substring(0, localIP.lastIndexOf('.'));

      for (int i = 1; i <= 5; i++) {
        final testIP = '$baseIP.$i';
        if (testIP != localIP) {
          final reachable = await NetworkUtils.isIPReachable(testIP, 80, timeout: Duration(seconds: 1));
          if (reachable) return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _testGatewayConnectivity(String localIP) async {
    try {
      // Определяем вероятный адрес шлюза
      final baseIP = localIP.substring(0, localIP.lastIndexOf('.'));
      final gatewayIPs = ['$baseIP.1', '$baseIP.254'];

      for (final gatewayIP in gatewayIPs) {
        final reachable = await NetworkUtils.isIPReachable(gatewayIP, 80, timeout: Duration(seconds: 2));
        if (reachable) return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _testPortAvailability(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  static NetworkStatus _analyzeResults(NetworkDiagnosticResult result) {
    if (result.error != null) return NetworkStatus.error;
    if (result.optimalIP == null) return NetworkStatus.noValidIP;

    if (!result.discoveryPortAvailable || !result.signalingPortAvailable) {
      return NetworkStatus.portConflict;
    }

    if (!result.networkReachable) return NetworkStatus.networkIssue;
    if (!result.gatewayReachable) return NetworkStatus.gatewayIssue;

    return NetworkStatus.ok;
  }

  static List<String> _generateRecommendations(NetworkDiagnosticResult result) {
    final recommendations = <String>[];

    switch (result.overallStatus) {
      case NetworkStatus.noValidIP:
        recommendations.addAll([
          'Проверьте подключение к Wi-Fi сети',
          'Убедитесь, что устройство подключено к локальной сети (192.168.x.x)',
          'Перезапустите Wi-Fi соединение',
          'Проверьте настройки сети в системе',
        ]);
        break;

      case NetworkStatus.portConflict:
        recommendations.addAll([
          'Закройте другие приложения, использующие порты 8080 или 9000',
          'Перезапустите приложение',
          'Проверьте запущенные сетевые службы',
        ]);
        break;

      case NetworkStatus.networkIssue:
        recommendations.addAll([
          'Проверьте настройки Wi-Fi роутера',
          'Убедитесь, что устройства находятся в одной сети',
          'Проверьте настройки брандмауэра',
          'Попробуйте переподключиться к Wi-Fi',
        ]);
        break;

      case NetworkStatus.gatewayIssue:
        recommendations.addAll([
          'Проверьте подключение к интернету',
          'Перезагрузите Wi-Fi роутер',
          'Проверьте кабельное подключение роутера',
        ]);
        break;

      case NetworkStatus.ok:
        recommendations.addAll([
          'Сеть настроена корректно',
          'Можно начинать использование приложения',
        ]);
        break;

      case NetworkStatus.error:
        recommendations.addAll([
          'Произошла ошибка диагностики',
          'Перезапустите приложение',
          'Проверьте разрешения приложения',
        ]);
        break;
    }

    return recommendations;
  }
}

enum NetworkStatus {
  ok,
  noValidIP,
  portConflict,
  networkIssue,
  gatewayIssue,
  error,
}

class NetworkDiagnosticResult {
  String? optimalIP;
  Map<String, dynamic>? debugInfo;
  bool networkReachable = false;
  bool gatewayReachable = false;
  bool discoveryPortAvailable = false;
  bool signalingPortAvailable = false;
  NetworkStatus overallStatus = NetworkStatus.error;
  List<String> recommendations = [];
  String? error;

  Map<String, dynamic> toJson() {
    return {
      'optimalIP': optimalIP,
      'debugInfo': debugInfo,
      'networkReachable': networkReachable,
      'gatewayReachable': gatewayReachable,
      'discoveryPortAvailable': discoveryPortAvailable,
      'signalingPortAvailable': signalingPortAvailable,
      'overallStatus': overallStatus.toString(),
      'recommendations': recommendations,
      'error': error,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}

/// Widget для отображения диагностики сети
class NetworkDiagnosticsWidget extends StatefulWidget {
  const NetworkDiagnosticsWidget({Key? key}) : super(key: key);

  @override
  State<NetworkDiagnosticsWidget> createState() => _NetworkDiagnosticsWidgetState();
}

class _NetworkDiagnosticsWidgetState extends State<NetworkDiagnosticsWidget> {
  NetworkDiagnosticResult? _result;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
      _result = null;
    });

    try {
      final result = await NetworkDiagnostics.runFullDiagnostic();
      setState(() {
        _result = result;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _result = NetworkDiagnosticResult()
          ..error = e.toString()
          ..overallStatus = NetworkStatus.error;
        _isRunning = false;
      });
    }
  }

  Color _getStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.ok:
        return Colors.green;
      case NetworkStatus.noValidIP:
      case NetworkStatus.portConflict:
      case NetworkStatus.networkIssue:
        return Colors.orange;
      case NetworkStatus.gatewayIssue:
        return Colors.yellow;
      case NetworkStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.ok:
        return 'Сеть работает корректно';
      case NetworkStatus.noValidIP:
        return 'Не найден валидный IP адрес';
      case NetworkStatus.portConflict:
        return 'Конфликт портов';
      case NetworkStatus.networkIssue:
        return 'Проблемы с сетью';
      case NetworkStatus.gatewayIssue:
        return 'Проблемы со шлюзом';
      case NetworkStatus.error:
        return 'Ошибка диагностики';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Диагностика сети'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostic,
          ),
        ],
      ),
      body: _isRunning
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Выполняется диагностика сети...'),
          ],
        ),
      )
          : _result == null
          ? Center(child: Text('Нет данных диагностики'))
          : _buildDiagnosticResults(),
    );
  }

  Widget _buildDiagnosticResults() {
    final result = _result!;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Общий статус
          Card(
            color: _getStatusColor(result.overallStatus).withOpacity(0.1),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    result.overallStatus == NetworkStatus.ok
                        ? Icons.check_circle
                        : Icons.warning,
                    color: _getStatusColor(result.overallStatus),
                    size: 32,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Статус сети',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _getStatusText(result.overallStatus),
                          style: TextStyle(
                            color: _getStatusColor(result.overallStatus),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Детали
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Детали диагностики',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 8),
                  _buildDetailRow('IP адрес', result.optimalIP ?? 'Не найден'),
                  _buildDetailRow('Сеть доступна', result.networkReachable ? 'Да' : 'Нет'),
                  _buildDetailRow('Шлюз доступен', result.gatewayReachable ? 'Да' : 'Нет'),
                  _buildDetailRow('Порт 9000 свободен', result.discoveryPortAvailable ? 'Да' : 'Нет'),
                  _buildDetailRow('Порт 8080 свободен', result.signalingPortAvailable ? 'Да' : 'Нет'),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Рекомендации
          if (result.recommendations.isNotEmpty)
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Рекомендации',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    ...result.recommendations.map((rec) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• '),
                          Expanded(child: Text(rec)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),

          SizedBox(height: 16),

          // Техническая информация
          ExpansionTile(
            title: Text('Техническая информация'),
            children: [
              Padding(
                padding: EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.debugInfo?.toString() ?? 'Нет данных',
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label + ':'),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}