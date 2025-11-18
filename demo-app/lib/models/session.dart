/// Model class for Session
class Session {
  final String sessionId;
  final String? ephemeralPublicKeyHex;

  Session({
    required this.sessionId,
    this.ephemeralPublicKeyHex,
  });

  bool get isEmpty => sessionId.isEmpty;
}

