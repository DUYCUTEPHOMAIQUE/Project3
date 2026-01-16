import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080/api/v1';
    } else if (Platform.isIOS) {
      return 'http://127.0.0.1:8080/api/v1';
    } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return 'http://127.0.0.1:8080/api/v1';
    }
    return 'http://127.0.0.1:8080/api/v1';
  }
  static const String tokenKey = 'access_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(tokenKey);
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
  }

  Future<Map<String, dynamic>> register(String username, String password, String? email) async {
    final url = '$baseUrl/auth/register';
    final body = {
      'username': username,
      'password': password,
      if (email != null && email.isNotEmpty) 'email': email,
    };
    
    print('[API] Register Request:');
    print('  URL: $url');
    print('  Body: ${jsonEncode(body)}');
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('[API] Register Response:');
      print('  Status Code: ${response.statusCode}');
      print('  Headers: ${response.headers}');
      print('  Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        print('[API] Parse success: $data');
        return data;
      } else {
        print('[API] Error status: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          print('[API] Error data: $errorData');
          return errorData;
        } catch (e) {
          print('[API] Failed to parse error response: $e');
          return {'error': 'Server error: ${response.statusCode}'};
        }
      }
    } catch (e, stackTrace) {
      print('[API] Exception:');
      print('  Error: $e');
      print('  Stack: $stackTrace');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
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

      if (response.statusCode == 200 && data['access_token'] != null) {
        await saveToken(data['access_token']);
      }
      return data;
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> sendFriendRequest(String query) async {
    try {
      final token = await getToken();
      
      final bool isEmail = query.contains('@');
      final body = isEmail 
          ? {'email': query}
          : {'username': query};
      
      print('[API] Send Friend Request:');
      print('  Query: $query (${isEmail ? "email" : "username"})');
      print('  Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('[API] Friend Request Response:');
      print('  Status: ${response.statusCode}');
      print('  Body: ${response.body}');

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[API] Friend Request Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/friends/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'request_id': requestId}),
      ).timeout(const Duration(seconds: 10));

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      return {'error': 'Network error: $e'};
    }
  }

  Future<List<dynamic>> getFriendRequests() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['requests'] ?? [];
      } catch (_) {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<List<dynamic>> getFriends() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/friends/list'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['friends'] ?? [];
      } catch (_) {
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}
