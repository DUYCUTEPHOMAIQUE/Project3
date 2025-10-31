//! X3DH Initiator (Alice side)
//!
//! Implements the initiator side of X3DH protocol:
//! 1. Fetch prekey bundle from server
//! 2. Generate ephemeral key (EK)
//! 3. Calculate shared secret: SK = KDF(DH1 || DH2 || DH3 || DH4)
//! 4. Encrypt initial message with SK

use x25519_dalek::{PublicKey, StaticSecret};
use rand::rngs::OsRng;
use crate::error::{E2EEError, Result};
use crate::keys::{IdentityKeyPair, PreKeyBundle, OneTimePreKey};
use super::handshake::{SharedSecret, derive_shared_secret, dh};

/// X3DH Initiator Result
pub struct InitiatorResult {
    /// Shared secret (SK) for Double Ratchet initialization
    pub shared_secret: SharedSecret,
    /// Ephemeral key pair (public key will be sent to Bob)
    pub ephemeral_key_pair: (StaticSecret, PublicKey),
    /// One-time prekey that was used (if any)
    pub used_one_time_prekey: Option<OneTimePreKey>,
}

/// Initiate X3DH key exchange
///
/// This function implements the initiator side (Alice) of X3DH protocol.
/// It takes Alice's identity key pair and Bob's prekey bundle, then:
/// 1. Generates an ephemeral key (EK)
/// 2. Calculates shared secret: SK = KDF(DH1 || DH2 || DH3 || DH4)
///    - DH1 = DH(IKA, SPKB)
///    - DH2 = DH(EK, IKB)
///    - DH3 = DH(EK, SPKB)
///    - DH4 = DH(EK, OPKB) [if available]
///
/// Returns the shared secret and ephemeral key pair.
pub fn initiate(
    alice_identity: &IdentityKeyPair,
    bob_prekey_bundle: &mut PreKeyBundle,
) -> Result<InitiatorResult> {
    // Generate ephemeral key (EK)
    let ephemeral_private = StaticSecret::random_from_rng(&mut OsRng);
    let ephemeral_public = PublicKey::from(&ephemeral_private);
    
    // Get Bob's identity public key
    let bob_identity_public = PublicKey::from_bytes(&bob_prekey_bundle.identity_key)
        .map_err(|e| E2EEError::Key(format!("Invalid Bob identity key: {}", e)))?;
    
    // Get Bob's signed prekey public key
    let bob_signed_prekey_public = bob_prekey_bundle.signed_prekey.public_key()?;
    
    // Try to get a one-time prekey (optional but preferred)
    let one_time_prekey = bob_prekey_bundle.take_one_time_prekey();
    
    // Calculate DH operations
    // DH1 = DH(IKA, SPKB)
    let alice_identity_private = alice_identity.private_key();
    let dh1 = dh(alice_identity_private, &bob_signed_prekey_public);
    
    // DH2 = DH(EK, IKB)
    let dh2 = dh(&ephemeral_private, &bob_identity_public);
    
    // DH3 = DH(EK, SPKB)
    let dh3 = dh(&ephemeral_private, &bob_signed_prekey_public);
    
    // DH4 = DH(EK, OPKB) [if available]
    let mut dh_outputs = vec![dh1.as_slice(), dh2.as_slice(), dh3.as_slice()];
    
    let used_one_time_prekey = if let Some(ref opk) = one_time_prekey {
        let opk_public = opk.public_key()?;
        let dh4 = dh(&ephemeral_private, &opk_public);
        dh_outputs.push(dh4.as_slice());
        Some(opk.clone())
    } else {
        None
    };
    
    // Derive shared secret: SK = KDF(DH1 || DH2 || DH3 || DH4)
    let shared_secret = derive_shared_secret(&dh_outputs)?;
    
    Ok(InitiatorResult {
        shared_secret,
        ephemeral_key_pair: (ephemeral_private, ephemeral_public),
        used_one_time_prekey,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keys::{SignedPreKey, PreKeyId};
    use ed25519_dalek::SigningKey;

    #[test]
    fn test_x3dh_initiate_with_one_time_prekey() {
        // Setup: Bob's keys
        let bob_identity = IdentityKeyPair::generate();
        let bob_signing_key = SigningKey::generate(&mut OsRng);
        let bob_signed_prekey = SignedPreKey::generate(1, &bob_signing_key).unwrap();
        let bob_one_time_prekeys: Vec<OneTimePreKey> = (0..5)
            .map(|i| OneTimePreKey::generate(i as PreKeyId))
            .collect();
        
        let mut bob_bundle = PreKeyBundle::new(
            &bob_identity,
            bob_signed_prekey,
            bob_one_time_prekeys,
        ).unwrap();
        
        // Alice initiates
        let alice_identity = IdentityKeyPair::generate();
        let result = initiate(&alice_identity, &mut bob_bundle).unwrap();
        
        // Verify results
        assert_eq!(result.shared_secret.len(), 32);
        assert!(result.used_one_time_prekey.is_some());
        assert_eq!(bob_bundle.one_time_prekeys.len(), 4); // One was consumed
    }

    #[test]
    fn test_x3dh_initiate_without_one_time_prekey() {
        // Setup: Bob's keys with minimal one-time prekey
        let bob_identity = IdentityKeyPair::generate();
        let bob_signing_key = SigningKey::generate(&mut OsRng);
        let bob_signed_prekey = SignedPreKey::generate(1, &bob_signing_key).unwrap();
        let mut bob_bundle = PreKeyBundle::new(
            &bob_identity,
            bob_signed_prekey,
            vec![OneTimePreKey::generate(1)],
        ).unwrap();
        
        // Alice initiates
        let alice_identity = IdentityKeyPair::generate();
        let result = initiate(&alice_identity, &mut bob_bundle).unwrap();
        
        // Verify results (should still work)
        assert_eq!(result.shared_secret.len(), 32);
        assert_eq!(bob_bundle.one_time_prekeys.len(), 0); // One was consumed
    }
}

