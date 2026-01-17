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
        signedPrekey: signedPrekeyData,
        prekeys: prekeys,
      );

      if (registeredDeviceId != null) {
        print('[DeviceService] ✅ Device registered: $deviceId');
      }

      return registeredDeviceId;
    } catch (e) {
      print('[DeviceService] ❌ Error: $e');
      return null;
    }
  }

  /// Check if device exists (by trying to get prekey bundle)
  Future<bool> deviceExists(String deviceId) async {
    final token = await _getToken();
    if (token == null) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/devices/$deviceId/prekey-bundle'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
