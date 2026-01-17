import '../models/auth/auth_result.dart';
import 'key_service_client.dart';
import 'nakama_service.dart';
import 'token_storage.dart';
import 'device_manager.dart';

/// Unified authentication service
/// Orchestrates authentication flow giữa Key Service và Nakama
class AuthService {
  final KeyServiceClient _keyServiceClient;
  final NakamaService _nakamaService;
  final TokenStorage _tokenStorage;
  final DeviceManager _deviceManager;

  AuthService({
    KeyServiceClient? keyServiceClient,
    NakamaService? nakamaService,
    TokenStorage? tokenStorage,
    DeviceManager? deviceManager,
  })  : _keyServiceClient = keyServiceClient ?? KeyServiceClient(),
        _nakamaService = nakamaService ?? NakamaService(),
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _deviceManager = deviceManager ?? DeviceManager();

  /// Initialize services
  Future<void> initialize() async {
    print('[AuthService] 🚀 Initializing...');
    await _nakamaService.initialize();
    print('[AuthService] ✅ Initialized');
  }

  /// Register user mới
  /// 
  /// Flow:
  /// 1. Register với Key Service (Key Service tự động tạo Nakama user)
  /// 2. Save tokens từ Key Service response (bao gồm cả Nakama session)
  Future<AuthResult> register({
    required String username,
    required String password,
    String? email,
  }) async {
    print('\n[AuthService] 📝 ========== REGISTER START ==========');
    print('[AuthService] 📝 Username: $username');
    print('[AuthService] 📝 Email: ${email ?? "(not provided)"}');
    
    try {
      // Step 1: Register với Key Service
      print('[AuthService] 📝 Step 1: Calling Key Service register endpoint...');
      final keyServiceResult = await _keyServiceClient.register(
        username: username,
        password: password,
        email: email,
      );

      print('[AuthService] 📝 Key Service response received');
      print('[AuthService] 📝 Response keys: ${keyServiceResult.keys.toList()}');

      if (keyServiceResult['error'] != null) {
        print('[AuthService] ❌ Key Service error: ${keyServiceResult['error']}');
        return AuthResult.failure(keyServiceResult['error'].toString());
      }

      final userId = keyServiceResult['user_id'] as String?;
      final usernameFromResponse = keyServiceResult['username'] as String?;

      if (userId == null || usernameFromResponse == null) {
        print('[AuthService] ❌ Invalid response: missing user_id or username');
        return AuthResult.failure('Invalid response from Key Service');
      }

      print('[AuthService] ✅ Step 1: User created in Key Service');
      print('[AuthService] 📝   User ID: $userId');
      print('[AuthService] 📝   Username: $usernameFromResponse');

      // Step 2: Extract Nakama info từ response
      print('[AuthService] 📝 Step 2: Extracting Nakama info from response...');
      final nakamaUserID = keyServiceResult['nakama_user_id'] as String?;
      final nakamaSession = keyServiceResult['nakama_session'] as String?;

      if (nakamaUserID != null && nakamaUserID.isNotEmpty) {
        print('[AuthService] ✅ Nakama user ID: $nakamaUserID');
      } else {
        print('[AuthService] ⚠️  Nakama user ID not provided (may be empty string)');
      }

      if (nakamaSession != null && nakamaSession.isNotEmpty) {
        print('[AuthService] ✅ Nakama session token: ${nakamaSession.substring(0, 20)}...');
      } else {
        print('[AuthService] ⚠️  Nakama session token not provided');
      }

      // Step 3: Save all tokens to centralized storage
      print('[AuthService] 📝 Step 3: Saving tokens to storage...');
      await _tokenStorage.saveUserInfo(
        userID: userId,
        username: usernameFromResponse,
        email: email,
      );

      if (nakamaUserID != null && nakamaUserID.isNotEmpty) {
        await _tokenStorage.saveNakamaUserID(nakamaUserID);
      }

      if (nakamaSession != null && nakamaSession.isNotEmpty) {
        await _tokenStorage.saveNakamaSessionToken(nakamaSession);
      }

      // Note: Key Service không trả về access_token trong register response
      // User cần login để lấy access_token
      print('[AuthService] ⚠️  Note: Access token not provided in register response');
      print('[AuthService] ⚠️  User needs to login to get access token');

      // Print storage state
      await _tokenStorage.printStorageState();

      print('[AuthService] ✅ ========== REGISTER SUCCESS ==========\n');

      final nakamaUserIDValue = nakamaUserID ?? '';
      final nakamaSessionValue = nakamaSession ?? '';
      final hasNakamaInfo = nakamaSessionValue.isNotEmpty && nakamaUserIDValue.isNotEmpty;
      
      return AuthResult.success(
        userId: userId,
        username: usernameFromResponse,
        keyServiceToken: '', // Access token sẽ có sau khi login
        nakamaSessionToken: nakamaSessionValue,
        nakamaSession: hasNakamaInfo
            ? {
                'token': nakamaSessionValue,
                'user_id': nakamaUserIDValue,
                'username': usernameFromResponse,
              }
            : null,
      );
    } catch (e, stackTrace) {
      print('[AuthService] ❌ ========== REGISTER FAILED ==========');
      print('[AuthService] ❌ Error: $e');
      print('[AuthService] ❌ Stack trace: $stackTrace');
      print('[AuthService] ❌ ======================================\n');
      return AuthResult.failure('Registration failed: $e');
    }
  }

  /// Login user
  /// 
  /// Flow:
  /// 1. Login với Key Service (Key Service tự động authenticate với Nakama nếu cần)
  /// 2. Save tokens từ Key Service response (bao gồm cả Nakama session)
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    print('\n[AuthService] 🔐 ========== LOGIN START ==========');
    print('[AuthService] 🔐 Username: $username');
    
    try {
      // Step 1: Login với Key Service
      print('[AuthService] 🔐 Step 1: Calling Key Service login endpoint...');
      final keyServiceResult = await _keyServiceClient.login(
        username: username,
        password: password,
      );

      print('[AuthService] 🔐 Key Service response received');
      print('[AuthService] 🔐 Response keys: ${keyServiceResult.keys.toList()}');

      if (keyServiceResult['error'] != null) {
        print('[AuthService] ❌ Key Service error: ${keyServiceResult['error']}');
        return AuthResult.failure(keyServiceResult['error'].toString());
      }

      // Step 2: Extract access token
      print('[AuthService] 🔐 Step 2: Extracting access token...');
      final accessToken = keyServiceResult['access_token'] as String?;
      final refreshToken = keyServiceResult['refresh_token'] as String?;

      if (accessToken == null) {
        print('[AuthService] ❌ No access token received');
        return AuthResult.failure('No access token received from Key Service');
      }

      print('[AuthService] ✅ Access token received: ${accessToken.substring(0, 20)}...');
      if (refreshToken != null) {
        print('[AuthService] ✅ Refresh token received: ${refreshToken.substring(0, 20)}...');
      }

      // Step 3: Extract user info từ response
      print('[AuthService] 🔐 Step 3: Extracting user info...');
      final userInfo = keyServiceResult['user'] as Map<String, dynamic>?;
      final userId = userInfo?['user_id'] as String? ?? 
                    keyServiceResult['user_id'] as String? ?? '';
      final usernameFromResponse = userInfo?['username'] as String? ?? 
                                   keyServiceResult['username'] as String? ?? 
                                   username;
      final email = userInfo?['email'] as String?;

      print('[AuthService] ✅ User info extracted:');
      print('[AuthService] 🔐   User ID: $userId');
      print('[AuthService] 🔐   Username: $usernameFromResponse');
      print('[AuthService] 🔐   Email: ${email ?? "(not provided)"}');

      // Step 4: Extract Nakama info từ response
      print('[AuthService] 🔐 Step 4: Extracting Nakama info...');
      final nakamaUserID = keyServiceResult['nakama_user_id'] as String?;
      final nakamaSession = keyServiceResult['nakama_session'] as String?;

      if (nakamaUserID != null && nakamaUserID.isNotEmpty) {
        print('[AuthService] ✅ Nakama user ID: $nakamaUserID');
      } else {
        print('[AuthService] ⚠️  Nakama user ID not provided (may be empty string)');
      }

      if (nakamaSession != null && nakamaSession.isNotEmpty) {
        print('[AuthService] ✅ Nakama session token: ${nakamaSession.substring(0, 20)}...');
      } else {
        print('[AuthService] ⚠️  Nakama session token not provided');
      }

      // Step 5: Save all tokens to centralized storage
      print('[AuthService] 🔐 Step 5: Saving all tokens to storage...');
      await _tokenStorage.saveKeyServiceAccessToken(accessToken);
      
      if (refreshToken != null) {
        await _tokenStorage.saveKeyServiceRefreshToken(refreshToken);
      }

      await _tokenStorage.saveUserInfo(
        userID: userId,
        username: usernameFromResponse,
        email: email,
      );

      if (nakamaUserID != null && nakamaUserID.isNotEmpty) {
        await _tokenStorage.saveNakamaUserID(nakamaUserID);
      }

      if (nakamaSession != null && nakamaSession.isNotEmpty) {
        await _tokenStorage.saveNakamaSessionToken(nakamaSession);
      }

      // Step 6: Ensure device is registered for chat
      print('[AuthService] 🔐 Step 6: Ensuring device is registered...');
      try {
        final deviceReady = await _deviceManager.ensureDeviceRegistered();
        if (deviceReady) {
          print('[AuthService] ✅ Device ready for chat');
        } else {
          print('[AuthService] ⚠️  Device registration failed (user can still use app)');
        }
      } catch (e) {
        print('[AuthService] ⚠️  Device registration error: $e (non-critical)');
      }

      // Print storage state
      await _tokenStorage.printStorageState();

      print('[AuthService] ✅ ========== LOGIN SUCCESS ==========\n');

      final nakamaUserIDValue = nakamaUserID ?? '';
      final nakamaSessionValue = nakamaSession ?? '';
      final hasNakamaInfo = nakamaSessionValue.isNotEmpty && nakamaUserIDValue.isNotEmpty;
      
      return AuthResult.success(
        userId: userId,
        username: usernameFromResponse,
        keyServiceToken: accessToken,
        nakamaSessionToken: nakamaSessionValue,
        nakamaSession: hasNakamaInfo
            ? {
                'token': nakamaSessionValue,
                'user_id': nakamaUserIDValue,
                'username': usernameFromResponse,
              }
            : null,
      );
    } catch (e, stackTrace) {
      print('[AuthService] ❌ ========== LOGIN FAILED ==========');
      print('[AuthService] ❌ Error: $e');
      print('[AuthService] ❌ Stack trace: $stackTrace');
      print('[AuthService] ❌ ===================================\n');
      return AuthResult.failure('Login failed: $e');
    }
  }

  /// Logout user
  /// Clear tất cả sessions và tokens (but preserve identity key for device re-registration)
  /// Signal-style: Identity key persists across logins for same device
  Future<void> logout() async {
    print('[AuthService] 🚪 Logging out...');
    await _nakamaService.disconnect();
    // Clear all tokens but preserve identity key
    // Identity key should persist across logins for same device
    await _tokenStorage.clearAll(clearIdentityKey: false);
    print('[AuthService] ✅ Logout complete (identity key preserved)');
  }

  /// Check authentication status
  Future<bool> isAuthenticated() async {
    return await _tokenStorage.isAuthenticated();
  }

  /// Get current user ID
  Future<String?> getCurrentUserId() async {
    return await _tokenStorage.getUserID();
  }

  /// Get current username
  Future<String?> getCurrentUsername() async {
    return await _tokenStorage.getUsername();
  }

  /// Get Key Service access token
  Future<String?> getKeyServiceAccessToken() async {
    return await _tokenStorage.getKeyServiceAccessToken();
  }

  /// Get Key Service refresh token
  Future<String?> getKeyServiceRefreshToken() async {
    return await _tokenStorage.getKeyServiceRefreshToken();
  }

  /// Get Nakama session token
  Future<String?> getNakamaSessionToken() async {
    return await _tokenStorage.getNakamaSessionToken();
  }

  /// Get Nakama user ID
  Future<String?> getNakamaUserID() async {
    return await _tokenStorage.getNakamaUserID();
  }

  /// Print current storage state (for debugging)
  Future<void> printStorageState() async {
    await _tokenStorage.printStorageState();
  }

  /// Refresh tokens nếu cần
  Future<bool> refreshTokens() async {
    // TODO: Implement token refresh logic
    // 1. Check token expiry
    // 2. Refresh Key Service token nếu cần
    // 3. Refresh Nakama session nếu cần
    return false;
  }
}
