import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkUtils {
  static final NetworkUtils _instance = NetworkUtils._internal();
  factory NetworkUtils() => _instance;
  NetworkUtils._internal();

  static Future<String?> getOptimalWiFiIP() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();

      if (wifiIP != null && _isValidLocalIP(wifiIP)) {
        return wifiIP;
      }

      final optimalIP = await _findBestLocalIP();
      if (optimalIP != null) {
        return optimalIP;
      }
      final anyLocalIP = await _getAnyValidLocalIP();
      if (anyLocalIP != null) {
        return anyLocalIP;
      }
      return null;
    } catch (e) {
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
        if (interface.addresses.isEmpty) continue;
        for (final address in interface.addresses) {
          final ip = address.address;
          final priority = _getIPPriority(ip);

          if (priority > bestPriority) {
            bestPriority = priority;
            bestIP = ip;
          }
        }
      }

      return bestIP;
    } catch (e) {
      return null;
    }
  }

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
      return null;
    }
  }

  static int _getIPPriority(String ip) {
    if (!_isValidIPv4(ip)) return -1;

    if (_isLoopback(ip)) return -1;
    if (_isAPIPAAddress(ip)) return -1;
    if (_isCarrierGradeNAT(ip)) return -1;

    if (_is192Network(ip)) return 100;
    if (_is10Network(ip)) return 80;
    if (_is172Network(ip)) return 70;

    if (_isPrivateNetwork(ip)) return 50;

    return 10;
  }

  static bool _isValidLocalIP(String ip) {
    if (!_isValidIPv4(ip)) return false;
    if (_isLoopback(ip)) return false;
    if (_isAPIPAAddress(ip)) return false;
    if (_isCarrierGradeNAT(ip)) return false;

    return true;
  }

  static bool _isValidIPv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }

    return true;
  }

  static bool _isLoopback(String ip) {
    return ip.startsWith('127.');
  }

  static bool _isAPIPAAddress(String ip) {
    return ip.startsWith('169.254.');
  }

  static bool _isCarrierGradeNAT(String ip) {
    if (!ip.startsWith('100.')) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    final secondOctet = int.tryParse(parts[1]);
    if (secondOctet == null) return false;

    return secondOctet >= 64 && secondOctet <= 127;
  }

  static bool _is192Network(String ip) {
    return ip.startsWith('192.168.');
  }

  static bool _is10Network(String ip) {
    return ip.startsWith('10.');
  }

  static bool _is172Network(String ip) {
    if (!ip.startsWith('172.')) return false;

    final parts = ip.split('.');
    if (parts.length != 4) return false;

    final secondOctet = int.tryParse(parts[1]);
    if (secondOctet == null) return false;

    return secondOctet >= 16 && secondOctet <= 31;
  }

  static bool _isPrivateNetwork(String ip) {
    return _is192Network(ip) || _is10Network(ip) || _is172Network(ip);
  }

  static Future<Map<String, dynamic>> getNetworkDebugInfo() async {
    final debugInfo = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'interfaces': <Map<String, dynamic>>[],
      'optimalIP': null,
      'networkInfoIP': null,
    };

    try {
      final networkInfo = NetworkInfo();
      debugInfo['networkInfoIP'] = await networkInfo.getWifiIP();

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

      debugInfo['optimalIP'] = await getOptimalWiFiIP();
    } catch (e) {
      debugInfo['error'] = e.toString();
    }

    return debugInfo;
  }

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

  static List<String> generateIPRange(String baseIP) {
    final parts = baseIP.split('.');
    if (parts.length != 4) return [];

    final baseNetwork = '${parts[0]}.${parts[1]}.${parts[2]}';
    final ips = <String>[];

    for (int i = 1; i <= 254; i++) {
      ips.add('$baseNetwork.$i');
    }

    return ips;
  }

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