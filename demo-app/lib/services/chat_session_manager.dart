import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../bridge_generated/ffi/api.dart' as api;
import '../services/device_service.dart';
import '../services/device_manager.dart';
import 'token_storage.dart';

/// Manages E2EE chat sessions between users
/// Handles X3DH session creation, persistence, and encryption/decryption
class ChatSessionManager {
  final TokenStorage _tokenStorage = TokenStorage();
  final DeviceManager _deviceManager = DeviceManager();
  final DeviceService _deviceService = DeviceService();
  
  // In-memory session cache: friendUserId -> sessionId
  final Map<String, String> _sessionCache = {};
  // Ephemeral key cache: friendUserId -> ephemeralKey (for initiator sessions)
  final Map<String, String> _ephemeralKeyCache = {};
  
  static const String _sessionPrefix = 'chat_session_';
  static const String _ephemeralKeyPrefix = 'ephemeral_key_';

  /// Get or create session với một friend
  /// Returns session ID nếu thành công
  Future<String?> getOrCreateSession(String friendUserId, String friendNakamaUserId) async {
    try {
      print('[ChatSessionManager] 🔍 Getting or creating session with friend: $friendUserId');
      
      // 1. Check cache first
      if (_sessionCache.containsKey(friendUserId)) {
        final cachedSessionId = _sessionCache[friendUserId]!;
        // Verify session still exists in Rust registry
        if (await _verifySessionExists(cachedSessionId)) {
          print('[ChatSessionManager] ✅ Found cached session: $cachedSessionId');
          return cachedSessionId;
        } else {
          print('[ChatSessionManager] ⚠️  Cached session not found in registry, will recreate');
          _sessionCache.remove(friendUserId);
        }
      }

      // 2. Check persistent storage
      final prefs = await SharedPreferences.getInstance();
      final storedSessionId = prefs.getString('$_sessionPrefix$friendUserId');
      if (storedSessionId != null && storedSessionId.isNotEmpty) {
        // Verify session still exists in Rust registry
        if (await _verifySessionExists(storedSessionId)) {
          print('[ChatSessionManager] ✅ Found stored session: $storedSessionId');
          _sessionCache[friendUserId] = storedSessionId;
          return storedSessionId;
        } else {
          print('[ChatSessionManager] ⚠️  Stored session not found in registry, will recreate');
          await prefs.remove('$_sessionPrefix$friendUserId');
        }
      }

      // 3. Create new session
      print('[ChatSessionManager] 🔐 No existing session found, creating new session...');
      final sessionId = await _createNewSession(friendUserId, friendNakamaUserId);
      
      if (sessionId != null) {
        // Cache và persist session
        _sessionCache[friendUserId] = sessionId;
        await prefs.setString('$_sessionPrefix$friendUserId', sessionId);
        print('[ChatSessionManager] ✅ Session created and saved: $sessionId');
      }
      
      return sessionId;
    } catch (e) {
      print('[ChatSessionManager] ❌ Error getting/creating session: $e');
      return null;
    }
  }

  /// Verify session exists in Rust registry by trying to use it
  Future<bool> _verifySessionExists(String sessionId) async {
    try {
      // Try to encrypt empty message to verify session exists
      // If session doesn't exist, will return error
      final testResult = api.encryptMessage(
        sessionId: sessionId,
        plaintext: [],
      );
      return !testResult.startsWith('Error:');
    } catch (_) {
      return false;
    }
  }

  /// Create new X3DH session với friend
  Future<String?> _createNewSession(String friendUserId, String friendNakamaUserId) async {
    try {
      print('[ChatSessionManager] 🔐 Step 1: Getting my identity key...');
      
      // Get my identity key (from device registration)
      final myUserId = await _tokenStorage.getUserID();
      if (myUserId == null) {
        print('[ChatSessionManager] ❌ No user ID found');
        return null;
      }

      final myDeviceId = await _deviceManager.getCurrentDeviceId();
      print('[ChatSessionManager] 🔐 My device ID: $myDeviceId');

      // Load my identity key from storage (must be the same as used in device registration)
      // CRITICAL: Using wrong identity key will cause decryption failures
      String myIdentityJson;
      final storedIdentityJson = await _tokenStorage.getIdentityKeyPair();
      if (storedIdentityJson != null && storedIdentityJson.isNotEmpty) {
        myIdentityJson = storedIdentityJson;
        print('[ChatSessionManager] 🔐 Loaded identity key pair from storage');
        
        // Verify identity key matches device registration
        final myPublicKey = api.getPublicKeyHexFromJson(identityBytesJson: myIdentityJson);
        print('[ChatSessionManager] 🔐 Identity public key: ${myPublicKey.substring(0, 16)}...');
      } else {
        print('[ChatSessionManager] ❌ CRITICAL: No stored identity key found!');
        print('[ChatSessionManager] ❌ This will cause decryption errors!');
        print('[ChatSessionManager] ❌ Solution: Logout and login again to re-register device');
        // Don't generate new key - this will break everything
        // Return error instead
        return null;
      }

      print('[ChatSessionManager] 🔐 Step 2: Getting friend\'s prekey bundle...');
      
      // Get friend's prekey bundle from Key Service
      final friendPrekeyBundle = await _getFriendPrekeyBundle(friendUserId);
      if (friendPrekeyBundle == null) {
        print('[ChatSessionManager] ❌ Failed to get friend\'s prekey bundle');
        return null;
      }

      print('[ChatSessionManager] 🔐 Step 3: Creating X3DH session (initiator)...');
      
      // Create session as initiator
      final sessionResultJson = api.createSessionInitiatorWithEphemeral(
        identityBytesJson: myIdentityJson,
        prekeyBundleJson: friendPrekeyBundle,
      );

      // Parse session result
      String sessionId;
      try {
        final sessionResult = jsonDecode(sessionResultJson) as Map<String, dynamic>;
        sessionId = sessionResult['session_id'] as String? ?? '';
        
        if (sessionId.isEmpty) {
          print('[ChatSessionManager] ❌ Invalid session result: $sessionResultJson');
          return null;
        }
        
        print('[ChatSessionManager] ✅ Session created: $sessionId');
        final ephemeralKey = sessionResult['alice_ephemeral_public_key_hex'] as String? ?? '';
        final aliceIdentityHex = sessionResult['alice_identity_hex'] as String? ?? '';
        
        if (ephemeralKey.isNotEmpty) {
          print('[ChatSessionManager] 🔐 Ephemeral key: ${ephemeralKey.substring(0, 16)}...');
          // Store ephemeral key for first message
          _ephemeralKeyCache[friendUserId] = ephemeralKey;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('$_ephemeralKeyPrefix$friendUserId', ephemeralKey);
          
          // Also store Alice's identity for responder session creation
          if (aliceIdentityHex.isNotEmpty) {
            await prefs.setString('${_sessionPrefix}alice_identity_$friendUserId', aliceIdentityHex);
          }
        }
      } catch (e) {
        // If not JSON, assume it's the session ID directly or an error
        if (sessionResultJson.startsWith('Error:')) {
          print('[ChatSessionManager] ❌ Session creation error: $sessionResultJson');
          return null;
        }
        sessionId = sessionResultJson;
      }

      return sessionId;
    } catch (e) {
      print('[ChatSessionManager] ❌ Error creating session: $e');
      return null;
    }
  }

  /// Get friend's prekey bundle from Key Service
  Future<String?> _getFriendPrekeyBundle(String friendUserId) async {
    try {
      print('[ChatSessionManager] 🔐 Fetching prekey bundle for user: $friendUserId');
      
      // Use new API endpoint to get prekey bundle by user ID
      final response = await _deviceService.getPrekeyBundleByUserId(friendUserId);
      if (response == null) {
        print('[ChatSessionManager] ❌ Failed to get prekey bundle for user: $friendUserId');
        return null;
      }

      // Convert API response to Rust PreKeyBundleJSON format
      final bundleJson = _convertToPrekeyBundleJSON(response);
      print('[ChatSessionManager] ✅ Converted prekey bundle to Rust format');
      
      return bundleJson;
    } catch (e) {
      print('[ChatSessionManager] ❌ Error getting prekey bundle: $e');
      return null;
    }
  }

  /// Convert API prekey bundle response to Rust PreKeyBundleJSON format
  String _convertToPrekeyBundleJSON(Map<String, dynamic> apiResponse) {
    final identityKey = apiResponse['identity_key'] as String? ?? '';
    final identityEd25519VerifyingKey = apiResponse['identity_ed25519_verifying_key'] as String? ?? '';
    final signedPrekey = apiResponse['signed_prekey'] as Map<String, dynamic>?;
    final oneTimePrekey = apiResponse['one_time_prekey'] as Map<String, dynamic>?;

    if (identityEd25519VerifyingKey.isEmpty) {
      print('[ChatSessionManager] ⚠️  Warning: Ed25519 verifying key is empty in API response');
    }

    final rustBundle = <String, dynamic>{
      'identity_public_hex': identityKey,
      'identity_ed25519_verifying_key_hex': identityEd25519VerifyingKey,
      'signed_prekey': signedPrekey != null
          ? {
              'public_key_hex': signedPrekey['public_key'] as String? ?? '',
              'signature_hex': signedPrekey['signature'] as String? ?? '',
              'key_id': signedPrekey['id'] as int? ?? 1,
            }
          : null,
      'one_time_prekey': oneTimePrekey != null
          ? {
              'public_key_hex': oneTimePrekey['public_key'] as String? ?? '',
              'key_id': oneTimePrekey['id'] as int? ?? 1,
            }
          : null,
    };

    return jsonEncode(rustBundle);
  }

  /// Get session ID for a friend (from cache or storage)
  Future<String?> getSessionId(String friendUserId) async {
    // Check cache first
    if (_sessionCache.containsKey(friendUserId)) {
      return _sessionCache[friendUserId];
    }

    // Check storage
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_sessionPrefix$friendUserId');
  }

  /// Get ephemeral key for a friend (for first message)
  Future<String?> getEphemeralKey(String friendUserId) async {
    // Check cache first
    if (_ephemeralKeyCache.containsKey(friendUserId)) {
      return _ephemeralKeyCache[friendUserId];
    }

    // Check storage
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_ephemeralKeyPrefix$friendUserId');
  }

  /// Create responder session when receiving first message from friend
  /// This is called when we receive an encrypted message but don't have a session yet
  Future<String?> createResponderSession(
    String friendUserId,
    String aliceIdentityHex,
    String aliceEphemeralKeyHex,
  ) async {
    try {
      print('[ChatSessionManager] 🔐 Creating responder session for friend: $friendUserId');
      
      // Get my identity key
      final myIdentityJson = await _tokenStorage.getIdentityKeyPair();
      if (myIdentityJson == null || myIdentityJson.isEmpty) {
        print('[ChatSessionManager] ❌ No identity key found');
        return null;
      }

      // Get prekey IDs from storage (saved during device registration)
      // Note: We can't get from prekey bundle because one-time prekey may have been consumed
      final signedPrekeyId = await _tokenStorage.getSignedPrekeyId();
      final oneTimePrekeyIds = await _tokenStorage.getOneTimePrekeyIds();
      
      if (signedPrekeyId == null) {
        print('[ChatSessionManager] ❌ No signed prekey ID found in storage');
        print('[ChatSessionManager] ⚠️  Falling back to default ID: 1');
      }
      
      if (oneTimePrekeyIds.isEmpty) {
        print('[ChatSessionManager] ❌ No one-time prekey IDs found in storage');
        print('[ChatSessionManager] ⚠️  Falling back to default ID: 1');
      }

      // Use first available one-time prekey ID (or default to 1)
      final oneTimePrekeyId = oneTimePrekeyIds.isNotEmpty ? oneTimePrekeyIds.first : 1;
      final finalSignedPrekeyId = signedPrekeyId ?? 1;

      print('[ChatSessionManager] 🔐 Creating responder session...');
      print('[ChatSessionManager] 🔐   Alice identity: ${aliceIdentityHex.substring(0, 16)}...');
      print('[ChatSessionManager] 🔐   Alice ephemeral: ${aliceEphemeralKeyHex.substring(0, 16)}...');
      print('[ChatSessionManager] 🔐   Signed prekey ID: $finalSignedPrekeyId');
      print('[ChatSessionManager] 🔐   One-time prekey ID: $oneTimePrekeyId');

      // Create responder session
      final sessionId = api.createSessionResponder(
        identityBytesJson: myIdentityJson,
        signedPrekeyId: finalSignedPrekeyId,
        oneTimePrekeyId: oneTimePrekeyId,
        aliceIdentityHex: aliceIdentityHex,
        aliceEphemeralPublicKeyHex: aliceEphemeralKeyHex,
      );

      if (sessionId.startsWith('Error:')) {
        print('[ChatSessionManager] ❌ Failed to create responder session: $sessionId');
        return null;
      }

      print('[ChatSessionManager] ✅ Responder session created: $sessionId');

      // Cache and persist session
      _sessionCache[friendUserId] = sessionId;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_sessionPrefix$friendUserId', sessionId);

      return sessionId;
    } catch (e) {
      print('[ChatSessionManager] ❌ Error creating responder session: $e');
      return null;
    }
  }

  /// Clear session for a friend
  Future<void> clearSession(String friendUserId) async {
    _sessionCache.remove(friendUserId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_sessionPrefix$friendUserId');
    print('[ChatSessionManager] 🗑️  Cleared session for friend: $friendUserId');
  }

  /// Clear ephemeral key for a friend (after first message sent)
  Future<void> clearEphemeralKey(String friendUserId) async {
    _ephemeralKeyCache.remove(friendUserId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_ephemeralKeyPrefix$friendUserId');
    print('[ChatSessionManager] 🗑️  Cleared ephemeral key for friend: $friendUserId');
  }

  /// Clear all sessions
  Future<void> clearAllSessions() async {
    _sessionCache.clear();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_sessionPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    print('[ChatSessionManager] 🗑️  Cleared all sessions');
  }
}
