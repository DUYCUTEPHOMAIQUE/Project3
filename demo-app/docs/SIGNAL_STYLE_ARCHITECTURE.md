# Signal-Style Chat Architecture

## Core Principles

### 1. **End-to-End Encryption (E2EE)**
- Messages được encrypt trên client trước khi gửi
- Server (Nakama) chỉ nhận được ciphertext, không thể decrypt
- Chỉ recipient mới có thể decrypt

### 2. **Local-First Storage**
- **Messages chỉ lưu local** (SQLite/Hive database)
- Server không lưu message history
- Server chỉ là transport layer (WebSocket)

### 3. **Session Persistence**
- DoubleRatchet session state được persist local
- Session được restore khi app restart
- Mỗi conversation có một session riêng

### 4. **Forward Secrecy**
- Mỗi message có key riêng (Double Ratchet)
- Old keys được discard sau khi dùng
- Compromise một key không ảnh hưởng messages khác

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter App (Client)                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐      ┌──────────────┐      ┌─────────────┐│
│  │   UI Layer   │─────▶│  ViewModel   │─────▶│   Service   ││
│  │  (ChatPage)  │      │ (ChatVM)     │      │ (ChatSvc)   ││
│  └──────────────┘      └──────────────┘      └─────────────┘│
│         │                     │                     │       │
│         │                     ▼                     │       │
│         │            ┌──────────────┐                │       │
│         │            │ Session Mgr  │                │       │
│         │            │ (X3DH/DR)    │                │       │
│         │            └──────────────┘                │       │
│         │                     │                     │       │
│         │                     ▼                     │       │
│         │            ┌──────────────┐                │       │
│         │            │ Rust Core    │                │       │
│         │            │ (E2EE)       │                │       │
│         │            └──────────────┘                │       │
│         │                     │                     │       │
│         ▼                     ▼                     ▼       │
│  ┌──────────────┐      ┌──────────────┐      ┌─────────────┐│
│  │ Local DB     │      │ Key Storage  │      │ Nakama     ││
│  │ (Messages)   │      │ (Identity)   │      │ (Transport)││
│  └──────────────┘      └──────────────┘      └─────────────┘│
│                                                               │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  Nakama Server  │
                    │  (WebSocket)    │
                    │  - No History   │
                    │  - Transport    │
                    └─────────────────┘
```

## Data Flow

### Sending Message

```
1. User types message
   ↓
2. ViewModel.sendMessage()
   ↓
3. ChatService.sendMessage()
   ↓
4. ChatSessionManager.getSession()
   ↓
5. Rust Core: encryptMessage(sessionId, plaintext)
   ↓
6. Get encrypted envelope (base64)
   ↓
7. Send via Nakama WebSocket (ciphertext only)
   ↓
8. Save message to Local DB (encrypted + metadata)
   ↓
9. Update UI
```

### Receiving Message

```
1. Nakama WebSocket receives message
   ↓
2. ChatService._processReceivedMessage()
   ↓
3. Parse encrypted envelope (base64)
   ↓
4. ChatSessionManager.getSession()
   ↓
5. Rust Core: decryptMessage(sessionId, envelope)
   ↓
6. Get decrypted plaintext
   ↓
7. Save message to Local DB (decrypted + metadata)
   ↓
8. Update UI
```

## Storage Structure

### Local Database (SQLite/Hive)

```dart
// Messages Table
class LocalMessage {
  String id;                    // Unique message ID
  String conversationId;         // Friend user ID
  String senderId;             // Sender user ID
  String content;              // Decrypted plaintext (local only)
  String? encryptedContent;   // Encrypted envelope (backup)
  DateTime timestamp;
  bool isFromMe;
  bool isDelivered;
  bool isRead;
}

// Sessions Table
class LocalSession {
  String sessionId;            // Session UUID
  String friendUserId;          // Friend user ID
  String sessionState;         // Serialized DoubleRatchet state (future)
  DateTime createdAt;
  DateTime lastUsedAt;
}

// Conversations Table
class LocalConversation {
  String friendUserId;
  String friendUsername;
  String? lastMessage;
  DateTime lastMessageTime;
  int unreadCount;
}
```

## Key Components

### 1. **ChatSessionManager**
- Quản lý X3DH sessions
- Persist session IDs
- Restore sessions khi app restart
- Handle session recreation nếu bị mất

### 2. **LocalMessageStorage**
- Lưu messages vào local database
- Load messages khi mở conversation
- Query messages theo conversation
- Mark messages as read/delivered

### 3. **ChatService**
- Handle Nakama WebSocket connection
- Send/receive encrypted messages
- Process incoming messages (decrypt)
- Không fetch history từ server

### 4. **NakamaService**
- WebSocket connection management
- Authentication với Nakama
- Channel management (join/leave)

## Security Considerations

### 1. **Identity Key Protection**
- Identity key được lưu trong secure storage
- Không bao giờ gửi private key lên server
- Chỉ public key được share

### 2. **Session State**
- Session state chỉ lưu local
- Không sync session state qua server
- Mỗi device có session riêng

### 3. **Message Storage**
- Messages được encrypt trước khi lưu local
- Local DB có thể encrypt thêm một lớp (optional)
- Keys được protect bằng device keychain

### 4. **Forward Secrecy**
- Double Ratchet đảm bảo forward secrecy
- Old keys được discard
- Compromise không ảnh hưởng future messages

## Implementation Checklist

### Phase 1: Core E2EE ✅
- [x] X3DH key exchange
- [x] Double Ratchet encryption
- [x] Session management
- [x] Message encryption/decryption

### Phase 2: Local Storage (TODO)
- [ ] Local database setup (SQLite/Hive)
- [ ] Message persistence
- [ ] Session state persistence
- [ ] Conversation list management

### Phase 3: Signal Features (TODO)
- [ ] Message delivery receipts
- [ ] Read receipts
- [ ] Typing indicators
- [ ] Message reactions
- [ ] Media encryption
- [ ] Disappearing messages

### Phase 4: Multi-Device (Future)
- [ ] Device registration per user
- [ ] Multi-device sync
- [ ] Device management

## Current Status

✅ **Working:**
- E2EE encryption/decryption
- X3DH session creation
- Nakama WebSocket transport
- Real-time messaging

⚠️ **Issues:**
- Identity key not persisted (causing session recreation)
- Messages only in memory (not persisted)
- Session state not persisted (lost on app restart)

🔧 **Next Steps:**
1. Fix identity key persistence
2. Implement local message storage
3. Implement session state persistence
4. Add message delivery tracking
