import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class ApiService {
  final TokenStorage _tokenStorage = TokenStorage();

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

  Future<String?> getToken() async {
    return await _tokenStorage.getKeyServiceAccessToken();
  }

  Future<void> saveToken(String token) async {
    await _tokenStorage.saveKeyServiceAccessToken(token);
  }

  Future<void> clearToken() async {
    await _tokenStorage.clearAll();
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
      
      if (token == null || token.isEmpty) {
        print('[API] ❌ No access token available');
        return {'error': 'Not authenticated. Please login again.'};
      }
      
      final bool isEmail = query.contains('@');
      final body = isEmail 
          ? {'email': query}
          : {'username': query};
      
      print('[API] 📤 Send Friend Request:');
      print('[API]   Query: $query (${isEmail ? "email" : "username"})');
      print('[API]   URL: $baseUrl/friends/request');
      print('[API]   Token: ${token.substring(0, 20)}...');
      print('[API]   Body: ${jsonEncode(body)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('[API] 📥 Friend Request Response:');
      print('[API]   Status: ${response.statusCode}');
      print('[API]   Body: ${response.body}');

      if (response.statusCode == 401) {
        print('[API] ❌ Unauthorized - Token may be invalid or expired');
        return {'error': 'Unauthorized. Please login again.'};
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[API] ❌ Friend Request Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    try {
      final token = await getToken();
      
      if (token == null || token.isEmpty) {
        print('[API] ❌ No access token available');
        return {'error': 'Not authenticated. Please login again.'};
      }
      
      print('[API] 📤 Accept Friend Request:');
      print('[API]   Request ID: $requestId');
      print('[API]   Token: ${token.substring(0, 20)}...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/friends/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'request_id': requestId}),
      ).timeout(const Duration(seconds: 10));

      print('[API] 📥 Accept Response:');
      print('[API]   Status: ${response.statusCode}');
      print('[API]   Body: ${response.body}');

      if (response.statusCode == 401) {
        print('[API] ❌ Unauthorized - Token may be invalid or expired');
        return {'error': 'Unauthorized. Please login again.'};
      }

      try {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[API] ❌ Accept Friend Request Error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  Future<List<dynamic>> getFriendRequests() async {
    try {
      final token = await getToken();
      
      if (token == null || token.isEmpty) {
        print('[API] ❌ No access token available');
        return [];
      }
      
      print('[API] 📤 Get Friend Requests:');
      print('[API]   Token: ${token.substring(0, 20)}...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      print('[API] 📥 Get Friend Requests Response:');
      print('[API]   Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('[API] ❌ Unauthorized - Token may be invalid or expired');
        return [];
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['requests'] ?? [];
      } catch (_) {
        return [];
      }
    } catch (e) {
      print('[API] ❌ Get Friend Requests Error: $e');
      return [];
    }
  }

  Future<List<dynamic>> getFriends() async {
    try {
      final token = await getToken();
      
      if (token == null || token.isEmpty) {
        print('[API] ❌ No access token available');
        return [];
      }
      
      print('[API] 📤 Get Friends List:');
      print('[API]   Token: ${token.substring(0, 20)}...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/friends/list'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      print('[API] 📥 Get Friends Response:');
      print('[API]   Status: ${response.statusCode}');

      if (response.statusCode == 401) {
        print('[API] ❌ Unauthorized - Token may be invalid or expired');
        return [];
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['friends'] ?? [];
      } catch (_) {
        return [];
      }
    } catch (e) {
      print('[API] ❌ Get Friends Error: $e');
      return [];
    }
  }
}
