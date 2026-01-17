import 'dart:io';
import 'package:nakama/nakama.dart';
import 'token_storage.dart';

/// Service để quản lý Nakama client connection và authentication
class NakamaService {
  NakamaBaseClient? _client;
  Session? _session;
  NakamaWebsocketClient? _socket;
  final TokenStorage _tokenStorage = TokenStorage();

  static String get _nakamaHost {
    if (Platform.isAndroid) {
      return '10.0.2.2';
    } else {
      return '127.0.0.1';
    }
  }
  static const String _nakamaServerKey = 'defaultkey';

  /// Initialize Nakama client
  Future<void> initialize() async {
    _client = getNakamaClient(
      host: _nakamaHost,
      ssl: false,
      serverKey: _nakamaServerKey,
    );
  }

  /// Authenticate với Nakama sử dụng session token từ TokenStorage
  /// Returns true nếu thành công
  Future<bool> authenticate() async {
    try {
      final nakamaUserID = await _tokenStorage.getNakamaUserID();

      if (nakamaUserID == null || nakamaUserID.isEmpty) {
        print('[NakamaService] ❌ No Nakama user ID found');
        return false;
      }

      if (_client == null) {
        await initialize();
      }

      // Authenticate với custom token (user ID từ Key Service)
      _session = await _client!.authenticateCustom(
        id: nakamaUserID,
        username: null,
      );
      print('[NakamaService] ✅ Authenticated with user ID: $nakamaUserID');
      return true;
    } catch (e) {
      print('[NakamaService] ❌ Authentication error: $e');
      return false;
    }
  }

  /// Connect realtime socket
  /// Returns true nếu thành công
  Future<bool> connectSocket() async {
    try {
      if (_session == null) {
        final authenticated = await authenticate();
        if (!authenticated) {
          return false;
        }
      }

      if (_socket != null) {
        print('[NakamaService] ⚠️  Socket already connected');
        return true;
      }

      _socket = NakamaWebsocketClient.init(
        host: _nakamaHost,
        port: 7350,
        ssl: false,
        token: _session!.token,
      );

      print('[NakamaService] ✅ Socket connected');
      return true;
    } catch (e) {
      print('[NakamaService] ❌ Socket connection error: $e');
      return false;
    }
  }

  /// Get socket instance (phải connect trước)
  NakamaWebsocketClient? getSocket() {
    return _socket;
  }

  /// Get session instance
  Session? getSession() {
    return _session;
  }

  /// Get current Nakama user ID from session
  /// Returns null if not authenticated
  String? getCurrentNakamaUserID() {
    return _session?.userId;
  }

  /// Check if socket is connected
  bool isSocketConnected() {
    return _socket != null;
  }

  /// Disconnect socket
  Future<void> disconnectSocket() async {
    try {
      _socket?.close();
      _socket = null;
      print('[NakamaService] ✅ Socket disconnected');
    } catch (e) {
      print('[NakamaService] ❌ Error disconnecting socket: $e');
    }
  }

  /// Disconnect từ Nakama (close socket và clear session)
  Future<void> disconnect() async {
    await disconnectSocket();
    _session = null;
  }

  /// Get client instance (for ChatService)
  NakamaBaseClient? getClient() {
    return _client;
  }
}
