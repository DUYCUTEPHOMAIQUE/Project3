# Technical Decision Log

Tài liệu này ghi lại các quyết định kỹ thuật quan trọng trong quá trình phát triển nền tảng E2EE.

## Format

Mỗi quyết định bao gồm:
- **Date**: Ngày quyết định
- **Status**: Proposed | Accepted | Rejected | Deprecated
- **Context**: Tình huống/background
- **Decision**: Quyết định được chọn
- **Alternatives**: Các lựa chọn khác đã cân nhắc
- **Consequences**: Tác động và trade-offs

---

## TD-001: Core Language Selection

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần chọn ngôn ngữ core cho SDK crypto library, phải hỗ trợ multi-platform (iOS, Android, Desktop, IoT) và có FFI tốt.

**Decision**: **Rust** được chọn làm core language cho crypto library.

**Rationale**:
- Memory safety: Rust cung cấp memory safety mà không cần GC, quan trọng cho crypto code
- Cross-platform: Compile sang native code cho iOS, Android, Desktop, và embedded systems
- FFI: C interoperability tốt, dễ tạo bindings cho Swift, Kotlin, C
- Performance: Zero-cost abstractions, performance tương đương C/C++
- Ecosystem: Có nhiều crypto libraries đã được audit (ring, x25519-dalek, ed25519-dalek)
- Concurrency: Async/await hỗ trợ tốt cho network operations

**Alternatives Considered**:
- **C/C++**: Performance tốt nhưng dễ có memory bugs, không có built-in safety
- **Go**: Dễ dùng nhưng có GC overhead, không phù hợp cho embedded/IoT
- **Swift/Kotlin native**: Chỉ hỗ trợ một platform, không thể share code

**Consequences**:
- ✅ Code reuse cao giữa các platforms
- ✅ Memory safety cho crypto operations
- ⚠️ Learning curve cho team (cần Rust knowledge)
- ⚠️ Build time có thể lâu hơn so với scripting languages

---

## TD-002: Crypto Library Selection

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần chọn crypto library implementation cho X3DH, Double Ratchet, và các primitive operations.

**Decision**: Sử dụng **composite approach**: `ring` + `x25519-dalek` + `ed25519-dalek` + custom protocol implementation.

**Rationale**:
- `ring`: Well-audited, maintained by BoringSSL team, cung cấp AEAD (ChaCha20-Poly1305), HKDF, HMAC
- `x25519-dalek`: Pure Rust X25519 implementation, đã được audit
- `ed25519-dalek`: Pure Rust Ed25519 implementation cho signatures
- Custom protocol: Implement X3DH và Double Ratchet theo spec, không phụ thuộc vào libsignal-client (để có control và học hỏi)

**Alternatives Considered**:
- **libsignal-client**: Production-ready nhưng:
  - Có thể quá phức tạp cho nhu cầu hiện tại
  - Khó customize
  - License có thể không phù hợp
- **libsodium**: Stable nhưng:
  - C API, cần wrapper
  - Không có pure Rust implementation
- **crypto_box**: Simplistic, không đủ features

**Consequences**:
- ✅ Control hoàn toàn về implementation
- ✅ Hiểu rõ protocol internals
- ✅ Dễ audit và customize
- ⚠️ Cần implement nhiều hơn từ đầu
- ⚠️ Cần test kỹ lưỡng hơn

**Future Consideration**: Nếu thời gian hạn chế, có thể migrate sang libsignal-client sau PoC phase.

---

## TD-003: Message Format & Serialization

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần định dạng binary cho message envelope để truyền qua network.

**Decision**: Sử dụng **Protocol Buffers (protobuf)** cho message envelope format.

**Rationale**:
- Cross-language support: Có generators cho Rust, Swift, Kotlin, TypeScript
- Efficient: Binary format nhỏ gọn, nhanh hơn JSON
- Versioning: Built-in backward/forward compatibility
- Well-tested: Được dùng rộng rãi trong production systems
- Type safety: Generated code có type safety

**Alternatives Considered**:
- **JSON**: Dễ debug nhưng overhead lớn, không phù hợp cho high-volume messaging
- **MessagePack**: Binary nhưng không có schema, khó versioning
- **CBOR**: Similar to MessagePack, nhưng protobuf phổ biến hơn
- **Custom binary**: Full control nhưng phải implement serialization từ đầu

**Schema Preview**:
```protobuf
message MessageEnvelope {
  uint32 version = 1;
  MessageType type = 2;
  bytes ciphertext = 3;
  MessageHeader header = 4;
}

message MessageHeader {
  bytes dh_public_key = 1;
  uint32 previous_chain_length = 2;
  uint64 message_number = 3;
}
```

**Consequences**:
- ✅ Interoperability giữa các platforms
- ✅ Efficient serialization
- ⚠️ Cần build step để generate code
- ⚠️ Schema changes cần careful versioning

---

## TD-004: Transport Protocol

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần chọn protocol cho communication giữa client và gateway.

**Decision**: **REST API (HTTP/JSON)** cho gateway, với plan migrate sang **gRPC** sau.

**Rationale**:
- REST cho MVP: Đơn giản, dễ debug, không cần code generation
- Future gRPC: Khi cần performance và streaming, có thể migrate
- IoT: MQTT sẽ được dùng cho IoT devices (separate adapter)

**Phased Approach**:
1. **Phase 1 (MVP)**: REST với Express.js
2. **Phase 2**: Evaluate performance, nếu cần thì migrate sang gRPC
3. **IoT**: Separate MQTT adapter

**Alternatives Considered**:
- **gRPC from start**: Tốt nhưng overhead cho MVP phase
- **WebSocket**: Real-time nhưng không cần cho initial implementation
- **GraphQL**: Overkill cho use case này

**Consequences**:
- ✅ Quick iteration trong MVP phase
- ✅ Easy debugging với REST
- ⚠️ Có thể cần refactor sau
- ✅ Flexibility để migrate khi cần

---

## TD-005: Recovery Policy

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần quyết định về backup và recovery mechanism.

**Decision**: **Signal-style (no backup by default)** + **Optional client-side encrypted backup**.

**Rationale**:
- Privacy-first: Default không backup để tối đa privacy
- Opt-in backup: User có thể chọn backup nếu muốn
- Client-side encryption: Backup được encrypt trước khi upload, server không thể decrypt
- Registration lock: Prevent unauthorized device registration

**Implementation**:
- Default: No backup, registration lock với PIN/password
- Optional: Encrypted backup với Argon2 KDF + AES-GCM
- Backup password: User-managed, không store trên server

**Alternatives Considered**:
- **Always backup**: Quá invasive về privacy
- **No backup at all**: Mất dữ liệu nếu device bị mất
- **Server-side backup**: Vi phạm E2EE principle

**Consequences**:
- ✅ Privacy-first approach
- ✅ User control
- ⚠️ UX có thể phức tạp hơn (user phải nhớ backup password)
- ✅ Compliance với privacy regulations

---

## TD-006: Group Messaging Strategy

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần chọn strategy cho group messaging.

**Decision**: **Sender Keys** approach.

**Rationale**:
- Efficiency: Single encryption cho tất cả group members (thay vì pairwise)
- Scalability: O(1) encryption cho group size, O(n) chỉ khi add/remove members
- Industry standard: Signal và WhatsApp đều dùng sender keys
- Performance: Tốt hơn nhiều so với pairwise encryption cho groups lớn

**How it works**:
- Each sender generates sender key
- Distribute sender key encrypted với mỗi member's session key
- Messages encrypted với sender key một lần
- Rotate sender key khi member add/remove

**Alternatives Considered**:
- **Pairwise-only**: Simple nhưng không scale (O(n) encryptions per message)
- **Centralized keys**: Vi phạm E2EE principle

**Consequences**:
- ✅ Efficient cho groups lớn
- ✅ Industry-proven approach
- ⚠️ Cần handle key rotation khi membership changes
- ✅ Scales tốt

---

## TD-007: IoT Support Level

**Date**: 2024-12-XX  
**Status**: Proposed  
**Context**: Cần quyết định mức độ hỗ trợ IoT devices.

**Decision**: **Lightweight C/Rust SDK variant** với **MQTT transport adapter**.

**Rationale**:
- Resource constraints: IoT devices có limited CPU/memory
- Lightweight: Minimal dependencies, chỉ essentials
- MQTT: Standard protocol cho IoT, low overhead
- Optional: Không bắt buộc cho initial implementation

**Implementation Plan**:
- Phase 1-2: Focus on mobile/desktop
- Phase 4: Add IoT adapter với minimal features
- ESP32/Arduino support: Basic pairwise chat, không cần full features

**Alternatives Considered**:
- **Full SDK**: Quá nặng cho embedded devices
- **No IoT support**: Bỏ qua một use case quan trọng

**Consequences**:
- ✅ Có thể support IoT sau
- ⚠️ Cần separate implementation cho IoT
- ✅ Flexible adoption

---

## TD-008: Keystore Implementation

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần secure storage cho private keys trên mỗi platform.

**Decision**: Platform-native keystores với hardware-backed security khi available.

**Rationale**:
- iOS: Secure Enclave (hardware-backed)
- Android: Android Keystore (hardware-backed khi available)
- Desktop: OS keychain (macOS Keychain, Windows Credential Store, Linux libsecret)
- Maximum security: Hardware-backed keys không thể export

**Implementation**:
- Platform-specific adapters
- Fallback: Software keystore nếu hardware không available
- No export: Private keys không bao giờ export được (trừ backup encrypted)

**Alternatives Considered**:
- **Custom encrypted storage**: Phức tạp hơn, không có hardware security
- **Shared keystore**: Không phù hợp với platform differences

**Consequences**:
- ✅ Maximum security với hardware backing
- ✅ Platform-native UX
- ⚠️ Cần implement adapter cho mỗi platform
- ✅ Users trust platform security

---

## TD-009: Key Agreement Protocol (X3DH/PQXDH)

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần chọn protocol cho asynchronous key agreement giữa 2 parties (Bob và Alice) trong môi trường bất đồng bộ.

**Decision**: **X3DH (Extended Triple Diffie-Hellman)** cho Phase 1, với plan support **PQXDH (Post-Quantum Extended Diffie-Hellman)** trong tương lai.

**Rationale**:
- **Asynchronous**: Bob có thể offline khi Alice muốn gửi message
- **Forward secrecy**: EK chỉ dùng một lần, không thể decrypt lại nếu EK bị leak
- **Identity binding**: Signed prekey đảm bảo authenticity
- **One-time prekeys**: Prevent replay attacks
- **Industry standard**: Signal protocol uses X3DH

**X3DH Protocol Flow**:
1. **Bob publishes keys**:
   - Identity Key (IKB): X25519 long-term key
   - Signed Prekey (SPKB): X25519 với Ed25519 signature
   - One-Time Prekeys (OPKB[]): Batch of X25519 keys (100+)
2. **Alice initiates**:
   - Fetch prekey bundle từ server
   - Generate ephemeral key (EK): temporary X25519 key
   - Calculate shared secret: `SK = KDF(DH1 || DH2 || DH3 || DH4)`
     - DH1 = ECDH(IKA, SPKB)
     - DH2 = ECDH(EK, IKB)
     - DH3 = ECDH(EK, SPKB)
     - DH4 = ECDH(EK, OPKB) [if available]
3. **Alice sends**: Initial message với EK_pub, encrypted với SK
4. **Bob responds**:
   - Receive EK_pub
   - Calculate same SK using own private keys
   - Decrypt initial message
   - Start Double Ratchet with SK

**PQXDH (Future)**:
- Adds post-quantum KEM (Key Encapsulation Mechanism)
- Mixed shared secret: `SK = KDF(ECC_DH || PQ_KEM)`
- Protects against quantum attacks on ECC
- Can be added as optional enhancement

**Alternatives Considered**:
- **Plain DH**: Không hỗ trợ asynchronous
- **OTR**: Synchronous only, không phù hợp
- **OMEMO**: Phức tạp hơn, overhead lớn

**Consequences**:
- ✅ Asynchronous messaging support
- ✅ Forward secrecy từ đầu
- ✅ Identity verification qua signed prekey
- ⚠️ Cần maintain prekey inventory
- ✅ Proven security model

---

## TD-010: Double Ratchet Properties

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần đảm bảo forward secrecy và break-in recovery cho message exchange.

**Decision**: Implement **Double Ratchet** với focus vào:
- **Forward Secrecy**: Mỗi message có key mới
- **Break-in Recovery**: Compromise chỉ ảnh hưởng tương lai
- **DH Ratchet**: Periodic key exchange
- **Message Queue**: Handle out-of-order messages

**Double Ratchet Components**:
1. **Sending Chain**: Ratchet forward mỗi khi send message
2. **Receiving Chain**: Ratchet forward khi receive DH key
3. **Chain Keys**: Derive message keys từ chain keys (KDF chain)
4. **DH Ratchet**: Generate new DH key pair periodically
5. **Message Queue**: Store out-of-order messages

**Security Properties**:
- **Forward Secrecy**: Old keys cannot decrypt new messages
- **Break-in Recovery**: Old messages cannot be decrypted after compromise
- **Out-of-order**: Messages queued until chain catches up

**Consequences**:
- ✅ Maximum security cho message exchange
- ✅ Industry-proven approach (Signal)
- ⚠️ Cần careful implementation để đảm bảo properties
- ✅ Protects against both passive và active attacks

---

## TD-011: Session Management (Sesame)

**Date**: 2024-12-XX  
**Status**: Accepted  
**Context**: Cần quản lý session state cho multiple conversations và devices.

**Decision**: Implement **Sesame** session management system.

**Features**:
- Multi-session management (one per contact/conversation)
- Secure session state storage (via keystore adapter)
- Session lifecycle: create, update, delete, restore
- Session expiration và cleanup
- Multi-device session synchronization

**Storage**:
- Session state encrypted với device-specific key
- Stored in platform keystore (Secure Enclave / Android Keystore)
- Never expose private keys

**Consequences**:
- ✅ Secure session management
- ✅ Supports multi-device scenarios
- ✅ Proper cleanup và expiration
- ⚠️ Cần careful state management

---

## Summary of Key Decisions

| Decision | Status | Impact |
|----------|--------|--------|
| Rust core | ✅ Accepted | High - affects entire codebase |
| Composite crypto libs | ✅ Accepted | High - security foundation |
| Protobuf messages | ✅ Accepted | Medium - interoperability |
| REST API (MVP) | ✅ Accepted | Low - can migrate later |
| Optional encrypted backup | ✅ Accepted | Medium - UX/privacy balance |
| Sender keys | ✅ Accepted | High - group messaging efficiency |
| IoT lightweight SDK | 📋 Proposed | Low - future consideration |
| Platform keystores | ✅ Accepted | High - security foundation |
| X3DH/PQXDH | ✅ Accepted | High - key agreement foundation |
| Double Ratchet | ✅ Accepted | High - message security |
| Sesame | ✅ Accepted | Medium - session management |

---

## Review Process

- Decisions được review trong Phase 0
- Major changes cần team consensus
- Revisit decisions nếu có blockers hoặc better alternatives xuất hiện
- Document rationale để future team members hiểu context

---

## References

- Signal Protocol specification
- X3DH key agreement protocol
- Double Ratchet algorithm
- Sender Keys for group messaging

