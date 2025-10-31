//! X3DH Handshake - Core functions

use x25519_dalek::{PublicKey, StaticSecret};
use ring::hkdf;
use crate::error::{E2EEError, Result};
use crate::keys::{IdentityKeyPair, PreKeyBundle, OneTimePreKey};

/// X3DH shared secret output (32 bytes)
pub type SharedSecret = [u8; 32];

/// HKDF info string for X3DH
const X3DH_INFO: &[u8] = b"E2EE X3DH Shared Secret";

/// Calculate shared secret from DH outputs using HKDF
pub fn derive_shared_secret(dh_outputs: &[&[u8]]) -> Result<SharedSecret> {
    // Concatenate all DH outputs
    let mut input = Vec::new();
    for output in dh_outputs {
        input.extend_from_slice(output);
    }
    
    // Use HKDF-SHA256 to derive 32-byte shared secret
    let salt = hkdf::Salt::new(hkdf::HKDF_SHA256, &[]);
    let prk = salt.extract(&input);
    let okm = prk.expand(&[X3DH_INFO], hkdf::HKDF_SHA256)
        .map_err(|_| E2EEError::Crypto("HKDF expansion failed".to_string()))?;
    
    let mut output = [0u8; 32];
    okm.fill(&mut output)
        .map_err(|_| E2EEError::Crypto("HKDF output length mismatch".to_string()))?;
    
    Ok(output)
}

/// Perform X25519 Diffie-Hellman key exchange
pub fn dh(private_key: &StaticSecret, public_key: &PublicKey) -> [u8; 32] {
    private_key.diffie_hellman(public_key).to_bytes()
}

#[cfg(test)]
mod tests {
    use super::*;
    use rand::rngs::OsRng;

    #[test]
    fn test_dh_symmetric() {
        // Generate two key pairs
        let alice_private = StaticSecret::random_from_rng(&mut OsRng);
        let alice_public = PublicKey::from(&alice_private);
        
        let bob_private = StaticSecret::random_from_rng(&mut OsRng);
        let bob_public = PublicKey::from(&bob_private);
        
        // Both parties should get the same shared secret
        let alice_shared = dh(&alice_private, &bob_public);
        let bob_shared = dh(&bob_private, &alice_public);
        
        assert_eq!(alice_shared, bob_shared);
    }

    #[test]
    fn test_derive_shared_secret() {
        let dh1 = b"test_dh_output_1_32_bytes_long!!!";
        let dh2 = b"test_dh_output_2_32_bytes_long!!!";
        let dh3 = b"test_dh_output_3_32_bytes_long!!!";
        
        let secret = derive_shared_secret(&[dh1, dh2, dh3]).unwrap();
        
        assert_eq!(secret.len(), 32);
        
        // Same inputs should produce same output
        let secret2 = derive_shared_secret(&[dh1, dh2, dh3]).unwrap();
        assert_eq!(secret, secret2);
        
        // Different inputs should produce different output
        let dh4 = b"test_dh_output_4_32_bytes_long!!!";
        let secret3 = derive_shared_secret(&[dh1, dh2, dh4]).unwrap();
        assert_ne!(secret, secret3);
    }
}

