# Hướng dẫn Sử dụng E2EE Core Library

## Tổng quan

Thư viện `e2ee-core` cung cấp các chức năng crypto cơ bản cho end-to-end encryption:
- **Key Generation**: Identity keys, Signed prekeys, One-time prekeys
- **X3DH**: Key agreement protocol cho asynchronous messaging
- **Double Ratchet**: Forward secrecy và break-in recovery cho message exchange
- **Message Format**: MessageEnvelope với serialization

## Cài đặt

Thêm vào `Cargo.toml` của project:

```toml
[dependencies]
e2ee-core = { path = "../core-rust" }
```

Hoặc nếu publish lên crates.io:

```toml
[dependencies]
e2ee-core = "0.1.0"
```

## Quy trình Sử dụng Cơ bản

### 1. Generate Keys

```rust
use e2ee_core::keys::IdentityKeyPair;
use e2ee_core::keys::prekey::{SignedPreKeyPair, OneTimePreKeyPair};

// Generate identity key
let identity = IdentityKeyPair::generate();

// Generate signed prekey (signed by identity)
let signed_prekey = SignedPreKeyPair::generate(1, &identity)?;

// Generate one-time prekey
let one_time_prekey = OneTimePreKeyPair::generate(1);
```

### 2. X3DH Handshake

**Bob side (Responder) - Publish keys:**
```rust
use e2ee_core::keys::{IdentityKeyPair, PreKeyBundle};
use e2ee_core::keys::prekey::{SignedPreKey, OneTimePreKey};

let bob_identity = IdentityKeyPair::generate();
let bob_signed_prekey = SignedPreKeyPair::generate(1, &bob_identity)?;
let bob_one_time_prekey = OneTimePreKeyPair::generate(1);

// Create prekey bundle to publish
let prekey_bundle = PreKeyBundle::new(
    bob_identity.public_key_hex(),
    SignedPreKey::from(&bob_signed_prekey),
    Some(OneTimePreKey::from(&bob_one_time_prekey)),
);
```

**Alice side (Initiator) - Initiate handshake:**
```rust
use e2ee_core::x3dh::{X3DHInitiator, X3DHResult};

let alice_identity = IdentityKeyPair::generate();
let alice = X3DHInitiator::new(alice_identity);

// Fetch prekey_bundle from Bob (via server)
let result: X3DHResult = alice.initiate(&prekey_bundle)?;

// result.shared_secret: [u8; 32] - shared secret for Double Ratchet
// result.ephemeral_public_key_hex: String - send to Bob
```

**Bob side (Responder) - Respond to handshake:**
```rust
use e2ee_core::x3dh::{X3DHResponder, X3DHResponseResult};
use x25519_dalek::{EphemeralSecret, PublicKey};

// Bob has prekeys stored
let bob_one_time_private = bob_one_time_prekey.private_key(); // &EphemeralSecret
let bob_one_time_private_bytes = unsafe {
    std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(bob_one_time_private)
};
let bob_one_time_private = unsafe {
    std::mem::transmute::<[u8; 32], EphemeralSecret>(bob_one_time_private_bytes)
};
let bob_one_time_public = PublicKey::from(&bob_one_time_private);

let mut bob = X3DHResponder::new(bob_identity, bob_signed_prekey);
bob.set_one_time_prekey(1, bob_one_time_private, bob_one_time_public);

// Receive alice_identity_hex and ephemeral_public_key_hex from Alice
let bob_result: X3DHResponseResult = bob.respond(
    &alice_identity.public_key_hex(),
    &result.ephemeral_public_key_hex,
)?;

// bob_result.shared_secret should equal result.shared_secret
```

### 3. Double Ratchet - Encrypt/Decrypt Messages

**Initialize Double Ratchet:**
```rust
use e2ee_core::ratchet::DoubleRatchet;

// Alice (initiator)
let mut alice_dr = DoubleRatchet::from_shared_secret(&shared_secret, true)?;

// Bob (responder)
let mut bob_dr = DoubleRatchet::from_shared_secret(&shared_secret, false)?;
```

**Alice encrypts a message:**
```rust
use e2ee_core::message::MessageEnvelope;

let plaintext = b"Hello, this is a secret message!";
let envelope: MessageEnvelope = alice_dr.encrypt_envelope(plaintext)?;

// Serialize envelope to send
let b64 = envelope.to_base64()?;
// Send b64 to Bob via server
```

**Bob decrypts the message:**
```rust
// Receive b64 from Alice
let envelope = MessageEnvelope::from_base64(&b64)?;
let decrypted = bob_dr.decrypt_envelope(&envelope)?;

println!("Decrypted: {}", String::from_utf8_lossy(&decrypted));
```

**Bob encrypts a reply:**
```rust
let reply = b"Hi Alice! This is Bob's reply.";
let reply_envelope = bob_dr.encrypt_envelope(reply)?;
let reply_b64 = reply_envelope.to_base64()?;
```

**Alice decrypts Bob's reply:**
```rust
let reply_envelope = MessageEnvelope::from_base64(&reply_b64)?;
let decrypted_reply = alice_dr.decrypt_envelope(&reply_envelope)?;
```

## Example Code

Xem file `examples/basic_usage.rs` để xem ví dụ đầy đủ:

```bash
cargo run --manifest-path core-rust/Cargo.toml --example basic_usage
```

## API Reference

### Keys Module

- `IdentityKeyPair::generate()` - Generate identity key pair
- `SignedPreKeyPair::generate(id, identity)` - Generate signed prekey
- `OneTimePreKeyPair::generate(id)` - Generate one-time prekey
- `PreKeyBundle::new(identity_hex, signed_prekey, one_time_prekey)` - Create bundle

### X3DH Module

- `X3DHInitiator::new(identity)` - Create initiator
- `X3DHInitiator::initiate(bundle)` - Initiate handshake
- `X3DHResponder::new(identity, signed_prekey)` - Create responder
- `X3DHResponder::respond(identity_hex, ephemeral_hex)` - Respond to handshake

### Double Ratchet Module

- `DoubleRatchet::from_shared_secret(secret, is_initiator)` - Initialize
- `DoubleRatchet::encrypt_envelope(plaintext)` - Encrypt message
- `DoubleRatchet::decrypt_envelope(envelope)` - Decrypt message

### Message Module

- `MessageEnvelope::regular(ciphertext, dh_hex, prev_len, msg_num)` - Create envelope
- `MessageEnvelope::to_base64()` - Serialize to base64
- `MessageEnvelope::from_base64(b64)` - Deserialize from base64

## Lưu Ý Quan Trọng

1. **Nonce Handling**: Hiện tại sử dụng fixed nonce (all zeros). Trong production, cần implement proper nonce sequence dựa trên message number.

2. **Key Storage**: Private keys cần được lưu trữ an toàn (hardware-backed keystores khi có thể).

3. **Session Management**: Cần implement session state serialization/deserialization để persist state giữa các lần khởi động lại app.

4. **Out-of-order Messages**: Hiện tại chưa implement message queue cho out-of-order messages. Cần implement để handle messages không theo thứ tự.

5. **DH Ratchet**: DH ratchet được trigger khi nhận DH public key mới. Đảm bảo DH keys được exchange đúng cách.

## Commands để Check Code

```bash
# Check compilation
cargo check --manifest-path core-rust/Cargo.toml --lib

# Build library
cargo build --manifest-path core-rust/Cargo.toml --lib

# Run example
cargo run --manifest-path core-rust/Cargo.toml --example basic_usage

# Run tests (if any)
cargo test --manifest-path core-rust/Cargo.toml
```

