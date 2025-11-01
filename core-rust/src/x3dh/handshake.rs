use crate::error::{E2EEError, Result};
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Calculate shared secret for X3DH protocol
/// 
/// SK = KDF(DH1 || DH2 || DH3 || DH4)
/// where:
/// - DH1 = ECDH(IKA, SPKB)
/// - DH2 = ECDH(EK, IKB)
/// - DH3 = ECDH(EK, SPKB)
/// - DH4 = ECDH(EK, OPKB) [if available]
/// 
/// This function accepts pre-computed DH values to avoid ownership issues
/// with EphemeralSecret which cannot be cloned.
pub fn calculate_shared_secret_from_dh(
    dh1: &[u8; 32],
    dh2: &[u8; 32],
    dh3: &[u8; 32],
    dh4: Option<&[u8; 32]>,
) -> Result<[u8; 32]> {
    // Concatenate DH1 || DH2 || DH3 || DH4 (total 128 bytes)
    let mut dh_input = Vec::with_capacity(128);
    dh_input.extend_from_slice(dh1);
    dh_input.extend_from_slice(dh2);
    dh_input.extend_from_slice(dh3);
    
    if let Some(dh4_bytes) = dh4 {
        dh_input.extend_from_slice(dh4_bytes);
    } else {
        // If no one-time prekey, use zeros (32 zero bytes)
        dh_input.extend_from_slice(&[0u8; 32]);
    }

    // Derive shared secret using HKDF
    let shared_secret = derive_shared_secret(&dh_input)?;

    Ok(shared_secret)
}

/// Perform ECDH key exchange
/// 
/// Returns the shared secret from ECDH(private, public)
/// 
/// Note: This function consumes the private key because EphemeralSecret
/// doesn't implement Copy.
pub fn perform_dh(private: EphemeralSecret, public: &PublicKey) -> Result<[u8; 32]> {
    // Perform ECDH using x25519
    // diffie_hellman consumes the private key
    let shared_secret = private.diffie_hellman(public);
    Ok(*shared_secret.as_bytes())
}

/// Derive shared secret using HKDF-SHA256
/// 
/// Uses HKDF with empty salt and info to derive 32-byte key
fn derive_shared_secret(ikm: &[u8]) -> Result<[u8; 32]> {
    let salt = ring::hkdf::Salt::new(ring::hkdf::HKDF_SHA256, &[]);
    
    // Extract PRK
    let prk = salt.extract(ikm);
    
    // Expand to 32 bytes
    let okm = prk.expand(&[], ring::hkdf::HKDF_SHA256)
        .map_err(|e| E2EEError::CryptoError(format!("HKDF expand failed: {}", e)))?;
    
    let mut shared_secret = [0u8; 32];
    okm.fill(&mut shared_secret)
        .map_err(|e| E2EEError::CryptoError(format!("HKDF fill failed: {}", e)))?;
    
    Ok(shared_secret)
}
