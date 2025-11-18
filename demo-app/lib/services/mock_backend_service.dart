/// Mock Backend Service for E2EE Chat
/// 
/// This service simulates a backend server that:
/// - Stores and forwards encrypted messages (ciphertext only)
/// - Does NOT decrypt or see plaintext
/// - Provides message queue for each user
/// 
/// In production, this would be replaced with real HTTP API calls.

class MockBackendService {
  // Simulate message queues for each user
  // In real app, this would be server-side storage
  static final Map<String, List<BackendMessage>> _messageQueues = {};

  /// Send an encrypted message to a recipient
  /// 
  /// In production: POST /api/messages
  /// Body: { "recipient_id": "bob", "ciphertext": "base64..." }
  static Future<void> sendMessage({
    required String senderId,
    required String recipientId,
    required String ciphertextBase64,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Create message
    final message = BackendMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: senderId,
      recipientId: recipientId,
      ciphertextBase64: ciphertextBase64,
      timestamp: DateTime.now(),
    );

    // Add to recipient's queue
    _messageQueues.putIfAbsent(recipientId, () => []);
    _messageQueues[recipientId]!.add(message);

    print('[Backend] Message sent from $senderId to $recipientId');
    print('[Backend] Ciphertext length: ${ciphertextBase64.length} chars');
  }

  /// Receive encrypted messages for a user
  /// 
  /// In production: GET /api/messages?user_id=bob
  /// Returns: List of { "id": "...", "sender_id": "...", "ciphertext": "..." }
  static Future<List<BackendMessage>> receiveMessages(String userId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    final queue = _messageQueues[userId] ?? [];
    print('[Backend] User $userId has ${queue.length} pending messages');

    // Return and clear queue (in real app, messages would be marked as delivered)
    final messages = List<BackendMessage>.from(queue);
    _messageQueues[userId] = [];
    return messages;
  }

  /// Poll for new messages (simulate real-time)
  /// 
  /// In production: WebSocket or Server-Sent Events
  static Stream<List<BackendMessage>> pollMessages(String userId) async* {
    while (true) {
      final messages = await receiveMessages(userId);
      if (messages.isNotEmpty) {
        yield messages;
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  /// Clear all messages (for testing)
  static void clearAll() {
    _messageQueues.clear();
    print('[Backend] All message queues cleared');
  }
}

/// Backend message model
/// 
/// This is what the backend stores and forwards.
/// Backend CANNOT decrypt this - only the recipient can.
class BackendMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String ciphertextBase64; // Base64-encoded MessageEnvelope
  final DateTime timestamp;

  BackendMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.ciphertextBase64,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'ciphertext': ciphertextBase64,
        'timestamp': timestamp.toIso8601String(),
      };

  factory BackendMessage.fromJson(Map<String, dynamic> json) => BackendMessage(
        id: json['id'] as String,
        senderId: json['sender_id'] as String,
        recipientId: json['recipient_id'] as String,
        ciphertextBase64: json['ciphertext'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

