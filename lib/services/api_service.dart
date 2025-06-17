import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model/user_model.dart';

class ApiService {
  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> _makeRequest(
    String endpoint,
    String method,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse(ApiConfig.baseUrl + endpoint);
    final headers = {'Content-Type': 'application/json'};

    http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
          break;
        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method');
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonBody = json.decode(response.body);
        if (jsonBody is Map<String, dynamic>) {
          if (jsonBody.containsKey('error') &&
              jsonBody.containsKey('success')) {
            if (!jsonBody['success']) {
              throw Exception(jsonBody['error'] ?? 'Unknown error occurred');
            }
          } else if (jsonBody['error'] != null) {
            throw Exception(jsonBody['error'].toString());
          }
          return jsonBody;
        }
        return jsonBody;
      } else {
        throw Exception(
          'Request failed with status: ${response.statusCode}\nBody: ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> register(UserModel user) async {
    return _makeRequest(
      ApiConfig.register,
      'POST',
      user.toJson(),
    );
  }

  Future<Map<String, dynamic>> verifyCode(int code) async {
    return _makeRequest(
      ApiConfig.verifyCode,
      'POST',
      {'code': code},
    );
  }

  Future<Map<String, dynamic>> sendCode(String email) async {
    return _makeRequest(
      ApiConfig.sendCode,
      'POST',
      {'email': email},
    );
  }

  Future<Map<String, dynamic>> authenticate(UserModel user) async {
    return _makeRequest(
      ApiConfig.auth,
      'POST',
      user.toJson(),
    );
  }

  Future<Map<String, dynamic>> resetPassword(
      int code, String newPassword) async {
    try {
      final response = await _makeRequest(
        ApiConfig.passwordReset,
        'PATCH',
        {
          'code': code,
          'password': newPassword,
        },
      );
      return response;
    } catch (e) {
      print('Password reset failed: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteAccountWithCode(int code) async {
    return _makeRequest(
      ApiConfig.deleteAccount,
      'DELETE',
      {'code': code},
    );
  }

  void dispose() {
    _client.close();
  }
}
