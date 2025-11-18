/// Model class for Identity Key Pair
class Identity {
  final String identityJson;
  final String publicKeyHex;

  Identity({
    required this.identityJson,
    required this.publicKeyHex,
  });

  bool get isEmpty => identityJson.isEmpty || publicKeyHex.isEmpty;
}

/// Model class for Prekey Bundle
class PrekeyBundle {
  final String bundleJson;

  PrekeyBundle({required this.bundleJson});

  bool get isEmpty => bundleJson.isEmpty;
}

