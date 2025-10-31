//! Cryptographic key management module
//!
//! This module provides key generation and management for X3DH protocol:
//! - Identity Keys (X25519) - long-term identity
//! - Signed Prekeys (X25519 + Ed25519 signature) - medium-term keys
//! - One-Time Prekeys (X25519) - single-use keys

pub mod identity;
pub mod prekey;

pub use identity::IdentityKeyPair;
pub use prekey::{PreKeyBundle, SignedPreKey, OneTimePreKey, PreKeyId};

