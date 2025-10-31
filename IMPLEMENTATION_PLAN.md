# Implementation Plan - E2EE Platform

## Overview
Plan chi tiết để code từng bước theo các pha đã định nghĩa. Mỗi task có thể code được ngay với acceptance criteria rõ ràng.

---

## PHASE 0: Foundations & Research

### Mục tiêu
Chốt tech stack, setup repo structure, build PoC nhỏ để validate approach.

### Task 0.1: Setup Mono-repo Structure
**Acceptance Criteria:**
- [ ] Tạo cấu trúc thư mục cho mono-repo
- [ ] Setup workspace config (Cargo workspace cho Rust, hoặc npm/yarn workspaces)
- [ ] Có package structure: `core-rust/`, `bindings-ios/`, `bindings-android/`, `gateway-node/`, `demo-mobile/`
- [ ] Setup `.gitignore` phù hợp cho Rust, Swift, Kotlin, Node.js

**Files to create:**
```
project3/
├── Cargo.toml (workspace)
├── core-rust/
│   ├── Cargo.toml
│   └── src/
├── bindings-ios/
│   ├── Package.swift
│   └── Sources/
├── bindings-android/
│   └── build.gradle.kts
├── gateway-node/
│   ├── package.json
│   └── src/
├── demo-mobile/
│   ├── android/
│   └── ios/
├── docs/
└── scripts/
```

### Task 0.2: Technical Decision Log
**Acceptance Criteria:**
- [ ] Tạo file `docs/TECH_DECISIONS.md`
- [ ] Document quyết định về:
  - Core language: Rust (recommended)
  - Crypto library: libsignal-client hoặc ring + libsodium
  - Message format: Protobuf
  - Transport: gRPC cho gateway, MQTT cho IoT
- [ ] Rationale cho mỗi quyết định

### Task 0.3: CI Pipeline Baseline
**Acceptance Criteria:**
- [ ] Setup GitHub Actions / GitLab CI
- [ ] Lint checks: rustfmt, clippy cho Rust
- [ ] Unit test runner (basic structure)
- [ ] Build artifacts cho mỗi platform

**Files to create:**
```
.github/workflows/ci.yml
```

### Task 0.4: Threat Model Document
**Acceptance Criteria:**
- [ ] Tạo `docs/THREAT_MODEL.md`
- [ ] Liệt kê threats: MITM, key compromise, device loss, metadata leakage
- [ ] Mitigation strategies cho mỗi threat
- [ ] Security assumptions

### Task 0.5: PoC - Core Crypto Library Setup
**Acceptance Criteria:**
- [ ] Tạo Rust crate `core-rust` với dependencies cơ bản
- [ ] Add crypto libs: `ring`, `x25519-dalek`, `ed25519-dalek`, hoặc `libsignal-client`
- [ ] Implement basic key generation (X25519 identity key)
- [ ] Unit test: generate key pair và verify

**Dependencies:**
```toml
[dependencies]
ring = "0.17"
x25519-dalek = "2.0"
ed25519-dalek = "2.0"
prost = "0.12"  # protobuf
serde = { version = "1.0", features = ["derive"] }
```

---

## PHASE 1: Core SDK MVP

### Mục tiêu
SDK core với X3DH + Double Ratchet, Gateway đơn giản, demo app pairwise chat.

### Cấu trúc theo 3 giai đoạn chính:

1. **Giai đoạn Khởi tạo Phiên (Key Agreement)** - Tasks 1.1, 1.2
2. **Giai đoạn gửi và nhận tin nhắn liên tục (Double Ratchet)** - Task 1.3
3. **Giai đoạn quản lí phiên (Sesame)** - Task 1.3.5

---

## GIAI ĐOẠN 1: Khởi tạo Phiên (Key Agreement)

Mục tiêu: Thiết lập shared secret (SK) giữa 2 parties (Bob và Alice) trong môi trường bất đồng bộ sử dụng X3DH.

### Task 1.1: Core Crypto - Key Management
**Acceptance Criteria:**
- [ ] Implement `IdentityKeyPair` struct (X25519)
- [ ] Implement `PreKeyBundle` struct (identity, signed prekey, one-time prekeys)
- [ ] Generate signed prekey với Ed25519 signature
- [ ] Generate batch one-time prekeys (100 keys)
- [ ] Unit tests: verify key generation và signatures

**Files to create:**
```
core-rust/src/
├── lib.rs
├── keys/
│   ├── mod.rs
│   ├── identity.rs
│   └── prekey.rs
└── tests/
    └── keys_test.rs
```

### Task 1.2: Core Crypto - X3DH Handshake
**Acceptance Criteria:**
- [ ] Implement X3DH key exchange algorithm (asynchronous key agreement)
- [ ] **Bob side (Key Publisher)**:
  - [ ] Publish identity key (IKB) lên server
  - [ ] Publish signed prekey (SPKB) với Ed25519 signature
  - [ ] Generate và publish batch one-time prekeys (OPKB) - 100+ keys
- [ ] **Alice side (Initiator)**:
  - [ ] Fetch prekey bundle từ server (IKB, SPKB, OPKB)
  - [ ] Generate ephemeral key (EK) - temporary key chỉ tồn tại trong handshake
  - [ ] Calculate shared secret: `SK = KDF(DH1 || DH2 || DH3 || DH4)`
    - DH1 = DH(IKA, SPKB)
    - DH2 = DH(EK, IKB)
    - DH3 = DH(EK, SPKB)
    - DH4 = DH(EK, OPKB) [nếu có]
  - [ ] Encrypt initial ciphertext với SK (hoặc derived key từ SK)
  - [ ] Send initial message với EK public key
- [ ] **Bob side (Responder)**:
  - [ ] Receive initial message với EK
  - [ ] Calculate same SK using own private keys
  - [ ] Decrypt initial ciphertext
- [ ] Function: `x3dh_initiate(identity_key_pair, prekey_bundle) -> (shared_secret, ephemeral_key)`
- [ ] Function: `x3dh_respond(identity_key_pair, signed_prekey_pair, one_time_prekey_pair, ephemeral_public_key) -> shared_secret`
- [ ] Unit tests: verify same shared secret từ cả 2 phía
- [ ] Edge cases: missing one-time prekey, expired signed prekey, Bob offline

**Files to create:**
```
core-rust/src/
├── x3dh/
│   ├── mod.rs
│   ├── handshake.rs
│   ├── initiator.rs
│   └── responder.rs
└── tests/
    └── x3dh_test.rs
```

**Protocol Flow:**
```
1. Bob → Server: Publish IKB, SPKB, OPKB[]
2. Alice → Server: GET prekey bundle for Bob
3. Alice: Generate EK, calculate SK = KDF(DH1||DH2||DH3||DH4)
4. Alice → Bob: Initial message with EK_pub, encrypted with SK
5. Bob: Calculate SK using IKB, SPKB, OPKB private keys + EK_pub
6. Bob: Decrypt initial message, initiate Double Ratchet with SK
```

**Deliverables:**
- ✅ Key generation và management (IK, SPK, OPK)
- ✅ Prekey bundle publishing và fetching
- ✅ X3DH handshake implementation (initiator + responder)
- ✅ Shared secret calculation (SK)
- ✅ Initial message encryption với SK

---

## GIAI ĐOẠN 2: Gửi và nhận tin nhắn liên tục (Double Ratchet)

Mục tiêu: Trao đổi messages được mã hoá với forward secrecy và break-in recovery sử dụng Double Ratchet algorithm.

### Task 1.3: Core Crypto - Double Ratchet
**Acceptance Criteria:**
- [ ] Implement `DoubleRatchet` struct initialized với SK từ X3DH
- [ ] **Forward Secrecy**: Mỗi message có key mới, không thể decrypt message cũ nếu key hiện tại bị leak
- [ ] **Break-in Recovery**: Nếu attacker compromise session state, chỉ có thể decrypt messages từ điểm đó về sau, không thể decrypt quá khứ
- [ ] Methods: `encrypt_message(plaintext) -> ciphertext`, `decrypt_message(ciphertext) -> plaintext`
- [ ] **Sending Ratchet**: Ratchet forward khi send message
- [ ] **Receiving Ratchet**: Ratchet forward khi receive message (DH ratchet)
- [ ] Handle out-of-order messages: queue skipped messages với message number
- [ ] **Chain Keys**: Derive message keys từ chain keys (KDF chain)
- [ ] **DH Ratchet**: Generate new DH key pair periodically, send public key trong message header
- [ ] Session state serialization/deserialization (secure storage)
- [ ] Unit tests: 
  - [ ] Bidirectional encryption/decryption
  - [ ] Forward secrecy: old keys cannot decrypt new messages
  - [ ] Out-of-order message handling
  - [ ] Session recovery after compromise

**Files to create:**
```
core-rust/src/
├── ratchet/
│   ├── mod.rs
│   ├── double_ratchet.rs
│   ├── chain.rs
│   ├── session.rs
│   └── message_queue.rs
└── tests/
    └── ratchet_test.rs
```

**Double Ratchet Properties:**
- **Sending Chain**: Ratchet forward mỗi khi send
- **Receiving Chain**: Ratchet forward mỗi khi receive DH key
- **Message Keys**: Derived từ chain keys với unique nonce
- **Queue**: Store out-of-order messages until chain catches up

**Deliverables:**
- ✅ Double Ratchet implementation với forward secrecy
- ✅ Break-in recovery mechanism
- ✅ Message encryption/decryption với ratcheting
- ✅ Out-of-order message handling
- ✅ DH ratchet for periodic key exchange

---

## GIAI ĐOẠN 3: Quản lí phiên (Sesame)

Mục tiêu: Quản lý session state cho multiple conversations và devices, secure storage và lifecycle management.

### Task 1.3.5: Core Crypto - Session Management (Sesame)
**Acceptance Criteria:**
- [ ] Implement `SessionManager` struct để quản lý multiple sessions
- [ ] Session lifecycle: create, update, delete, restore
- [ ] Store session state securely (via keystore adapter)
- [ ] Session expiration và cleanup
- [ ] Multi-device session synchronization
- [ ] Unit tests: session creation, update, deletion

**Files to create:**
```
core-rust/src/
├── session/
│   ├── mod.rs
│   ├── manager.rs
│   └── state.rs
└── tests/
    └── session_test.rs
```

**Session Management Features:**
- Multi-session support (one per contact/conversation)
- Secure session state storage (via keystore adapter)
- Session lifecycle: create, update, delete, restore
- Session expiration và cleanup
- Multi-device session synchronization

**Deliverables:**
- ✅ SessionManager implementation
- ✅ Secure session state storage
- ✅ Session lifecycle management
- ✅ Multi-device synchronization support

---

## Supporting Tasks (Chung cho cả 3 giai đoạn)

### Task 1.4: Message Envelope Format (Protobuf)
**Note**: Cần cho cả 3 giai đoạn - format cho initial message (Key Agreement) và regular messages (Double Ratchet)

**Acceptance Criteria:**
- [ ] Define protobuf schema cho message envelope
- [ ] Fields: version, message_type, ciphertext, header (ratchet info)
- [ ] **Initial Message**: Include ephemeral key (EK) from X3DH
- [ ] **Regular Message**: Include DH public key for ratchet, message number, previous chain length
- [ ] Implement encode/decode functions
- [ ] Version compatibility handling

**Files to create:**
```
core-rust/src/
├── proto/
│   ├── mod.rs
│   └── envelope.proto
└── message/
    ├── mod.rs
    └── envelope.rs
```

**Protobuf schema (draft):**
```protobuf
message MessageEnvelope {
  uint32 version = 1;
  MessageType type = 2;  // INITIAL, REGULAR, PREKEY_BUNDLE
  bytes ciphertext = 3;
  MessageHeader header = 4;
  bool is_initial = 5;  // true for X3DH initial message
}

message MessageHeader {
  bytes dh_public_key = 1;  // EK for initial, ratchet key for regular
  uint32 previous_chain_length = 2;
  uint64 message_number = 3;
  bytes ephemeral_key = 4;  // Only for initial message
}
```

### Task 1.5: Keystore Adapter - iOS Secure Enclave
**Note**: Cần cho cả 3 giai đoạn - store keys (Key Agreement), session state (Double Ratchet), session data (Sesame)
**Acceptance Criteria:**
- [ ] Create Swift package `bindings-ios`
- [ ] Implement `Keystore` protocol với Secure Enclave integration
- [ ] Methods: `store(key: Data, label: String)`, `retrieve(label: String) -> Data?`, `delete(label: String)`
- [ ] Unit tests trên iOS simulator

**Files to create:**
```
bindings-ios/Sources/E2EESDK/
├── Keystore.swift
├── SecureEnclaveKeystore.swift
└── Tests/
    └── KeystoreTests.swift
```

### Task 1.6: Keystore Adapter - Android Keystore
**Note**: Cần cho cả 3 giai đoạn - store keys (Key Agreement), session state (Double Ratchet), session data (Sesame)
**Acceptance Criteria:**
- [ ] Create Android library module `bindings-android`
- [ ] Implement `Keystore` interface với Android Keystore
- [ ] Methods: `store(key: ByteArray, alias: String)`, `retrieve(alias: String): ByteArray?`, `delete(alias: String)`
- [ ] Unit tests

**Files to create:**
```
bindings-android/src/main/kotlin/
├── Keystore.kt
├── AndroidKeystore.kt
└── test/
    └── KeystoreTest.kt
```

### Task 1.7: Gateway - Device Registration
**Note**: Hỗ trợ Key Agreement - Bob publish keys, Alice register device
**Acceptance Criteria:**
- [ ] REST endpoint: `POST /api/v1/devices/register`
- [ ] Request body: `{ device_id, identity_public_key, signed_prekey, prekeys[] }`
- [ ] Store device info trong memory (sẽ migrate sang DB sau)
- [ ] Return: `{ device_id, registration_token }`
- [ ] Input validation & error handling

**Files to create:**
```
gateway-node/src/
├── server.ts
├── routes/
│   └── devices.ts
└── handlers/
    └── register.ts
```

### Task 1.8: Gateway - Prekey Bundle API
**Note**: Hỗ trợ Key Agreement - Alice fetch prekey bundle để initiate X3DH
**Acceptance Criteria:**
- [ ] REST endpoint: `GET /api/v1/devices/{device_id}/prekey-bundle`
- [ ] Return prekey bundle cho device đó
- [ ] Handle case: no available prekeys (return error)
- [ ] Consume one-time prekey sau khi return

**Files to create:**
```
gateway-node/src/routes/
└── prekeys.ts
```

### Task 1.9: Gateway - Message Relay
**Note**: Hỗ trợ Double Ratchet - relay encrypted messages giữa devices
**Acceptance Criteria:**
- [ ] REST endpoint: `POST /api/v1/messages`
- [ ] Request: `{ recipient_device_id, ciphertext, message_type }`
- [ ] Store message trong memory queue (sẽ migrate sang Kafka sau)
- [ ] REST endpoint: `GET /api/v1/devices/{device_id}/messages`
- [ ] Return messages cho device và remove khỏi queue
- [ ] Handle pagination

**Files to create:**
```
gateway-node/src/routes/
└── messages.ts
```

### Task 1.10: Device Linking - QR Code Flow
**Acceptance Criteria:**
- [ ] Generate QR code chứa: device_id, identity_public_key, signed_prekey
- [ ] Scan QR code và parse data
- [ ] UI flow: primary device shows QR → new device scans → approval prompt
- [ ] Implement approval mechanism (có thể đơn giản: button confirm)

**Files to create:**
```
core-rust/src/
└── linking/
    ├── mod.rs
    └── qr.rs

demo-mobile/android/app/src/main/java/
└── LinkingActivity.kt

demo-mobile/ios/DemoApp/
└── LinkingViewController.swift
```

### Task 1.11: Demo App - Android Basic Chat
**Acceptance Criteria:**
- [ ] Simple Android app với 2 screens: registration, chat
- [ ] Integrate SDK để register device
- [ ] Send/receive encrypted messages giữa 2 devices
- [ ] Display messages trong UI (decrypted)
- [ ] Error handling & loading states

**Files to create:**
```
demo-mobile/android/app/src/main/java/
├── MainActivity.kt
├── ChatActivity.kt
└── RegisterActivity.kt
```

### Task 1.12: Demo App - iOS Basic Chat
**Acceptance Criteria:**
- [ ] Simple iOS app với 2 screens: registration, chat
- [ ] Integrate SDK để register device
- [ ] Send/receive encrypted messages giữa 2 devices
- [ ] Display messages trong UI (decrypted)
- [ ] Error handling & loading states

**Files to create:**
```
demo-mobile/ios/DemoApp/
├── App.swift
├── RegisterView.swift
└── ChatView.swift
```

### Task 1.13: Integration Tests
**Acceptance Criteria:**
- [ ] Test suite: 2 devices register → exchange prekeys → send messages → decrypt
- [ ] Test edge cases: device offline, message loss, reconnection
- [ ] Test across platforms: Android ↔ iOS, iOS ↔ iOS
- [ ] CI runs integration tests

**Files to create:**
```
tests/
└── integration/
    ├── pairwise_chat_test.rs
    └── cross_platform_test.rs
```

---

## PHASE 2: Multi-device, Backup, Group

### Task 2.1: Multi-device Linking Full Flow
**Acceptance Criteria:**
- [ ] Device list API: `GET /api/v1/devices` (return all devices cho user)
- [ ] Device revocation API: `DELETE /api/v1/devices/{device_id}`
- [ ] Propagate revocation events đến tất cả devices
- [ ] UI: device list screen, revoke device action
- [ ] Test: link 3 devices, send message đến all devices, revoke 1 device

**Files to create:**
```
gateway-node/src/routes/
└── device-management.ts

core-rust/src/
└── devices/
    ├── mod.rs
    └── revocation.rs
```

### Task 2.2: Client-side Encrypted Backup
**Acceptance Criteria:**
- [ ] Implement backup export: serialize session state + identity keys
- [ ] Encrypt backup với Argon2 + AES-GCM (client-side)
- [ ] Upload backup blob lên S3 (via gateway)
- [ ] Implement backup restore: download, decrypt, import
- [ ] Backup password prompt UI
- [ ] Unit tests: encrypt/decrypt backup

**Files to create:**
```
core-rust/src/
└── backup/
    ├── mod.rs
    ├── export.rs
    └── import.rs

gateway-node/src/routes/
└── backup.ts
```

### Task 2.3: Group Messaging - Sender Keys
**Acceptance Criteria:**
- [ ] Implement Sender Key generation và distribution
- [ ] Create group API: `POST /api/v1/groups` (create group, add members)
- [ ] Sender key distribution: encrypt với mỗi member's session key
- [ ] Group message encryption: use sender key (single encryption cho all members)
- [ ] Handle member add/remove: rotate sender key
- [ ] Unit tests: group message encryption/decryption

**Files to create:**
```
core-rust/src/
└── groups/
    ├── mod.rs
    ├── sender_keys.rs
    └── distribution.rs

gateway-node/src/routes/
└── groups.ts
```

### Task 2.4: Device Verification UI
**Acceptance Criteria:**
- [ ] Display device fingerprint (hash of identity public key)
- [ ] Compare fingerprints UI (side-by-side)
- [ ] Verification status indicator
- [ ] Manual verification flow

**Files to create:**
```
core-rust/src/
└── verification/
    └── fingerprint.rs

demo-mobile/android/app/src/main/java/
└── VerificationActivity.kt
```

---

## PHASE 3: Scale & Hardening

### Task 3.1: Database Schema (Postgres)
**Acceptance Criteria:**
- [ ] Migrate từ in-memory sang Postgres
- [ ] Schema: devices, prekeys, messages, groups, backups
- [ ] Indexes cho performance
- [ ] Migration scripts

**Files to create:**
```
gateway-node/src/db/
├── schema.sql
├── migrations/
└── client.ts
```

### Task 3.2: Message Broker (Kafka/NATS)
**Acceptance Criteria:**
- [ ] Replace in-memory queue bằng Kafka/NATS
- [ ] Producer: publish messages to topic
- [ ] Consumer: subscribe messages cho device
- [ ] Handle delivery failures & retries

**Files to create:**
```
gateway-node/src/broker/
├── producer.ts
└── consumer.ts
```

### Task 3.3: Monitoring (Prometheus + Grafana)
**Acceptance Criteria:**
- [ ] Expose Prometheus metrics endpoint
- [ ] Metrics: prekey inventory, message queue lag, delivery success rate, error rates
- [ ] Grafana dashboard config
- [ ] Alerts: low prekey inventory, high error rate

**Files to create:**
```
gateway-node/src/monitoring/
├── metrics.ts
└── dashboard.json
```

### Task 3.4: Security Testing
**Acceptance Criteria:**
- [ ] Fuzz testing setup (cargo fuzz)
- [ ] Static analysis: clippy, cargo audit
- [ ] Dependency scanning
- [ ] Malformed message tests

**Files to create:**
```
fuzz/
└── fuzz_targets/
    └── message_envelope.rs
```

### Task 3.5: Rate Limiting
**Acceptance Criteria:**
- [ ] Implement rate limiting middleware
- [ ] Limits: registration (per IP), message sending (per device)
- [ ] Return 429 khi exceed limit

**Files to create:**
```
gateway-node/src/middleware/
└── rate-limit.ts
```

---

## PHASE 4: Enterprise & Ecosystem

### Task 4.1: SDK Documentation
**Acceptance Criteria:**
- [ ] API documentation (Rust doc comments)
- [ ] Integration guide cho iOS/Android
- [ ] Example code snippets
- [ ] Architecture diagrams

**Files to create:**
```
docs/
├── SDK_API.md
├── INTEGRATION_GUIDE.md
└── ARCHITECTURE.md
```

### Task 4.2: IoT MQTT Adapter
**Acceptance Criteria:**
- [ ] MQTT client adapter cho IoT devices
- [ ] Lightweight C/Rust SDK variant
- [ ] Example: ESP32 integration

**Files to create:**
```
adapters/
└── mqtt/
    ├── Cargo.toml
    └── src/
```

### Task 4.3: Admin Console (Privacy Preserving)
**Acceptance Criteria:**
- [ ] Metrics dashboard (no plaintext data)
- [ ] Device count, message volume (aggregated)
- [ ] System health indicators

**Files to create:**
```
admin-console/
├── package.json
└── src/
```

---

## Coding Order (Recommended)

### Week 1-2: Phase 0
1. Task 0.1: Setup mono-repo
2. Task 0.2: Tech decisions
3. Task 0.3: CI pipeline
4. Task 0.4: Threat model
5. Task 0.5: PoC crypto setup

### Week 3-6: Phase 1 Core (theo 3 giai đoạn)

**Giai đoạn 1: Key Agreement (Week 3-4)**
1. Task 1.1: Key management (IK, SPK, OPK)
2. Task 1.2: X3DH handshake (initiator + responder)
3. Task 1.7: Gateway - Device registration
4. Task 1.8: Gateway - Prekey bundle API

**Giai đoạn 2: Double Ratchet (Week 4-5)**
1. Task 1.3: Double Ratchet (forward secrecy + break-in recovery)
2. Task 1.4: Message envelope format
3. Task 1.9: Gateway - Message relay

**Giai đoạn 3: Sesame (Week 5)**
1. Task 1.3.5: Session Management (Sesame)

**Supporting Tasks (parallel)**
1. Task 1.5-1.6: Keystore adapters (iOS + Android)
2. Task 1.10: Device linking
3. Task 1.11-1.12: Demo apps
4. Task 1.13: Integration tests (end-to-end qua cả 3 giai đoạn)

### Week 7-10: Phase 2
1. Task 2.1: Multi-device
2. Task 2.2: Backup
3. Task 2.3: Group messaging
4. Task 2.4: Verification UI

### Week 11-14: Phase 3
1. Task 3.1: Database
2. Task 3.2: Message broker
3. Task 3.3: Monitoring
4. Task 3.4: Security testing
5. Task 3.5: Rate limiting

### Week 15+: Phase 4
1. Task 4.1: Documentation
2. Task 4.2: IoT adapter
3. Task 4.3: Admin console

---

## Quick Start Checklist (Immediate)

1. ✅ Setup mono-repo structure (Task 0.1)
2. ✅ Choose crypto library: `libsignal-client` or `ring` + `x25519-dalek`
3. ✅ Create core-rust crate với basic dependencies
4. ✅ Implement PoC: generate keys, basic X3DH handshake
5. ✅ Create Node Gateway skeleton với 4 endpoints
6. ✅ Build simple Android demo app
7. ✅ Test end-to-end: Android ↔ Android encrypted chat

---

## Protocol Flow Summary

### Giai đoạn 1: Khởi tạo Phiên (Key Agreement - X3DH/PQXDH)
1. **Bob publishes keys**: IKB, SPKB (signed), OPKB[] → Server
2. **Alice fetches**: GET prekey bundle for Bob
3. **Alice initiates**: Generate EK, calculate SK = KDF(DH1||DH2||DH3||DH4)
4. **Alice sends**: Initial message với EK_pub, encrypted với SK
5. **Bob responds**: Calculate SK, decrypt initial message, start Double Ratchet with SK

**Deliverables**: Shared secret (SK) được thiết lập, ready cho Double Ratchet

### Giai đoạn 2: Gửi và nhận tin nhắn liên tục (Double Ratchet)
- **Forward Secrecy**: Mỗi message có key mới, không thể decrypt quá khứ
- **Break-in Recovery**: Compromise chỉ ảnh hưởng tương lai, không thể decrypt quá khứ
- **DH Ratchet**: Periodic key exchange để ratchet forward
- **Message Queue**: Handle out-of-order messages

**Deliverables**: Secure message exchange với forward secrecy và break-in recovery

### Giai đoạn 3: Quản lí phiên (Sesame)
- Multi-session management (one per contact/conversation)
- Secure session state storage
- Session lifecycle management (create, update, delete, restore)
- Multi-device session synchronization

**Deliverables**: Complete session management system

---

## Notes

- Mỗi task nên có PR riêng với tests
- Code review tập trung vào security cho crypto code
- Keep tasks small và incremental
- Test-driven development cho crypto flows
- Document decisions trong `docs/TECH_DECISIONS.md`
- **Security Focus**: Forward secrecy và break-in recovery là core requirements

