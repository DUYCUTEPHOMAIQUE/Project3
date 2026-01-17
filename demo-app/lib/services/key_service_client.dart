import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Client để gọi Key Service API
/// Refactored từ ApiService để chỉ focus vào Key Service
class KeyServiceClient {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8099/api/v1';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8099/api/v1';
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'http://127.0.0.1:8099/api/v1';
    }
    return 'http://127.0.0.1:8099/api/v1';
  }

  /// Register user với Key Service
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    String? email,
  }) async {
    final url = '$baseUrl/auth/register';
    final body = {
      'username': username,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
    };

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        try {
          return jsonDecode(response.body) as Map<String, dynamic>;
        } catch (e) {
          return {'error': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  /// Login với Key Service
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 10));

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {'error': 'Invalid response from server'};
      }

      return data;
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  /// Refresh token
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(const Duration(seconds: 10));

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {'error': 'Invalid response from server'};
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  /// Verify token với Key Service (dùng cho Nakama hook)
  /// NOTE: Endpoint này cần được implement trong Key Service
  Future<Map<String, dynamic>> verifyToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/verify'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (e) {
        return {'error': 'Invalid response from server'};
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }
}
