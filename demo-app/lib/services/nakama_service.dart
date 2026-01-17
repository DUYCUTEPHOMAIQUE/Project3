// TODO: Add nakama package khi đã có
// import 'package:nakama/nakama.dart';

/// Service để quản lý Nakama client connection và authentication
/// 
/// NOTE: File này là template. Cần install nakama package và implement đầy đủ
class NakamaService {
  // TODO: Uncomment khi đã add nakama package
  // late final Client _client;
  // Session? _session;

  // TODO: Uncomment và sử dụng khi đã có nakama package
  // static String get _nakamaHost {
  //   if (Platform.isAndroid) {
  //     return '10.0.2.2';
  //   } else {
  //     return '127.0.0.1';
  //   }
  // }
  // static const int _nakamaPort = 7350;
  // static const String _nakamaServerKey = 'defaultkey';

  /// Initialize Nakama client
  Future<void> initialize() async {
    // TODO: Implement khi đã có nakama package
    // _client = Client(
    //   serverKey: _nakamaServerKey,
    //   host: _nakamaHost,
    //   port: _nakamaPort,
    //   ssl: false, // Set true cho production
    // );
  }

  /// Authenticate với Nakama sử dụng custom token từ Key Service
  /// 
  /// [customToken] là JWT token từ Key Service
  /// Returns Nakama session nếu thành công
  Future<Map<String, dynamic>?> authenticateCustom(String customToken) async {
    // TODO: Implement khi đã có nakama package
    // try {
    //   _session = await _client.authenticateCustom(
    //     id: customToken, // Pass JWT token as custom ID
    //     username: null, // Will be set by Nakama hook
    //   );
    //   
    //   return {
    //     'token': _session!.token,
    //     'refresh_token': _session!.refreshToken,
    //     'user_id': _session!.userId,
    //     'username': _session!.username,
    //     'created': _session!.created,
    //     'expires_at': _session!.expiresAt,
    //   };
    // } catch (e) {
    //   print('Nakama authentication error: $e');
    //   return null;
    // }
    
    // Placeholder return
    return null;
  }

  /// Authenticate với device ID (optional, cho anonymous login)
  Future<Map<String, dynamic>?> authenticateDevice(String deviceId) async {
    // TODO: Implement khi đã có nakama package
    // try {
    //   _session = await _client.authenticateDevice(
    //     id: deviceId,
    //     username: null,
    //   );
    //   
    //   return {
    //     'token': _session!.token,
    //     'refresh_token': _session!.refreshToken,
    //     'user_id': _session!.userId,
    //     'username': _session!.username,
    //   };
    // } catch (e) {
    //   print('Nakama device authentication error: $e');
    //   return null;
    // }
    
    return null;
  }

  /// Get current Nakama session
  Map<String, dynamic>? getCurrentSession() {
    // TODO: Return _session data khi đã có nakama package
    return null;
  }

  /// Check if session is valid
  bool isSessionValid() {
    // TODO: Check _session expiry khi đã có nakama package
    // if (_session == null) return false;
    // return DateTime.now().millisecondsSinceEpoch < _session!.expiresAt;
    return false;
  }

  /// Refresh Nakama session
  Future<Map<String, dynamic>?> refreshSession(String refreshToken) async {
    // TODO: Implement khi đã có nakama package
    // try {
    //   _session = await _client.sessionRefresh(_session!);
    //   return {
    //     'token': _session!.token,
    //     'refresh_token': _session!.refreshToken,
    //     'expires_at': _session!.expiresAt,
    //   };
    // } catch (e) {
    //   print('Nakama session refresh error: $e');
    //   return null;
    // }
    
    return null;
  }

  /// Disconnect từ Nakama
  Future<void> disconnect() async {
    // TODO: Close socket và cleanup khi đã có nakama package
    // _session = null;
  }

  /// Get Nakama client instance (để dùng cho realtime features sau này)
  // Client getClient() {
  //   return _client;
  // }
}
