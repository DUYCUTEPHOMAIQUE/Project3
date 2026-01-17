import 'package:shared_preferences/shared_preferences.dart';
// TODO: Migrate to flutter_secure_storage for production
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized token storage service
/// Quản lý tất cả tokens: Key Service JWT, Nakama session, refresh tokens, user info
class TokenStorage {
  static const String _keyServiceAccessTokenKey = 'key_service_access_token';
  static const String _keyServiceRefreshTokenKey = 'key_service_refresh_token';
  static const String _nakamaSessionTokenKey = 'nakama_session_token';
  static const String _nakamaRefreshTokenKey = 'nakama_refresh_token';
  static const String _nakamaUserIDKey = 'nakama_user_id';
  static const String _userIDKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';

  /// Save Key Service access token
  Future<void> saveKeyServiceAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServiceAccessTokenKey, token);
    print('[TokenStorage] ✅ Saved Key Service access token');
  }

  /// Get Key Service access token
  Future<String?> getKeyServiceAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServiceAccessTokenKey);
  }

  /// Save Key Service refresh token
  Future<void> saveKeyServiceRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServiceRefreshTokenKey, token);
    print('[TokenStorage] ✅ Saved Key Service refresh token');
  }

  /// Get Key Service refresh token
  Future<String?> getKeyServiceRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyServiceRefreshTokenKey);
  }

  /// Save Nakama session token
  Future<void> saveNakamaSessionToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nakamaSessionTokenKey, token);
    print('[TokenStorage] ✅ Saved Nakama session token');
  }

  /// Get Nakama session token
  Future<String?> getNakamaSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nakamaSessionTokenKey);
  }

  /// Save Nakama refresh token
  Future<void> saveNakamaRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nakamaRefreshTokenKey, token);
    print('[TokenStorage] ✅ Saved Nakama refresh token');
  }

  /// Get Nakama refresh token
  Future<String?> getNakamaRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nakamaRefreshTokenKey);
  }

  /// Save Nakama user ID
  Future<void> saveNakamaUserID(String userID) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nakamaUserIDKey, userID);
    print('[TokenStorage] ✅ Saved Nakama user ID: $userID');
  }

  /// Get Nakama user ID
  Future<String?> getNakamaUserID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nakamaUserIDKey);
  }

  /// Save user info
  Future<void> saveUserInfo({
    required String userID,
    required String username,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIDKey, userID);
    await prefs.setString(_usernameKey, username);
    if (email != null) {
      await prefs.setString(_emailKey, email);
    }
    print('[TokenStorage] ✅ Saved user info: $username ($userID)');
  }

  /// Get user ID
  Future<String?> getUserID() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIDKey);
  }

  /// Get username
  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  /// Get email
  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Check if user is authenticated
  /// Returns true if both Key Service token and Nakama session exist
  Future<bool> isAuthenticated() async {
    final keyServiceToken = await getKeyServiceAccessToken();
    final nakamaToken = await getNakamaSessionToken();
    final isAuth = keyServiceToken != null && 
                   keyServiceToken.isNotEmpty &&
                   nakamaToken != null && 
                   nakamaToken.isNotEmpty;
    print('[TokenStorage] 🔍 Auth check: Key Service=${keyServiceToken != null}, Nakama=${nakamaToken != null}, Result=$isAuth');
    return isAuth;
  }

  /// Get all stored tokens (for debugging)
  Future<Map<String, String?>> getAllTokens() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'key_service_access_token': prefs.getString(_keyServiceAccessTokenKey),
      'key_service_refresh_token': prefs.getString(_keyServiceRefreshTokenKey),
      'nakama_session_token': prefs.getString(_nakamaSessionTokenKey),
      'nakama_refresh_token': prefs.getString(_nakamaRefreshTokenKey),
      'nakama_user_id': prefs.getString(_nakamaUserIDKey),
      'user_id': prefs.getString(_userIDKey),
      'username': prefs.getString(_usernameKey),
      'email': prefs.getString(_emailKey),
    };
  }

  /// Clear all tokens and user info
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServiceAccessTokenKey);
    await prefs.remove(_keyServiceRefreshTokenKey);
    await prefs.remove(_nakamaSessionTokenKey);
    await prefs.remove(_nakamaRefreshTokenKey);
    await prefs.remove(_nakamaUserIDKey);
    await prefs.remove(_userIDKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
    print('[TokenStorage] 🗑️  Cleared all tokens and user info');
  }

  /// Print current storage state (for debugging)
  Future<void> printStorageState() async {
    final tokens = await getAllTokens();
    print('[TokenStorage] 📦 Current storage state:');
    tokens.forEach((key, value) {
      if (value != null && value.isNotEmpty) {
        final displayValue = key.contains('token') 
            ? '${value.substring(0, 20)}...' 
            : value;
        print('  $key: $displayValue');
      }
    });
  }
}
