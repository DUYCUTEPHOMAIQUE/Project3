/// Model class for Message
class Message {
  final String plaintext;
  final String? encryptedBase64;
  final String? decryptedText;

  Message({
    required this.plaintext,
    this.encryptedBase64,
    this.decryptedText,
  });

  bool get hasPlaintext => plaintext.isNotEmpty;
  bool get isEncrypted => encryptedBase64 != null && encryptedBase64!.isNotEmpty;
  bool get isDecrypted => decryptedText != null && decryptedText!.isNotEmpty;
}

