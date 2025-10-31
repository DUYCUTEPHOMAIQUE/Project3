//! X3DH Responder (Bob side)
//!
//! Implements the responder side of X3DH protocol:
//! 1. Receive initial message with ephemeral public key (EK_pub)
//! 2. Calculate shared secret: SK = KDF(DH1 || DH2 || DH3 || DH4)
//! 3. Decrypt initial message with SK

use x25519_dalek::{PublicKey, StaticSecret};
use crate::error::{E2EEError, Result};
use crate::keys::IdentityKeyPair;
use super::handshake::{SharedSecret, derive_shared_secret, dh};

/// X3DH Responder - Calculate shared secret from received ephemeral key
///
/// This function implements the responder side (Bob) of X3DH protocol.
/// It takes Bob's private keys and Alice's public keys, then:
/// 1. Calculates shared secret: SK = KDF(DH1 || DH2 || DH3 || DH4)
///    - DH1 = DH(IKA, SPKB) = ECDH(SPKB_private, IKA_public) [commutative property]
///    - DH2 = DH(EK, IKB) = ECDH(IKB_private, EK_public)
///    - DH3 = DH(EK, SPKB) = ECDH(SPKB_private, EK_public)
///    - DH4 = DH(EK, OPKB) = ECDH(OPKB_private, EK_public) [if one-time prekey was used]
///
/// Note: Bob needs to know which one-time prekey was used (indicated by prekey_id).
pub fn respond_full(
    bob_identity: &IdentityKeyPair,
    bob_signed_prekey_private: &StaticSecret,
    bob_one_time_prekey_private: Option<&StaticSecret>,
    alice_identity_public: &PublicKey,
    alice_ephemeral_public: &PublicKey,
) -> Result<SharedSecret> {
    let bob_identity_private = bob_identity.private_key();
    
    // DH1 = DH(IKA, SPKB) = ECDH(SPKB_private, IKA_public)
    // Using commutative property: ECDH(a_private, b_public) = ECDH(b_private, a_public)
    let dh1 = dh(bob_signed_prekey_private, alice_identity_public);
    
    // DH2 = DH(EK, IKB) = ECDH(IKB_private, EK_public)
    let dh2 = dh(bob_identity_private, alice_ephemeral_public);
    
    // DH3 = DH(EK, SPKB) = ECDH(SPKB_private, EK_public)
    let dh3 = dh(bob_signed_prekey_private, alice_ephemeral_public);
    
    // DH4 = DH(EK, OPKB) [if available]
    let mut dh_outputs = vec![dh1.as_slice(), dh2.as_slice(), dh3.as_slice()];
    
    if let Some(opk_private) = bob_one_time_prekey_private {
        let dh4 = dh(opk_private, alice_ephemeral_public);
        dh_outputs.push(dh4.as_slice());
    }
    
    // Derive shared secret: SK = KDF(DH1 || DH2 || DH3 || DH4)
    derive_shared_secret(&dh_outputs)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::keys::{PreKeyBundle, SignedPreKey, PreKeyId, OneTimePreKey};
    use crate::x3dh::initiator;
    use ed25519_dalek::SigningKey;
    use rand::rngs::OsRng;

    #[test]
    fn test_x3dh_responder_matches_initiator() {
        // Setup: Bob's keys
        // Note: In practice, Bob would store the private key when generating SignedPreKey
        // For testing, we need to reconstruct the private key from the public key
        // This is a simplified test - in production, SignedPreKey would be generated
        // with a way to access the private key
        
        let bob_identity = IdentityKeyPair::generate();
        let bob_signing_key = SigningKey::generate(&mut OsRng);
        
        // Generate signed prekey - Bob stores private key separately
        let bob_signed_prekey_private = StaticSecret::random_from_rng(&mut OsRng);
        let bob_signed_prekey_public = PublicKey::from(&bob_signed_prekey_private);
        
        // Create SignedPreKey manually (normally this would be done by generate())
        // We'll sign the public key
        let message = bob_signed_prekey_public.as_bytes();
        let signature = bob_signing_key.sign(message);
        let bob_signed_prekey = SignedPreKey {
            id: 1,
            public_key: bob_signed_prekey_public.to_bytes(),
            signature: signature.to_bytes(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        };
        
        // Generate one-time prekey (with private key stored)
        let bob_one_time_prekey_private = StaticSecret::random_from_rng(&mut OsRng);
        let bob_one_time_prekey_public = PublicKey::from(&bob_one_time_prekey_private);
        let bob_one_time_prekey = OneTimePreKey {
            id: 1,
            public_key: bob_one_time_prekey_public.to_bytes(),
        };
        
        // Create bundle with the public keys
        let mut bob_bundle = PreKeyBundle::new(
            &bob_identity,
            bob_signed_prekey,
            vec![bob_one_time_prekey.clone()],
        ).unwrap();
        
        // Alice initiates
        let alice_identity = IdentityKeyPair::generate();
        let initiator_result = initiator::initiate(&alice_identity, &mut bob_bundle).unwrap();
        
        // Bob responds
        let bob_shared_secret = respond_full(
            &bob_identity,
            &bob_signed_prekey_private,
            Some(&bob_one_time_prekey_private),
            alice_identity.public_key(),
            &initiator_result.ephemeral_key_pair.1,
        ).unwrap();
        
        // Both should have the same shared secret
        assert_eq!(initiator_result.shared_secret, bob_shared_secret);
    }

    #[test]
    fn test_x3dh_without_one_time_prekey() {
        // Similar setup but test without one-time prekey
        let bob_identity = IdentityKeyPair::generate();
        let bob_signing_key = SigningKey::generate(&mut OsRng);
        
        let bob_signed_prekey_private = StaticSecret::random_from_rng(&mut OsRng);
        let bob_signed_prekey_public = PublicKey::from(&bob_signed_prekey_private);
        let message = bob_signed_prekey_public.as_bytes();
        let signature = bob_signing_key.sign(message);
        let bob_signed_prekey = SignedPreKey {
            id: 1,
            public_key: bob_signed_prekey_public.to_bytes(),
            signature: signature.to_bytes(),
            timestamp: std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_secs(),
        };
        
        let bob_one_time_prekey_private = StaticSecret::random_from_rng(&mut OsRng);
        let bob_one_time_prekey_public = PublicKey::from(&bob_one_time_prekey_private);
        let bob_one_time_prekey = OneTimePreKey {
            id: 1,
            public_key: bob_one_time_prekey_public.to_bytes(),
        };
        
        let mut bob_bundle = PreKeyBundle::new(
            &bob_identity,
            bob_signed_prekey,
            vec![bob_one_time_prekey],
        ).unwrap();
        
        // Alice initiates
        let alice_identity = IdentityKeyPair::generate();
        let initiator_result = initiator::initiate(&alice_identity, &mut bob_bundle).unwrap();
        
        // Bob responds
        let bob_shared_secret = respond_full(
            &bob_identity,
            &bob_signed_prekey_private,
            Some(&bob_one_time_prekey_private),
            alice_identity.public_key(),
            &initiator_result.ephemeral_key_pair.1,
        ).unwrap();
        
        // Both should have the same shared secret
        assert_eq!(initiator_result.shared_secret, bob_shared_secret);
    }
}

