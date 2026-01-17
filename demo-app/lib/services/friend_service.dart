import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/friend/friend.dart';
import '../models/friend/friend_request.dart';
import 'token_storage.dart';

class FriendService {
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

  Future<String?> _getToken() async {
    final token = await _tokenStorage.getKeyServiceAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }
    return token;
  }

  /// Send a friend request to another user by username or email
  Future<Map<String, dynamic>> sendFriendRequest(String query) async {
    final token = await _getToken();
    if (token == null) {
      return {'error': 'Not authenticated. Please login again.'};
    }

    final bool isEmail = query.contains('@');
    final body = isEmail 
        ? {'email': query}
        : {'username': query};
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return {'error': 'Unauthorized. Please login again.'};
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('[FriendService] ✅ Friend request sent to $query');
        } else {
          print('[FriendService] ❌ Failed to send request: ${data['error']}');
        }
        return data;
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  /// Accept a pending friend request
  Future<Map<String, dynamic>> acceptFriendRequest(String requestId) async {
    final token = await _getToken();
    if (token == null) {
      return {'error': 'Not authenticated. Please login again.'};
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'request_id': requestId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return {'error': 'Unauthorized. Please login again.'};
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('[FriendService] ✅ Friend request accepted');
        } else {
          print('[FriendService] ❌ Failed to accept: ${data['error']}');
        }
        return data;
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  /// Reject a pending friend request
  Future<Map<String, dynamic>> rejectFriendRequest(String requestId) async {
    final token = await _getToken();
    if (token == null) {
      return {'error': 'Not authenticated. Please login again.'};
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/reject'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'request_id': requestId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return {'error': 'Unauthorized. Please login again.'};
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('[FriendService] ✅ Friend request rejected');
        } else {
          print('[FriendService] ❌ Failed to reject: ${data['error']}');
        }
        return data;
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  /// Remove a friend from the friend list
  Future<Map<String, dynamic>> removeFriend(String friendUserId) async {
    final token = await _getToken();
    if (token == null) {
      return {'error': 'Not authenticated. Please login again.'};
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/friends/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'friend_user_id': friendUserId}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return {'error': 'Unauthorized. Please login again.'};
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('[FriendService] ✅ Friend removed');
        } else {
          print('[FriendService] ❌ Failed to remove: ${data['error']}');
        }
        return data;
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return {'error': 'Invalid response: ${response.statusCode}'};
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return {'error': 'Network error: $e'};
    }
  }

  /// Get pending friend requests received by the current user
  Future<List<FriendRequest>> getFriendRequests() async {
    final token = await _getToken();
    if (token == null) {
      return [];
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return [];
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final requests = data['requests'] as List<dynamic>? ?? [];
        
        return requests
            .map((r) => FriendRequest.fromJson(r as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return [];
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return [];
    }
  }

  /// Get friend requests sent by the current user
  Future<List<FriendRequest>> getSentFriendRequests() async {
    final token = await _getToken();
    if (token == null) {
      return [];
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/requests/sent'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return [];
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final requests = data['requests'] as List<dynamic>? ?? [];
        
        return requests
            .map((r) => FriendRequest.fromJson(r as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return [];
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return [];
    }
  }

  /// Get the list of friends for the current user
  Future<List<Friend>> getFriends() async {
    final token = await _getToken();
    if (token == null) {
      return [];
    }
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/friends/list'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return [];
      }

      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final friends = data['friends'] as List<dynamic>? ?? [];
        
        return friends
            .map((f) => Friend.fromJson(f as Map<String, dynamic>))
            .toList();
      } catch (e) {
        print('[FriendService] ❌ Parse error: $e');
        return [];
      }
    } catch (e) {
      print('[FriendService] ❌ Network error: $e');
      return [];
    }
  }
}
