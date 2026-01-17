/// Kết quả authentication từ AuthService
class AuthResult {
  final bool success;
  final String? error;
  final String? userId;
  final String? username;
  final String? keyServiceToken; // JWT từ Key Service
  final String? nakamaSessionToken; // Session token từ Nakama
  final Map<String, dynamic>? nakamaSession; // Full Nakama session data

  AuthResult({
    required this.success,
    this.error,
    this.userId,
    this.username,
    this.keyServiceToken,
    this.nakamaSessionToken,
    this.nakamaSession,
  });

  factory AuthResult.success({
    required String userId,
    required String username,
    required String keyServiceToken,
    required String nakamaSessionToken,
    Map<String, dynamic>? nakamaSession,
  }) {
    return AuthResult(
      success: true,
      userId: userId,
      username: username,
      keyServiceToken: keyServiceToken,
      nakamaSessionToken: nakamaSessionToken,
      nakamaSession: nakamaSession,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      error: error,
    );
  }
}
