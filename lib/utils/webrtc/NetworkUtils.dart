import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static final NetworkUtils _instance = NetworkUtils._internal();
  factory NetworkUtils() => _instance;
  NetworkUtils._internal();

  /// Получает оптимальный IPv4 адрес для WebRTC соединения
  /// Приоритет: 192.168.x.x > 10.x.x.x > 172.16-31.x.x > другие IPv4
  static Future<String?> getOptimalWiFiIP() async {
    try {
      // Сначала пробуем стандартный способ
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();

      if (wifiIP != null && _isValidLocalIP(wifiIP)) {
        print('NetworkUtils: Found valid WiFi IP via NetworkInfo: $wifiIP');
        return wifiIP;
      }

      // Если стандартный способ не сработал, ищем среди всех интерфейсов
      final optimalIP = await _findBestLocalIP();
      if (optimalIP != null) {
        print('NetworkUtils: Found optimal IP via interfaces: $optimalIP');
        return optimalIP;
      }

      // Последняя попытка - получить любой валидный локальный IP
      final anyLocalIP = await _getAnyValidLocalIP();
      if (anyLocalIP != null) {
        print('NetworkUtils: Found any valid local IP: $anyLocalIP');
        return anyLocalIP;
      }

      print('NetworkUtils: No valid local IP found');
      return null;
    } catch (e) {
      print('NetworkUtils: Error getting optimal WiFi IP: $e');
      return null;
    }
  }

  /// Поиск лучшего локального IP среди всех сетевых интерфейсов
  static Future<String?> _findBestLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      String? bestIP;
      int bestPriority = -1;

      for (final interface in interfaces) {
        // Пропускаем неактивные интерфейсы
        if (interface.addresses.isEmpty) continue;

        print('NetworkUtils: Checking interface ${interface.name}');

        for (final address in interface.addresses) {
          final ip = address.address;
          final priority = _getIPPriority(ip);

          print('NetworkUtils: Interface ${interface.name}, IP: $ip, Priority: $priority');

          if (priority > bestPriority) {
            bestPriority = priority;
            bestIP = ip;
          }
        }
      }

      return bestIP;
    } catch (e) {
      print('NetworkUtils: Error finding best local IP: $e');
      return null;
    }
  }

  /// Получение любого валидного локального IP
  static Future<String?> _getAnyValidLocalIP() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          final ip = address.address;
          if (_isValidLocalIP(ip)) {
            return ip;
          }
        }
      }

      return null;
    } catch (e) {
      print('NetworkUtils: Error getting any valid local IP: $e');
      return null;
    }
  }

  /// Определяет приоритет IP адреса
  /// Чем выше число, тем лучше адрес для WebRTC
  static int _getIPPriority(String ip) {
    if (!_isValidIPv4(ip)) return -1;

    // Исключаем нежелательные адреса
    if (_isLoopback(ip)) return -1;
    if (_isAPIPAAddress(ip)) return -1;
    if (_isCarrierGradeNAT(ip)) return -1;

    // Приоритеты для локальных сетей
    if (_is192Network(ip)) return 100; // Наивысший приоритет
    if (_is10Network(ip)) return 80;   // Высокий приоритет
    if (_is172Network(ip)) return 70;  // Средний приоритет

    // Другие RFC1918 адреса
    if (_isPrivateNetwork(ip)) return 50;

    // Публичные адреса (обычно не то что нам нужно для локальной сети)
    return 10;
  }

  /// Проверяет, является ли IP адрес валидным для WebRTC соединения
  static bool _isValidLocalIP(String ip) {
    if (!_isValidIPv4(ip)) return false;
    if (_isLoopback(ip)) return false;
    if (_isAPIPAAddress(ip)) return false;
    if (_isCarrierGradeNAT(ip)) return false;

    return true;
  }

  /// Проверка на валидный IPv4 адрес
  static bool _isValidIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  /// Проверка на loopback адрес (127.x.x.x)
  static bool _isLoopback(String ip) {
    return ip.startsWith('127.');
  }

  /// Проверка на APIPA адрес (169.254.x.x)
  static bool _isAPIPAAddress(String ip) {
    return ip.startsWith('169.254.');
  }

  /// Проверка на Carrier Grade NAT (100.64.x.x - 100.127.x.x)
  static bool _isCarrierGradeNAT(String ip) {
    if (!ip.startsWith('100.')) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    final secondOctet = int.tryParse(parts[1]);
    if (secondOctet == null) return false;

    return secondOctet >= 64 && secondOctet <= 127;
  }

  /// Проверка на сеть 192.168.x.x
  static bool _is192Network(String ip) {
    return ip.startsWith('192.168.');
  }

  /// Проверка на сеть 10.x.x.x
  static bool _is10Network(String ip) {
    return ip.startsWith('10.');
  }

  /// Проверка на сеть 172.16.x.x - 172.31.x.x
  static bool _is172Network(String ip) {
    if (!ip.startsWith('172.')) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    final secondOctet = int.tryParse(parts[1]);
    if (secondOctet == null) return false;

    return secondOctet >= 16 && secondOctet <= 31;
  }

  /// Проверка на любую приватную сеть (RFC1918)
  static bool _isPrivateNetwork(String ip) {
    return _is192Network(ip) || _is10Network(ip) || _is172Network(ip);
  }

  /// Получает информацию о всех сетевых интерфейсах для отладки
  static Future<Map<String, dynamic>> getNetworkDebugInfo() async {
    final debugInfo = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'interfaces': <Map<String, dynamic>>[],
      'optimalIP': null,
      'networkInfoIP': null,
    };

    try {
      // Информация через NetworkInfo
      final networkInfo = NetworkInfo();
      debugInfo['networkInfoIP'] = await networkInfo.getWifiIP();

      // Информация через NetworkInterface
      final interfaces = await NetworkInterface.list(
        includeLoopback: true,
        type: InternetAddressType.any,
      );

      for (final interface in interfaces) {
        final interfaceInfo = <String, dynamic>{
          'name': interface.name,
          'addresses': <Map<String, dynamic>>[],
        };

        for (final address in interface.addresses) {
          final addressInfo = <String, dynamic>{
            'address': address.address,
            'type': address.type.name,
            'isLoopback': address.isLoopback,
            'isIPv4': address.type == InternetAddressType.IPv4,
            'priority': address.type == InternetAddressType.IPv4
                ? _getIPPriority(address.address)
                : -1,
            'isValid': address.type == InternetAddressType.IPv4
                ? _isValidLocalIP(address.address)
                : false,
          };

          interfaceInfo['addresses'].add(addressInfo);
        }

        debugInfo['interfaces'].add(interfaceInfo);
      }

      // Оптимальный IP
      debugInfo['optimalIP'] = await getOptimalWiFiIP();
    } catch (e) {
      debugInfo['error'] = e.toString();
    }

    return debugInfo;
  }

  /// Проверяет, находятся ли два IP в одной подсети
  static bool areInSameSubnet(String ip1, String ip2, {String subnet = '255.255.255.0'}) {
    try {
      final addr1 = InternetAddress(ip1);
      final addr2 = InternetAddress(ip2);
      final mask = InternetAddress(subnet);

      final ip1Bytes = addr1.rawAddress;
      final ip2Bytes = addr2.rawAddress;
      final maskBytes = mask.rawAddress;

      if (ip1Bytes.length != ip2Bytes.length ||
          ip1Bytes.length != maskBytes.length) {
        return false;
      }

      for (int i = 0; i < ip1Bytes.length; i++) {
        if ((ip1Bytes[i] & maskBytes[i]) != (ip2Bytes[i] & maskBytes[i])) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Генерирует диапазон IP адресов для сканирования
  static List<String> generateIPRange(String baseIP) {
    final parts = baseIP.split('.');
    if (parts.length != 4) return [];

    final baseNetwork = '${parts[0]}.${parts[1]}.${parts[2]}';
    final ips = <String>[];

    // Генерируем адреса от .1 до .254
    for (int i = 1; i <= 254; i++) {
      ips.add('$baseNetwork.$i');
    }

    return ips;
  }

  /// Проверяет доступность IP адреса
  static Future<bool> isIPReachable(String ip, int port, {Duration timeout = const Duration(seconds: 1)}) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      await socket.close();
      return true;
    } catch (e) {
      return false;
    }
  }
}