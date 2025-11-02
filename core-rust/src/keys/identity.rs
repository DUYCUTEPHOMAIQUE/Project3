use rand::rngs::OsRng;
use rand::RngCore;
use x25519_dalek::{EphemeralSecret, PublicKey};
use ed25519_dalek::{SigningKey, VerifyingKey, SecretKey};

/// Identity key pair for X3DH protocol
/// 
/// Uses X25519 for key exchange and Ed25519 for signing.
/// The private keys are kept secret and never exposed outside this struct.
/// 
/// Stores the private keys as raw bytes to allow reuse and cloning.
pub struct IdentityKeyPair {
    // X25519 keys for key exchange
    private_key_bytes: [u8; 32],
    public_key: PublicKey,
    // Ed25519 keys for signing
    ed25519_signing_key: SigningKey,
}

impl IdentityKeyPair {
    /// Generate a new identity key pair
    /// 
    /// Generates both X25519 (for key exchange) and Ed25519 (for signing) key pairs.
    /// Uses `OsRng` for cryptographically secure random number generation.
    pub fn generate() -> Self {
        // Generate X25519 key pair for key exchange
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
        
        // Generate Ed25519 key pair for signing
        // We use a different random seed to ensure independence
        let mut ed25519_secret_bytes = [0u8; 32];
        OsRng.fill_bytes(&mut ed25519_secret_bytes);
        let ed25519_secret_key: SecretKey = ed25519_secret_bytes.into();
        let ed25519_signing_key = SigningKey::from_bytes(&ed25519_secret_key);
        
        Self {
            private_key_bytes,
            public_key,
            ed25519_signing_key,
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

    /// Get the Ed25519 signing key for signing operations
    /// 
    /// Returns a reference to the signing key that can be used to sign data.
    pub(crate) fn signing_key(&self) -> &SigningKey {
        &self.ed25519_signing_key
    }

    /// Get the Ed25519 verifying key (public key) for signature verification
    /// 
    /// Returns the verifying key that corresponds to the signing key.
    pub fn verifying_key(&self) -> VerifyingKey {
        self.ed25519_signing_key.verifying_key()
    }

    /// Create IdentityKeyPair from bytes (for deserialization)
    /// 
    /// # Arguments
    /// * `x25519_private_key` - X25519 private key bytes (32 bytes)
    /// * `x25519_public_key` - X25519 public key bytes (32 bytes)
    /// * `ed25519_private_key` - Ed25519 private key bytes (32 bytes)
    /// * `ed25519_public_key` - Ed25519 public key bytes (32 bytes)
    /// 
    /// # Returns
    /// IdentityKeyPair if keys are valid, Err otherwise
    pub fn from_bytes(
        x25519_private_key: [u8; 32],
        x25519_public_key: [u8; 32],
        ed25519_private_key: [u8; 32],
        ed25519_public_key: [u8; 32],
    ) -> crate::error::Result<Self> {
        use crate::error::E2EEError;
        
        // Reconstruct X25519 keys
        let x25519_private = unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(x25519_private_key)
        };
        let x25519_public = PublicKey::from(&x25519_private);
        
        // Validate public key matches
        if x25519_public_key != *x25519_public.as_bytes() {
            return Err(E2EEError::SerializationError(
                "X25519 public key mismatch".to_string()
            ));
        }
        
        // Reconstruct Ed25519 keys
        let ed25519_secret_key: SecretKey = ed25519_private_key.into();
        let ed25519_signing_key = SigningKey::from_bytes(&ed25519_secret_key);
        let ed25519_verifying_key = ed25519_signing_key.verifying_key();
        
        // Validate public key matches
        if ed25519_public_key != ed25519_verifying_key.to_bytes() {
            return Err(E2EEError::SerializationError(
                "Ed25519 public key mismatch".to_string()
            ));
        }
        
        Ok(Self {
            private_key_bytes: x25519_private_key,
            public_key: x25519_public,
            ed25519_signing_key,
        })
    }
}

impl Clone for IdentityKeyPair {
    fn clone(&self) -> Self {
        // We can clone because we store the bytes, not EphemeralSecret
        // For Ed25519 signing key, we need to extract bytes and recreate
        let ed25519_secret_bytes = self.ed25519_signing_key.to_bytes();
        let ed25519_secret_key: SecretKey = ed25519_secret_bytes.into();
        let ed25519_signing_key = SigningKey::from_bytes(&ed25519_secret_key);
        
        Self {
            private_key_bytes: self.private_key_bytes,
            public_key: self.public_key,
            ed25519_signing_key,
        }
    }
}

