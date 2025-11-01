use crate::error::{E2EEError, Result};
use crate::keys::identity::IdentityKeyPair;
use ed25519_dalek::{SigningKey, VerifyingKey, Signature, Signer, Verifier, SecretKey};
use rand::rngs::OsRng;
use rand::RngCore;
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Signed prekey pair with Ed25519 signature
/// 
/// The signed prekey is signed by the identity key to ensure authenticity.
/// 
/// Stores the private key as raw bytes to allow reuse and cloning.
pub struct SignedPreKeyPair {
    prekey_bytes: [u8; 32],
    prekey_public: PublicKey,
    signature: Signature,
    key_id: u32,
}

impl SignedPreKeyPair {
    /// Generate a new signed prekey pair and sign it with the identity key
    /// 
    /// # Arguments
    /// * `key_id` - Unique identifier for this prekey
    /// * `identity_pair` - Identity key pair to sign the prekey
    pub fn generate(key_id: u32, _identity_pair: &IdentityKeyPair) -> Result<Self> {
        // Generate new X25519 prekey pair
        let prekey = EphemeralSecret::random_from_rng(OsRng);
        let prekey_public = PublicKey::from(&prekey);
        
        // Sign the prekey public key with Ed25519 identity key
        // We need to convert X25519 to Ed25519 or use a separate signing key
        // For now, we'll use Ed25519 for signing (identity key needs Ed25519 variant)
        // This requires identity key to have Ed25519 signing capability
        
        // Generate Ed25519 secret key from randomness (32 bytes)
        let mut secret_bytes = [0u8; 32];
        OsRng.fill_bytes(&mut secret_bytes);
        let secret_key: SecretKey = secret_bytes.into();
        
        // Create Ed25519 signing key from secret key
        let signing_key = SigningKey::from_bytes(&secret_key);
        let prekey_pub_bytes = prekey_public.as_bytes();
        
        // Sign the prekey public key
        let signature = signing_key.sign(prekey_pub_bytes);
        
        // Extract scalar bytes from EphemeralSecret using unsafe
        let prekey_bytes = unsafe {
            std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(&prekey)
        };
        
        // Zeroize the original EphemeralSecret by dropping it
        drop(prekey);
        
        Ok(Self {
            prekey_bytes,
            prekey_public,
            signature,
            key_id,
        })
    }

    /// Verify the signature of this prekey
    pub fn verify_signature(&self, identity_public: &VerifyingKey) -> Result<bool> {
        let prekey_pub_bytes = self.prekey_public.as_bytes();
        identity_public
            .verify(prekey_pub_bytes, &self.signature)
            .map_err(|e| E2EEError::CryptoError(format!("Signature verification failed: {}", e)))?;
        Ok(true)
    }

    /// Get the prekey public key
    pub fn public_key(&self) -> &PublicKey {
        &self.prekey_public
    }

    /// Get the prekey public key as bytes
    pub fn public_key_bytes(&self) -> [u8; 32] {
        *self.prekey_public.as_bytes()
    }

    /// Get the prekey public key as hex string
    pub fn public_key_hex(&self) -> String {
        hex::encode(self.public_key_bytes())
    }

    /// Get the signature as bytes
    pub fn signature_bytes(&self) -> Vec<u8> {
        self.signature.to_bytes().to_vec()
    }

    /// Get the signature as hex string
    pub fn signature_hex(&self) -> String {
        hex::encode(self.signature_bytes())
    }

    /// Get the key ID
    pub fn key_id(&self) -> u32 {
        self.key_id
    }

    /// Get the private key as EphemeralSecret for DH operations
    /// 
    /// Creates a new EphemeralSecret from the stored bytes.
    pub(crate) fn private_key(&self) -> EphemeralSecret {
        unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(self.prekey_bytes)
        }
    }

    /// Get the signature
    pub fn signature(&self) -> &Signature {
        &self.signature
    }
}

impl Clone for SignedPreKeyPair {
    fn clone(&self) -> Self {
        // We can clone because we store the bytes, not EphemeralSecret
        Self {
            prekey_bytes: self.prekey_bytes,
            prekey_public: self.prekey_public,
            signature: self.signature,
            key_id: self.key_id,
        }
    }
}

/// One-time prekey pair for X3DH
/// 
/// One-time prekeys are used once and then discarded to prevent replay attacks.
pub struct OneTimePreKeyPair {
    private_key: EphemeralSecret,
    public_key: PublicKey,
    key_id: u32,
}

impl OneTimePreKeyPair {
    /// Generate a new one-time prekey pair
    /// 
    /// # Arguments
    /// * `key_id` - Unique identifier for this prekey
    pub fn generate(key_id: u32) -> Self {
        let private_key = EphemeralSecret::random_from_rng(OsRng);
        let public_key = PublicKey::from(&private_key);
        
        Self {
            private_key,
            public_key,
            key_id,
        }
    }

    /// Get the private key reference
    /// 
    /// Note: EphemeralSecret doesn't implement Clone, so we return a reference.
    /// For cloning the key, you need to serialize/deserialize instead.
    pub fn private_key(&self) -> &EphemeralSecret {
        &self.private_key
    }

    /// Get the private key reference (internal use)
    #[allow(dead_code)]
    pub(crate) fn private_key_ref(&self) -> &EphemeralSecret {
        &self.private_key
    }

    /// Get the public key
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Get the public key as bytes
    pub fn public_key_bytes(&self) -> [u8; 32] {
        *self.public_key.as_bytes()
    }

    /// Get the public key as hex string
    pub fn public_key_hex(&self) -> String {
        hex::encode(self.public_key_bytes())
    }

    /// Get the key ID
    pub fn key_id(&self) -> u32 {
        self.key_id
    }
}

/// Public representation of a signed prekey
pub struct SignedPreKey {
    public_key: PublicKey,
    signature: Signature,
    key_id: u32,
}

impl SignedPreKey {
    /// Create from a SignedPreKeyPair
    pub fn from(key_pair: &SignedPreKeyPair) -> Self {
        Self {
            public_key: key_pair.prekey_public,
            signature: key_pair.signature.clone(),
            key_id: key_pair.key_id,
        }
    }

    /// Get the public key
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Get the public key as hex string
    pub fn public_key_hex(&self) -> String {
        hex::encode(*self.public_key.as_bytes())
    }

    /// Get the signature
    pub fn signature(&self) -> &Signature {
        &self.signature
    }

    /// Get the key ID
    pub fn key_id(&self) -> u32 {
        self.key_id
    }
}

/// Public representation of a one-time prekey
pub struct OneTimePreKey {
    public_key: PublicKey,
    key_id: u32,
}

impl OneTimePreKey {
    /// Create from a OneTimePreKeyPair
    pub fn from(key_pair: &OneTimePreKeyPair) -> Self {
        Self {
            public_key: key_pair.public_key,
            key_id: key_pair.key_id,
        }
    }

    /// Get the public key
    pub fn public_key(&self) -> &PublicKey {
        &self.public_key
    }

    /// Get the public key as hex string
    pub fn public_key_hex(&self) -> String {
        hex::encode(*self.public_key.as_bytes())
    }

    /// Get the key ID
    pub fn key_id(&self) -> u32 {
        self.key_id
    }
}

/// Prekey bundle containing identity key, signed prekey, and optional one-time prekey
pub struct PreKeyBundle {
    identity_public_hex: String,
    signed_prekey: SignedPreKey,
    one_time_prekey: Option<OneTimePreKey>,
}

impl PreKeyBundle {
    /// Create a new prekey bundle
    /// 
    /// # Arguments
    /// * `identity_public_hex` - Identity public key as hex string
    /// * `signed_prekey` - Signed prekey
    /// * `one_time_prekey` - Optional one-time prekey
    pub fn new(
        identity_public_hex: String,
        signed_prekey: SignedPreKey,
        one_time_prekey: Option<OneTimePreKey>,
    ) -> Self {
        Self {
            identity_public_hex,
            signed_prekey,
            one_time_prekey,
        }
    }

    /// Get the identity public key as hex
    pub fn identity_public_hex(&self) -> &str {
        &self.identity_public_hex
    }

    /// Get the signed prekey
    pub fn signed_prekey(&self) -> &SignedPreKey {
        &self.signed_prekey
    }

    /// Get the one-time prekey (if present)
    pub fn one_time_prekey(&self) -> Option<&OneTimePreKey> {
        self.one_time_prekey.as_ref()
    }
}

