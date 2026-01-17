import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
// TODO: Migrate to flutter_secure_storage for production
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized token storage service
/// Quản lý tất cả tokens: Key Service JWT, Nakama session, refresh tokens, user info
class TokenStorage {
  static const String _keyServiceAccessTokenKey = 'key_service_access_token';
  static const String _keyServiceRefreshTokenKey = 'key_service_refresh_token';
  static const String _identityKeyPairKey = 'identity_key_pair_json';
  static const String _nakamaSessionTokenKey = 'nakama_session_token';
  static const String _nakamaRefreshTokenKey = 'nakama_refresh_token';
  static const String _nakamaUserIDKey = 'nakama_user_id';
  static const String _userIDKey = 'user_id';
  static const String _usernameKey = 'username';
  static const String _emailKey = 'email';
  static const String _channelIdPrefix = 'channel_id_'; // channel_id_{friendUserId}
  static const String _signedPrekeyIdKey = 'signed_prekey_id';
  static const String _oneTimePrekeyIdsKey = 'one_time_prekey_ids'; // JSON array of IDs

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

  /// Save identity key pair (used for E2EE sessions)
  Future<void> saveIdentityKeyPair(String identityKeyPairJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_identityKeyPairKey, identityKeyPairJson);
    print('[TokenStorage] ✅ Saved identity key pair');
  }

  /// Get identity key pair
  Future<String?> getIdentityKeyPair() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_identityKeyPairKey);
  }

  /// Save channel ID for a friend
  Future<void> saveChannelId(String friendUserId, String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_channelIdPrefix$friendUserId', channelId);
    print('[TokenStorage] ✅ Saved channel ID for friend $friendUserId: $channelId');
  }

  /// Get channel ID for a friend
  Future<String?> getChannelId(String friendUserId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_channelIdPrefix$friendUserId');
  }

  /// Clear channel ID for a friend
  Future<void> clearChannelId(String friendUserId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_channelIdPrefix$friendUserId');
    print('[TokenStorage] 🗑️  Cleared channel ID for friend: $friendUserId');
  }

  /// Save prekey IDs (signed prekey ID and one-time prekey IDs)
  Future<void> savePrekeyIds(int signedPrekeyId, List<int> oneTimePrekeyIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_signedPrekeyIdKey, signedPrekeyId);
    await prefs.setString(_oneTimePrekeyIdsKey, jsonEncode(oneTimePrekeyIds));
    print('[TokenStorage] ✅ Saved prekey IDs: signed=$signedPrekeyId, one-time=$oneTimePrekeyIds');
  }

  /// Get signed prekey ID
  Future<int?> getSignedPrekeyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_signedPrekeyIdKey);
  }

  /// Get one-time prekey IDs
  Future<List<int>> getOneTimePrekeyIds() async {
    final prefs = await SharedPreferences.getInstance();
    final idsJson = prefs.getString(_oneTimePrekeyIdsKey);
    if (idsJson == null || idsJson.isEmpty) {
      return [];
    }
    try {
      final ids = jsonDecode(idsJson) as List<dynamic>;
      return ids.map((id) => id as int).toList();
    } catch (e) {
      print('[TokenStorage] ⚠️  Error parsing one-time prekey IDs: $e');
      return [];
    }
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

  /// Clear all tokens and user info (but keep identity key for device re-registration)
  /// Identity key should only be cleared when explicitly requested (e.g., account deletion)
  Future<void> clearAll({bool clearIdentityKey = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyServiceAccessTokenKey);
    await prefs.remove(_keyServiceRefreshTokenKey);
    await prefs.remove(_nakamaSessionTokenKey);
    await prefs.remove(_nakamaRefreshTokenKey);
    await prefs.remove(_nakamaUserIDKey);
    await prefs.remove(_userIDKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_emailKey);
    
    if (clearIdentityKey) {
      await prefs.remove(_identityKeyPairKey);
      print('[TokenStorage] 🗑️  Cleared all tokens, user info, and identity key');
    } else {
      print('[TokenStorage] 🗑️  Cleared all tokens and user info (identity key preserved)');
    }
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
