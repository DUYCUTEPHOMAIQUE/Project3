//! Identity Key Pair (X25519)
//!
//! Used for long-term identity in X3DH protocol.
//! Private key should be stored securely (hardware-backed keystore).

use x25519_dalek::{PublicKey, StaticSecret};
use rand::rngs::OsRng;
use hex;

/// Identity Key Pair (X25519)
/// 
/// Used for long-term identity in X3DH protocol.
/// Private key should be stored securely (hardware-backed keystore).
#[derive(Debug, Clone)]
pub struct IdentityKeyPair {
    /// Private key (should be stored securely)
    private_key: StaticSecret,
    /// Public key (can be shared)
    public_key: PublicKey,
}

impl IdentityKeyPair {
    /// Generate a new identity key pair
    pub fn generate() -> Self {
        let private_key = StaticSecret::random_from_rng(&mut OsRng);
        let public_key = PublicKey::from(&private_key);
        
        Self {
            private_key,
            public_key,
        }
    }

    /// Get the public key
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Get public key as bytes (32 bytes)
    pub fn public_key_bytes(&self) -> [u8; 32] {
        self.public_key.to_bytes()
    }

    /// Get public key as hex string
    pub fn public_key_hex(&self) -> String {
        hex::encode(self.public_key_bytes())
    }

    /// Get the private key (for internal use only)
    /// 
    /// WARNING: This should not be exposed outside the crypto module.
    /// Private keys should only be accessed through secure interfaces.
    pub(crate) fn private_key(&self) -> &StaticSecret {
        &self.private_key
    }
}

impl Default for IdentityKeyPair {
    fn default() -> Self {
        Self::generate()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_identity_key_generation() {
        let key_pair = IdentityKeyPair::generate();
        
        // Verify public key is valid
        let public_bytes = key_pair.public_key_bytes();
        assert_eq!(public_bytes.len(), 32);
        
        // Verify hex encoding
        let hex = key_pair.public_key_hex();
        assert_eq!(hex.len(), 64); // 32 bytes * 2 hex chars
        
        // Verify can decode hex
        let decoded = hex::decode(&hex).unwrap();
        assert_eq!(decoded, public_bytes);
    }

    #[test]
    fn test_identity_key_uniqueness() {
        let key_pair1 = IdentityKeyPair::generate();
        let key_pair2 = IdentityKeyPair::generate();
        
        // Verify keys are different
        assert_ne!(
            key_pair1.public_key_bytes(),
            key_pair2.public_key_bytes()
        );
    }

    #[test]
    fn test_identity_key_multiple_generations() {
        // Generate multiple keys to ensure randomness
        let keys: Vec<IdentityKeyPair> = (0..100).map(|_| IdentityKeyPair::generate()).collect();
        
        // Verify all keys are unique
        for i in 0..keys.len() {
            for j in (i + 1)..keys.len() {
                assert_ne!(
                    keys[i].public_key_bytes(),
                    keys[j].public_key_bytes()
                );
            }
        }
    }
}

