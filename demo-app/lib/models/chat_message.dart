/// Model class for a single chat message
class ChatMessage {
  final String id;
  final String sender; // 'alice' or 'bob'
  final String plaintext;
  final String? encryptedBase64;
  final String? decryptedText;
  final DateTime timestamp;
  final bool isEncrypted;
  final bool isDecrypted;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.plaintext,
    this.encryptedBase64,
    this.decryptedText,
    required this.timestamp,
    this.isEncrypted = false,
    this.isDecrypted = false,
  });

  ChatMessage copyWith({
    String? id,
    String? sender,
    String? plaintext,
    String? encryptedBase64,
    String? decryptedText,
    DateTime? timestamp,
    bool? isEncrypted,
    bool? isDecrypted,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      plaintext: plaintext ?? this.plaintext,
      encryptedBase64: encryptedBase64 ?? this.encryptedBase64,
      decryptedText: decryptedText ?? this.decryptedText,
      timestamp: timestamp ?? this.timestamp,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      isDecrypted: isDecrypted ?? this.isDecrypted,
    );
  }
}

