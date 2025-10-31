//! Prekey management for X3DH protocol
//!
//! This module provides:
//! - Signed Prekeys (X25519 + Ed25519 signature)
//! - One-Time Prekeys (X25519)
//! - PreKeyBundle (combination of identity, signed prekey, and one-time prekeys)

use x25519_dalek::{PublicKey, StaticSecret};
use ed25519_dalek::{SigningKey, VerifyingKey, Signature, Signer};
use rand::rngs::OsRng;
use serde::{Serialize, Deserialize};
use crate::error::{E2EEError, Result};
use super::identity::IdentityKeyPair;

/// Prekey ID type
pub type PreKeyId = u32;

/// Signed Prekey (X25519 + Ed25519 signature)
///
/// A medium-term prekey that is signed by the identity key.
/// Used in X3DH protocol to ensure authenticity.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedPreKey {
    /// Prekey ID (unique identifier)
    pub id: PreKeyId,
    /// X25519 public key
    pub public_key: [u8; 32],
    /// Ed25519 signature of the public key
    pub signature: [u8; 64],
    /// Timestamp when this prekey was created (Unix timestamp)
    pub timestamp: u64,
}

impl SignedPreKey {
    /// Generate a new signed prekey
    ///
    /// Signs the X25519 prekey with the Ed25519 identity signing key.
    pub fn generate(id: PreKeyId, identity_signing_key: &SigningKey) -> Result<Self> {
        // Generate X25519 key pair
        let prekey_private = StaticSecret::random_from_rng(&mut OsRng);
        let prekey_public = PublicKey::from(&prekey_private);
        
        // Sign the public key with Ed25519 identity key
        let message = prekey_public.as_bytes();
        let signature = identity_signing_key.sign(message);
        
        let timestamp = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| E2EEError::Internal(format!("Time error: {}", e)))?
            .as_secs();
        
        Ok(Self {
            id,
            public_key: prekey_public.to_bytes(),
            signature: signature.to_bytes(),
            timestamp,
        })
    }

    /// Verify the signature of this signed prekey
    pub fn verify(&self, identity_verifying_key: &VerifyingKey) -> Result<()> {
        let signature = Signature::from_bytes(&self.signature)
            .map_err(|e| E2EEError::Crypto(format!("Invalid signature: {}", e)))?;
        
        identity_verifying_key.verify_strict(&self.public_key, &signature)
            .map_err(|e| E2EEError::Crypto(format!("Signature verification failed: {}", e)))?;
        
        Ok(())
    }

    /// Get public key as PublicKey type
    pub fn public_key(&self) -> Result<PublicKey> {
        PublicKey::from_bytes(&self.public_key)
            .map_err(|e| E2EEError::Key(format!("Invalid public key: {}", e)))
    }
}

/// One-Time Prekey (X25519)
///
/// A single-use prekey that is consumed after use.
/// Used in X3DH protocol for initial key exchange.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OneTimePreKey {
    /// Prekey ID (unique identifier)
    pub id: PreKeyId,
    /// X25519 public key
    pub public_key: [u8; 32],
}

impl OneTimePreKey {
    /// Generate a new one-time prekey
    pub fn generate(id: PreKeyId) -> Self {
        let private_key = StaticSecret::random_from_rng(&mut OsRng);
        let public_key = PublicKey::from(&private_key);
        
        Self {
            id,
            public_key: public_key.to_bytes(),
        }
    }

    /// Get public key as PublicKey type
    pub fn public_key(&self) -> Result<PublicKey> {
        PublicKey::from_bytes(&self.public_key)
            .map_err(|e| E2EEError::Key(format!("Invalid public key: {}", e)))
    }
}

/// PreKey Bundle
///
/// Contains all the keys needed for X3DH key exchange:
/// - Identity public key
/// - Signed prekey
/// - One or more one-time prekeys
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreKeyBundle {
    /// Identity public key (32 bytes)
    pub identity_key: [u8; 32],
    /// Signed prekey
    pub signed_prekey: SignedPreKey,
    /// One-time prekeys (at least one should be present)
    pub one_time_prekeys: Vec<OneTimePreKey>,
}

impl PreKeyBundle {
    /// Create a new prekey bundle
    pub fn new(
        identity_key_pair: &IdentityKeyPair,
        signed_prekey: SignedPreKey,
        one_time_prekeys: Vec<OneTimePreKey>,
    ) -> Result<Self> {
        if one_time_prekeys.is_empty() {
            return Err(E2EEError::InvalidInput(
                "PreKeyBundle must contain at least one one-time prekey".to_string()
            ));
        }

        Ok(Self {
            identity_key: identity_key_pair.public_key_bytes(),
            signed_prekey,
            one_time_prekeys,
        })
    }

    /// Verify the signed prekey in this bundle
    pub fn verify_signed_prekey(&self, identity_verifying_key: &VerifyingKey) -> Result<()> {
        self.signed_prekey.verify(identity_verifying_key)
    }

    /// Get the first available one-time prekey and remove it
    pub fn take_one_time_prekey(&mut self) -> Option<OneTimePreKey> {
        if !self.one_time_prekeys.is_empty() {
            Some(self.one_time_prekeys.remove(0))
        } else {
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_signed_prekey_generation() {
        let signing_key = SigningKey::generate(&mut OsRng);
        let signed_prekey = SignedPreKey::generate(1, &signing_key).unwrap();
        
        assert_eq!(signed_prekey.id, 1);
        assert_eq!(signed_prekey.public_key.len(), 32);
        assert_eq!(signed_prekey.signature.len(), 64);
        assert!(signed_prekey.timestamp > 0);
    }

    #[test]
    fn test_signed_prekey_verification() {
        let signing_key = SigningKey::generate(&mut OsRng);
        let verifying_key = signing_key.verifying_key();
        
        let signed_prekey = SignedPreKey::generate(1, &signing_key).unwrap();
        
        // Verify should succeed
        assert!(signed_prekey.verify(&verifying_key).is_ok());
    }

    #[test]
    fn test_one_time_prekey_generation() {
        let one_time_prekey = OneTimePreKey::generate(1);
        
        assert_eq!(one_time_prekey.id, 1);
        assert_eq!(one_time_prekey.public_key.len(), 32);
    }

    #[test]
    fn test_batch_one_time_prekey_generation() {
        let prekeys: Vec<OneTimePreKey> = (0..100)
            .map(|i| OneTimePreKey::generate(i as PreKeyId))
            .collect();
        
        assert_eq!(prekeys.len(), 100);
        
        // Verify all IDs are unique
        for i in 0..prekeys.len() {
            for j in (i + 1)..prekeys.len() {
                assert_ne!(prekeys[i].id, prekeys[j].id);
            }
        }
        
        // Verify all public keys are unique
        for i in 0..prekeys.len() {
            for j in (i + 1)..prekeys.len() {
                assert_ne!(prekeys[i].public_key, prekeys[j].public_key);
            }
        }
    }

    #[test]
    fn test_prekey_bundle_creation() {
        let identity_key_pair = IdentityKeyPair::generate();
        let signing_key = SigningKey::generate(&mut OsRng);
        let signed_prekey = SignedPreKey::generate(1, &signing_key).unwrap();
        let one_time_prekeys: Vec<OneTimePreKey> = (0..5)
            .map(|i| OneTimePreKey::generate(i as PreKeyId))
            .collect();
        
        let bundle = PreKeyBundle::new(
            &identity_key_pair,
            signed_prekey,
            one_time_prekeys,
        ).unwrap();
        
        assert_eq!(bundle.identity_key.len(), 32);
        assert_eq!(bundle.one_time_prekeys.len(), 5);
    }

    #[test]
    fn test_prekey_bundle_requires_one_time_prekey() {
        let identity_key_pair = IdentityKeyPair::generate();
        let signing_key = SigningKey::generate(&mut OsRng);
        let signed_prekey = SignedPreKey::generate(1, &signing_key).unwrap();
        
        // Try to create bundle with no one-time prekeys
        let result = PreKeyBundle::new(&identity_key_pair, signed_prekey, vec![]);
        assert!(result.is_err());
    }

    #[test]
    fn test_prekey_bundle_take_one_time_prekey() {
        let identity_key_pair = IdentityKeyPair::generate();
        let signing_key = SigningKey::generate(&mut OsRng);
        let signed_prekey = SignedPreKey::generate(1, &signing_key).unwrap();
        let one_time_prekeys: Vec<OneTimePreKey> = (0..3)
            .map(|i| OneTimePreKey::generate(i as PreKeyId))
            .collect();
        
        let mut bundle = PreKeyBundle::new(
            &identity_key_pair,
            signed_prekey,
            one_time_prekeys,
        ).unwrap();
        
        assert_eq!(bundle.one_time_prekeys.len(), 3);
        
        let taken = bundle.take_one_time_prekey().unwrap();
        assert_eq!(taken.id, 0);
        assert_eq!(bundle.one_time_prekeys.len(), 2);
        
        let taken2 = bundle.take_one_time_prekey().unwrap();
        assert_eq!(taken2.id, 1);
        assert_eq!(bundle.one_time_prekeys.len(), 1);
        
        let taken3 = bundle.take_one_time_prekey().unwrap();
        assert_eq!(taken3.id, 2);
        assert_eq!(bundle.one_time_prekeys.len(), 0);
        
        assert!(bundle.take_one_time_prekey().is_none());
    }
}

