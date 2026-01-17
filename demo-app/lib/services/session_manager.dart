import 'package:shared_preferences/shared_preferences.dart';
// TODO: Migrate to flutter_secure_storage for production
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Quản lý session tokens cho cả Key Service và Nakama
class SessionManager {
  static const String _keyServiceTokenKey = 'key_service_token';
  static const String _nakamaSessionTokenKey = 'nakama_session_token';
  static const String _nakamaSessionKey = 'nakama_session';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  /// Lưu Key Service JWT token
  Future<void> saveKeyServiceToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServiceTokenKey, token);
  }

  /// Lấy Key Service JWT token
  Future<String?> getKeyServiceToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServiceTokenKey);
  }

  /// Lưu Nakama session token
  Future<void> saveNakamaSessionToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nakamaSessionTokenKey, token);
  }

  /// Lấy Nakama session token
  Future<String?> getNakamaSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nakamaSessionTokenKey);
  }

  /// Lưu full Nakama session data
  Future<void> saveNakamaSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    // Convert Map to JSON string để lưu
    final sessionJson = session.toString(); // Simple approach
    // TODO: Use proper JSON encoding
    await prefs.setString(_nakamaSessionKey, sessionJson);
  }

  /// Lấy Nakama session data
  Future<Map<String, dynamic>?> getNakamaSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString(_nakamaSessionKey);
    if (sessionJson == null) return null;
    // TODO: Parse JSON properly
    return {}; // Placeholder
  }

  /// Lưu user info
  Future<void> saveUserInfo(String userId, String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_usernameKey, username);
  }

  /// Lấy user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Lấy username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Kiểm tra xem user đã authenticated chưa
  Future<bool> isAuthenticated() async {
    final keyServiceToken = await getKeyServiceToken();
    final nakamaToken = await getNakamaSessionToken();
    return keyServiceToken != null && 
           keyServiceToken.isNotEmpty &&
           nakamaToken != null && 
           nakamaToken.isNotEmpty;
  }

  /// Clear tất cả session data
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServiceTokenKey);
    await prefs.remove(_nakamaSessionTokenKey);
    await prefs.remove(_nakamaSessionKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_usernameKey);
  }
}
