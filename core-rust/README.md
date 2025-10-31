# PoC - Core Crypto Library Setup

## Overview
Basic PoC implementation để validate crypto library setup và key generation.

## What's Implemented

### 1. Identity Key Pair Generation (X25519)
- `IdentityKeyPair` struct với X25519 keys
- Secure key generation sử dụng `OsRng`
- Public key export (bytes và hex)
- Private key protection (không expose ra ngoài)

### 2. Error Handling
- `E2EEError` enum với các error types
- `Result<T>` type alias

### 3. Tests
- Unit tests trong `keys.rs`
- Integration test trong `tests/integration_test.rs`
- Test key generation và uniqueness

## Files Created

```
core-rust/
├── Cargo.toml (updated với dependencies)
├── src/
│   ├── lib.rs (main library entry)
│   ├── keys.rs (key generation)
│   └── error.rs (error types)
└── tests/
    └── integration_test.rs
```

## Dependencies

- `x25519-dalek`: X25519 key exchange
- `ed25519-dalek`: Ed25519 signatures (for signed prekeys)
- `ring`: AEAD, HKDF, HMAC
- `rand`: Secure random number generation
- `hex`: Hex encoding/decoding
- `thiserror`: Error handling

## Next Steps

1. Implement prekey generation (signed prekey, one-time prekeys)
2. Implement X3DH handshake
3. Add more comprehensive tests

## Testing

Run tests:
```bash
cargo test
```

Run specific test:
```bash
cargo test test_identity_key_generation
```

