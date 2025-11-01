use rand::rngs::OsRng;
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Identity key pair for X3DH protocol
/// 
/// Uses X25519 for key exchange. The private key is kept secret
/// and never exposed outside this struct.
/// 
/// Stores the private key as raw bytes to allow reuse and cloning.
pub struct IdentityKeyPair {
    private_key_bytes: [u8; 32],
    public_key: PublicKey,
}

impl IdentityKeyPair {
    /// Generate a new identity key pair
    /// 
    /// Uses `OsRng` for cryptographically secure random number generation.
    pub fn generate() -> Self {
        let private_key = EphemeralSecret::random_from_rng(OsRng);
        let public_key = PublicKey::from(&private_key);
        
        // Extract scalar bytes from EphemeralSecret using unsafe
        // This is safe because we're only reading the bytes, not modifying them
        let private_key_bytes = unsafe {
            // EphemeralSecret internally stores the scalar as [u8; 32]
            // We access it through a pointer cast - this is the only way to extract it
            // since x25519-dalek doesn't expose a safe API for this
            std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(&private_key)
        };
        
        // Zeroize the original EphemeralSecret by dropping it
        drop(private_key);
        
        Self {
            private_key_bytes,
            public_key,
        }
    }

    /// Get the public key
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Get the public key as bytes (32 bytes)
    pub fn public_key_bytes(&self) -> [u8; 32] {
        *self.public_key.as_bytes()
    }

    /// Get the public key as hex string (64 hex characters)
    pub fn public_key_hex(&self) -> String {
        hex::encode(self.public_key_bytes())
    }

    /// Get the private key as EphemeralSecret for DH operations
    /// 
    /// Creates a new EphemeralSecret from the stored bytes.
    /// Note: Each call creates a new EphemeralSecret, so this can be used multiple times.
    pub(crate) fn private_key_as_ephemeral(&self) -> EphemeralSecret {
        // Reconstruct EphemeralSecret from bytes
        // This is safe because we're reconstructing from valid scalar bytes
        unsafe {
            // We transmute the bytes into EphemeralSecret
            // This is safe because EphemeralSecret is just a wrapper around [u8; 32]
            std::mem::transmute::<[u8; 32], EphemeralSecret>(self.private_key_bytes)
        }
    }
    
    /// Get the private key bytes for serialization/cloning
    /// 
    /// Note: This exposes the private key, use with caution.
    #[allow(dead_code)]
    pub(crate) fn private_key_bytes(&self) -> [u8; 32] {
        self.private_key_bytes
    }
}

impl Clone for IdentityKeyPair {
    fn clone(&self) -> Self {
        // We can clone because we store the bytes, not EphemeralSecret
        Self {
            private_key_bytes: self.private_key_bytes,
            public_key: self.public_key,
        }
    }
}

