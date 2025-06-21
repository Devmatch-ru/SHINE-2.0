import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

import '../core/error_handler.dart';
import '../core/logger.dart';


class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Logger _logger = Logger();
  final ErrorHandler _errorHandler = ErrorHandler();

  Future<String?> getWifiIP() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        if (interface.name.contains('wlan') || interface.name.contains('wifi')) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 &&
                !addr.address.startsWith('127.') &&
                !addr.address.startsWith('10.0.0.')) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('Error getting Wi-Fi IP: $e');
    }
    return null;
  }

  Future<http.Response> post(
      String url,
      Map<String, dynamic> data, {
        Duration timeout = const Duration(seconds: 5),
        Map<String, String>? headers,
      }) async {
    try {
      _logger.log('NetworkService', 'POST $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
        body: jsonEncode(data),
      ).timeout(timeout);

      _logger.log('NetworkService', 'POST $url - Status: ${response.statusCode}');
      return response;
    } catch (e) {
      _errorHandler.handleError('NetworkService.post', e);
      rethrow;
    }
  }

  Future<http.Response> get(
      String url, {
        Duration timeout = const Duration(seconds: 5),
        Map<String, String>? headers,
      }) async {
    try {
      _logger.log('NetworkService', 'GET $url');

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(timeout);

      _logger.log('NetworkService', 'GET $url - Status: ${response.statusCode}');
      return response;
    } catch (e) {
      _errorHandler.handleError('NetworkService.get', e);
      rethrow;
    }
  }
}