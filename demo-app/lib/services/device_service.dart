import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import '../bridge_generated/ffi/api.dart' as api;

class DeviceService {
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

  /// Register device với Key Service
  /// Returns device_id nếu thành công, null nếu có lỗi
  Future<String?> registerDevice({
    required String deviceId,
    required String identityPublicKey,
    required String identityEd25519VerifyingKey,
    required Map<String, dynamic> signedPrekey,
    required List<Map<String, dynamic>> prekeys,
  }) async {
    final token = await _getToken();
    if (token == null) {
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/register'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'device_id': deviceId,
          'identity_public_key': identityPublicKey,
          'identity_ed25519_verifying_key': identityEd25519VerifyingKey,
          'signed_prekey': signedPrekey,
          'prekeys': prekeys,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['device_id'] as String?;
      } else {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          print('[DeviceService] ❌ Registration failed: ${error['error']}');
        } catch (_) {}
        return null;
      }
    } catch (e) {
      print('[DeviceService] ❌ Network error: $e');
      return null;
    }
  }

  /// Generate keys và register device
  /// Returns device_id nếu thành công
  Future<String?> generateAndRegisterDevice(String deviceId) async {
    try {
      // Generate identity key pair
      final identityJson = api.generateIdentityKeyPair();
      final identityPublicKey = api.getPublicKeyHexFromJson(
        identityBytesJson: identityJson,
      );

      // Generate prekey bundle (includes signed prekey + one one-time prekey)
      final bundleJson = api.generatePrekeyBundle(
        identityBytesJson: identityJson,
        signedPrekeyId: 1,
        oneTimePrekeyId: 1,
      );

      // Parse bundle - Rust returns PreKeyBundleJSON format
      final bundle = jsonDecode(bundleJson) as Map<String, dynamic>;
      final identityEd25519VerifyingKey = bundle['identity_ed25519_verifying_key_hex'] as String? ?? '';
      final signedPrekeyJson = bundle['signed_prekey'] as Map<String, dynamic>;
      final oneTimePrekeyJson = bundle['one_time_prekey'] as Map<String, dynamic>?;

      // Map Rust format to API format
      // Rust: {public_key_hex, signature_hex, key_id}
      // API: {id, public_key, signature, timestamp}
      final signedPrekeyData = {
        'id': signedPrekeyJson['key_id'] as int,
        'public_key': signedPrekeyJson['public_key_hex'] as String,
        'signature': signedPrekeyJson['signature_hex'] as String,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      // Prepare prekeys array (only one-time prekeys, signed prekey is separate)
      final prekeys = <Map<String, dynamic>>[];

      // Add one-time prekey if available
      if (oneTimePrekeyJson != null) {
        prekeys.add({
          'id': oneTimePrekeyJson['key_id'] as int,
          'public_key': oneTimePrekeyJson['public_key_hex'] as String,
        });
      }

      // Generate additional one-time prekeys for better UX
      for (int i = 2; i <= 3; i++) {
        try {
          final additionalBundleJson = api.generatePrekeyBundle(
            identityBytesJson: identityJson,
            signedPrekeyId: 1,
            oneTimePrekeyId: i,
          );
          final additionalBundle = jsonDecode(additionalBundleJson) as Map<String, dynamic>;
          final additionalPrekey = additionalBundle['one_time_prekey'] as Map<String, dynamic>?;
          if (additionalPrekey != null) {
            prekeys.add({
              'id': additionalPrekey['key_id'] as int,
              'public_key': additionalPrekey['public_key_hex'] as String,
            });
          }
        } catch (_) {
          // Skip if generation fails
        }
      }

      // Ensure we have at least one prekey
      if (prekeys.isEmpty) {
        print('[DeviceService] ❌ No prekeys generated');
        return null;
      }

      // Register device
      final registeredDeviceId = await registerDevice(
        deviceId: deviceId,
        identityPublicKey: identityPublicKey,
        identityEd25519VerifyingKey: identityEd25519VerifyingKey,
        signedPrekey: signedPrekeyData,
        prekeys: prekeys,
      );

      if (registeredDeviceId != null) {
        print('[DeviceService] ✅ Device registered: $deviceId');
        // Save identity key pair for later use in session creation
        // This is critical: same identity key must be used for all sessions
        await _tokenStorage.saveIdentityKeyPair(identityJson);
        
        // Save prekey IDs for responder session creation
        final signedPrekeyId = signedPrekeyData['id'] as int;
        final oneTimePrekeyIds = prekeys.map((p) => p['id'] as int).toList();
        await _tokenStorage.savePrekeyIds(signedPrekeyId, oneTimePrekeyIds);
        print('[DeviceService] ✅ Saved prekey IDs: signed=$signedPrekeyId, one-time=$oneTimePrekeyIds');
        
        // Verify identity key was saved
        final savedKey = await _tokenStorage.getIdentityKeyPair();
        if (savedKey != null && savedKey.isNotEmpty) {
          print('[DeviceService] ✅ Verified: Identity key pair saved successfully');
        } else {
          print('[DeviceService] ❌ ERROR: Identity key pair was not saved!');
        }
      } else {
        print('[DeviceService] ❌ Device registration failed, identity key not saved');
      }

      return registeredDeviceId;
    } catch (e) {
      print('[DeviceService] ❌ Error: $e');
      return null;
    }
  }

  /// Get prekey bundle của một user (lấy từ device đầu tiên của user)
  /// Returns prekey bundle data nếu thành công, null nếu có lỗi
  Future<Map<String, dynamic>?> getPrekeyBundleByUserId(String userId) async {
    final token = await _getToken();
    if (token == null) {
      print('[DeviceService] ❌ No access token');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/$userId/prekey-bundle'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('[DeviceService] ❌ Failed to get prekey bundle by user ID: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('[DeviceService] ✅ Got prekey bundle for user: $userId');
      return data;
    } catch (e) {
      print('[DeviceService] ❌ Error getting prekey bundle by user ID: $e');
      return null;
    }
  }

  /// Get prekey bundle của một device
  /// Returns prekey bundle data nếu thành công, null nếu có lỗi
  Future<Map<String, dynamic>?> getPrekeyBundle(String deviceId) async {
    final token = await _getToken();
    if (token == null) {
      print('[DeviceService] ❌ No access token');
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId/prekey-bundle'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('[DeviceService] ❌ Failed to get prekey bundle: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('[DeviceService] ✅ Got prekey bundle for device: $deviceId');
      return data;
    } catch (e) {
      print('[DeviceService] ❌ Error getting prekey bundle: $e');
      return null;
    }
  }

  /// Check if device exists (by trying to get prekey bundle)
  Future<bool> deviceExists(String deviceId) async {
    final bundle = await getPrekeyBundle(deviceId);
    return bundle != null;
  }

  /// Delete a device from Key Service
  /// Returns true if successful, false otherwise
  Future<bool> deleteDevice(String deviceId) async {
    final token = await _getToken();
    if (token == null) {
      print('[DeviceService] ❌ No access token');
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/devices/$deviceId'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('[DeviceService] ✅ Device deleted: $deviceId');
        return true;
      } else {
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          print('[DeviceService] ❌ Delete failed: ${error['error']}');
        } catch (_) {
          print('[DeviceService] ❌ Delete failed: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      print('[DeviceService] ❌ Error deleting device: $e');
      return false;
    }
  }
}
