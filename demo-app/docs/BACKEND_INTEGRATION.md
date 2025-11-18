# Backend Integration Guide

## Tóm tắt

**Đúng vậy!** Logic E2EE đã ổn định và hoàn chỉnh. Backend chỉ cần:
- **Nhận và lưu trữ ciphertext** (base64-encoded MessageEnvelope)
- **Forward ciphertext** đến recipient
- **KHÔNG decrypt** - backend không thể đọc được nội dung

## Architecture Overview

```
┌─────────────┐                    ┌─────────────┐
│   Alice     │                    │    Bob      │
│  (Client)   │                    │  (Client)   │
└──────┬──────┘                    └──────┬──────┘
       │                                   │
       │ 1. Encrypt (client-side)          │
       │    plaintext → ciphertext          │
       │                                    │
       │ 2. Send ciphertext                │
       ├───────────────────────────────────┤
       │                                    │
       │         ┌─────────────┐          │
       └─────────▶│   Backend   │─────────┘
                  │   Server     │
                  └─────────────┘
                  │
                  │ Backend chỉ thấy:
                  │ - ciphertext (base64)
                  │ - sender_id
                  │ - recipient_id
                  │ - timestamp
                  │
                  │ Backend KHÔNG thấy:
                  │ - plaintext ❌
                  │ - encryption keys ❌
                  │
       │                                    │
       │ 3. Receive ciphertext              │
       │                                    │
       │ 4. Decrypt (client-side)           │
       │    ciphertext → plaintext          │
       │                                    │
```

## Message Flow

### 1. Alice gửi tin nhắn cho Bob

```dart
// Client-side (Alice)
final plaintext = "Hello Bob!";
final plaintextBytes = utf8.encode(plaintext);

// Encrypt locally using Alice's session
final ciphertextBase64 = encryptMessage(
  sessionId: aliceSessionId,
  plaintext: plaintextBytes,
);
// Returns: Base64-encoded MessageEnvelope

// Send to backend
await backend.sendMessage(
  senderId: "alice",
  recipientId: "bob",
  ciphertext: ciphertextBase64, // Backend chỉ nhận được ciphertext
);
```

**Backend nhận được:**
```json
{
  "sender_id": "alice",
  "recipient_id": "bob",
  "ciphertext": "eyJ2ZXJzaW9uIjoxLCJtZXNzYWdlX3R5cGUiOiJSZWd1bGFyIiwiY2lwaGVydGV4dCI6Wy4uLl0sImhlYWRlciI6eyJkaF9wdWJsaWNfa2V5IjoiLi4uIiwibWVzc2FnZV9udW1iZXIiOjF9fQ==",
  "timestamp": "2024-01-01T12:00:00Z"
}
```

**Backend KHÔNG thể decrypt** - chỉ thấy base64 string.

### 2. Backend forward đến Bob

```dart
// Backend chỉ cần:
// 1. Store message in Bob's queue
// 2. Forward ciphertext (không modify)

// Backend code (pseudo):
class BackendAPI {
  Map<String, List<Message>> messageQueues = {};
  
  POST /api/messages {
    // Store ciphertext as-is
    messageQueues[recipientId].add({
      sender_id: senderId,
      ciphertext: ciphertext, // Store without decrypting
      timestamp: now()
    });
  }
  
  GET /api/messages?user_id=bob {
    // Return ciphertext as-is
    return messageQueues["bob"];
  }
}
```

### 3. Bob nhận và decrypt

```dart
// Client-side (Bob)
final messages = await backend.receiveMessages("bob");

for (final msg in messages) {
  // Decrypt locally using Bob's session
  final decryptedBytes = decryptMessage(
    sessionId: bobSessionId,
    envelopeBase64: msg.ciphertext, // Ciphertext từ backend
  );
  
  final plaintext = utf8.decode(decryptedBytes);
  // "Hello Bob!" - chỉ Bob mới thấy được plaintext này
}
```

## Backend Requirements

### Backend chỉ cần implement:

1. **Message Storage**
   - Store ciphertext (base64 string)
   - Store metadata: sender_id, recipient_id, timestamp
   - **KHÔNG cần** decrypt hoặc xử lý nội dung

2. **Message Delivery**
   - Queue messages cho mỗi user
   - Forward ciphertext đến recipient
   - **KHÔNG modify** ciphertext

3. **API Endpoints**

```typescript
// Send message
POST /api/messages
Body: {
  recipient_id: string;
  ciphertext: string; // Base64-encoded MessageEnvelope
}

// Receive messages
GET /api/messages?user_id={userId}
Returns: [
  {
    id: string;
    sender_id: string;
    ciphertext: string; // Base64-encoded MessageEnvelope
    timestamp: string;
  }
]

// Real-time (optional)
WebSocket: /ws/messages?user_id={userId}
```

### Backend KHÔNG cần:

- ❌ Decrypt messages
- ❌ Store encryption keys
- ❌ Understand message content
- ❌ Message routing logic (chỉ forward)
- ❌ Content filtering (không thể vì không decrypt được)

## Security Guarantees

1. **End-to-End Encryption**: Chỉ sender và recipient có thể decrypt
2. **Forward Secrecy**: Mỗi message có key riêng, không thể decrypt message cũ nếu key hiện tại bị leak
3. **Backend Privacy**: Backend không thể đọc được nội dung messages
4. **Metadata Protection**: Backend chỉ thấy sender/recipient IDs và timestamps

## Implementation Example

Xem `lib/services/mock_backend_service.dart` để thấy cách implement mock backend.

Xem `lib/viewmodels/chat_with_backend_view_model.dart` để thấy cách integrate với backend.

## Testing với Mock Backend

```dart
// 1. Alice gửi message
await viewModel.sendMessageAsAlice("Hello Bob!");
// → Encrypts locally
// → Sends ciphertext to backend

// 2. Bob nhận và decrypt
await viewModel.receiveAndDecryptMessages("bob");
// → Fetches ciphertext from backend
// → Decrypts locally
// → Shows plaintext in UI
```

## Production Considerations

1. **Message Queue**: Sử dụng Redis/RabbitMQ cho message queue
2. **Persistence**: Lưu ciphertext vào database (PostgreSQL/MongoDB)
3. **Real-time**: WebSocket hoặc Server-Sent Events cho push notifications
4. **Rate Limiting**: Giới hạn số messages gửi/giờ
5. **Message Expiry**: Xóa messages sau một thời gian (optional)
6. **Delivery Receipts**: Track message delivery status (optional)

## Summary

✅ **Logic E2EE đã hoàn chỉnh** - encrypt/decrypt hoạt động đúng  
✅ **Backend chỉ cần** - store và forward ciphertext  
✅ **Backend không thể** - decrypt hoặc đọc nội dung  
✅ **Client-side** - encrypt trước khi gửi, decrypt sau khi nhận  

Backend đóng vai trò như một "dumb pipe" - chỉ forward encrypted data mà không thể đọc được.

