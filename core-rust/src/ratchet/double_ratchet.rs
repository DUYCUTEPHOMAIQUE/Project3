//! MVP Double Ratchet implementation
//!
//! This is a minimal implementation for MVP testing:
//! - Initializes from a shared secret (SK) derived from X3DH
//! - Maintains sending/receiving chain keys and message counters
//! - Provides encrypt/decrypt using AEAD (ChaCha20-Poly1305)
//! - Skipped messages and advanced recovery not implemented yet

use ring::aead::{self, Aad, LessSafeKey, Nonce, UnboundKey, CHACHA20_POLY1305};
use ring::hkdf;
use crate::error::{E2EEError, Result};
use x25519_dalek::{PublicKey, StaticSecret};
use crate::message::{MessageEnvelope, MessageType};

/// 32-byte key
type SymKey = [u8; 32];

/// Convert slice to Nonce (96-bit)
fn nonce_from_u64(counter: u64) -> Nonce {
    let mut bytes = [0u8; 12];
    // Big-endian place the counter in the last 8 bytes
    bytes[4..].copy_from_slice(&counter.to_be_bytes());
    Nonce::assume_unique_for_key(bytes)
}

/// Derive a 32-byte key from input using HKDF-SHA256
fn hkdf_derive(input: &[u8], info: &[u8]) -> SymKey {
    let salt = hkdf::Salt::new(hkdf::HKDF_SHA256, &[]);
    let prk = salt.extract(input);
    let okm = prk.expand(&[info], hkdf::HKDF_SHA256).expect("hkdf okm");
    let mut out = [0u8; 32];
    okm.fill(&mut out).expect("hkdf fill");
    out
}

/// Ratchet state (MVP)
#[derive(Debug, Clone)]
pub struct DoubleRatchet {
    // Root key
    root_key: SymKey,
    // Sending chain key and counter
    send_chain_key: SymKey,
    send_counter: u64,
    // Receiving chain key and counter
    recv_chain_key: SymKey,
    recv_counter: u64,
}

impl DoubleRatchet {
    /// Initialize from shared secret (SK) coming from X3DH
    pub fn from_shared_secret(shared_secret: &[u8; 32]) -> Result<Self> {
        let root_key = hkdf_derive(shared_secret, b"dr-root");
        let send_chain_key = hkdf_derive(&root_key, b"dr-send");
        let recv_chain_key = hkdf_derive(&root_key, b"dr-recv");
        Ok(Self {
            root_key,
            send_chain_key,
            send_counter: 0,
            recv_chain_key,
            recv_counter: 0,
        })
    }

    /// Derive next message key from a chain key
    fn derive_message_key(chain_key: &SymKey) -> (SymKey, SymKey) {
        // chain_key_{i+1} = HKDF(chain_key_i, "ck")
        // message_key_i  = HKDF(chain_key_i, "mk")
        let next_chain = hkdf_derive(chain_key, b"ck");
        let msg_key = hkdf_derive(chain_key, b"mk");
        (next_chain, msg_key)
    }

    /// Encrypt plaintext returning (nonce, ciphertext)
    pub fn encrypt(&mut self, plaintext: &[u8]) -> Result<(u64, Vec<u8>)> {
        // Derive message key and advance send chain
        let (next_chain, msg_key_bytes) = Self::derive_message_key(&self.send_chain_key);
        self.send_chain_key = next_chain;
        let nonce_counter = self.send_counter;
        self.send_counter = self.send_counter.saturating_add(1);

        // Prepare AEAD key
        let unbound = UnboundKey::new(&CHACHA20_POLY1305, &msg_key_bytes)
            .map_err(|_| E2EEError::Crypto("Invalid AEAD key".to_string()))?;
        let key = LessSafeKey::new(unbound);
        let mut in_out = plaintext.to_vec();
        let nonce = nonce_from_u64(nonce_counter);

        key.seal_in_place_append_tag(nonce, Aad::empty(), &mut in_out)
            .map_err(|_| E2EEError::Crypto("AEAD seal failed".to_string()))?;
        Ok((nonce_counter, in_out))
    }

    /// Decrypt using provided (nonce, ciphertext)
    pub fn decrypt(&mut self, nonce_counter: u64, ciphertext: &[u8]) -> Result<Vec<u8>> {
        // Derive message key and advance recv chain to the expected counter
        // MVP: assume in-order messages only
        if nonce_counter != self.recv_counter {
            return Err(E2EEError::InvalidInput(format!(
                "Out-of-order message (expected {}, got {})",
                self.recv_counter, nonce_counter
            )));
        }
        let (next_chain, msg_key_bytes) = Self::derive_message_key(&self.recv_chain_key);
        self.recv_chain_key = next_chain;
        self.recv_counter = self.recv_counter.saturating_add(1);

        let unbound = UnboundKey::new(&CHACHA20_POLY1305, &msg_key_bytes)
            .map_err(|_| E2EEError::Crypto("Invalid AEAD key".to_string()))?;
        let key = LessSafeKey::new(unbound);
        let mut in_out = ciphertext.to_vec();
        let nonce = nonce_from_u64(nonce_counter);

        let plain = key
            .open_in_place(nonce, Aad::empty(), &mut in_out)
            .map_err(|_| E2EEError::Crypto("AEAD open failed".to_string()))?;
        Ok(plain.to_vec())
    }

    /// Encrypt and produce a MessageEnvelope (Regular)
    pub fn encrypt_envelope(&mut self, plaintext: &[u8]) -> Result<MessageEnvelope> {
        let (nonce, ct) = self.encrypt(plaintext)?;
        Ok(MessageEnvelope::regular(nonce, ct))
    }

    /// Decrypt a MessageEnvelope
    pub fn decrypt_envelope(&mut self, env: &MessageEnvelope) -> Result<Vec<u8>> {
        match env.message_type {
            MessageType::Initial | MessageType::Regular => {
                self.decrypt(env.nonce_counter, &env.ciphertext)
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_encrypt_decrypt_roundtrip() {
        let sk = [7u8; 32];
        let mut alice = DoubleRatchet::from_shared_secret(&sk).unwrap();
        let mut bob = DoubleRatchet::from_shared_secret(&sk).unwrap();

        let msg1 = b"hello ratchet";
        let (n1, c1) = alice.encrypt(msg1).unwrap();
        let p1 = bob.decrypt(n1, &c1).unwrap();
        assert_eq!(p1, msg1);

        let msg2 = b"second message";
        let (n2, c2) = bob.encrypt(msg2).unwrap();
        let p2 = alice.decrypt(n2, &c2).unwrap();
        assert_eq!(p2, msg2);
    }

    #[test]
    fn test_out_of_order_rejected_in_mvp() {
        let sk = [1u8; 32];
        let mut a = DoubleRatchet::from_shared_secret(&sk).unwrap();
        let mut b = DoubleRatchet::from_shared_secret(&sk).unwrap();
        let (n1, c1) = a.encrypt(b"one").unwrap();
        let (_n2, _c2) = a.encrypt(b"two").unwrap();
        // Bob expects n1 first; if we try n1 then ok, but if we pass wrong counter it errors
        assert!(b.decrypt(n1 + 1, &c1).is_err());
    }

    #[test]
    fn test_envelope_roundtrip() {
        let sk = [9u8; 32];
        let mut a = DoubleRatchet::from_shared_secret(&sk).unwrap();
        let mut b = DoubleRatchet::from_shared_secret(&sk).unwrap();
        let env = a.encrypt_envelope(b"Hello DR Envelope").unwrap();
        let plain = b.decrypt_envelope(&env).unwrap();
        assert_eq!(plain, b"Hello DR Envelope");
    }
}
