use crate::error::{E2EEError, Result};
use crate::keys::{IdentityKeyPair, PreKeyBundle};
use crate::keys::prekey::{SignedPreKey, OneTimePreKey};
use serde::{Deserialize, Serialize};

/// Identity key pair bytes for FFI
/// 
/// Contains the serialized identity key pair (X25519 + Ed25519 private keys).
/// The private keys are stored as raw bytes for serialization.
/// 
/// For Flutter side: store these bytes securely (e.g., secure storage).
/// These bytes should never be exposed publicly.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdentityKeyPairBytes {
    /// X25519 private key bytes (32 bytes)
    pub x25519_private_key: Vec<u8>,
    /// X25519 public key bytes (32 bytes)
    pub x25519_public_key: Vec<u8>,
    /// Ed25519 private key bytes (32 bytes)
    pub ed25519_private_key: Vec<u8>,
    /// Ed25519 public key bytes (32 bytes)
    pub ed25519_public_key: Vec<u8>,
}

impl IdentityKeyPairBytes {
    /// Create from IdentityKeyPair
    pub fn from_identity_key_pair(identity: &IdentityKeyPair) -> Self {
        let x25519_private = identity.private_key_bytes();
        let x25519_public = identity.public_key_bytes();
        
        let ed25519_signing_key = identity.signing_key();
        let ed25519_private = ed25519_signing_key.to_bytes();
        let ed25519_verifying_key = identity.verifying_key();
        let ed25519_public = ed25519_verifying_key.to_bytes();
        
        Self {
            x25519_private_key: x25519_private.to_vec(),
            x25519_public_key: x25519_public.to_vec(),
            ed25519_private_key: ed25519_private.to_vec(),
            ed25519_public_key: ed25519_public.to_vec(),
        }
    }

    /// Convert to IdentityKeyPair
    /// 
    /// Note: This reconstructs the keys from bytes. Use with caution.
    pub fn to_identity_key_pair(&self) -> Result<IdentityKeyPair> {
        use x25519_dalek::{EphemeralSecret, PublicKey};
        use ed25519_dalek::{SigningKey, SecretKey};
        
        // Validate key lengths
        if self.x25519_private_key.len() != 32 || self.x25519_public_key.len() != 32 {
            return Err(E2EEError::SerializationError(
                "Invalid X25519 key length".to_string()
            ));
        }
        
        if self.ed25519_private_key.len() != 32 || self.ed25519_public_key.len() != 32 {
            return Err(E2EEError::SerializationError(
                "Invalid Ed25519 key length".to_string()
            ));
        }
        
        // Reconstruct X25519 keys
        let mut x25519_private_bytes = [0u8; 32];
        x25519_private_bytes.copy_from_slice(&self.x25519_private_key);
        let x25519_private = unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(x25519_private_bytes)
        };
        let x25519_public = PublicKey::from(&x25519_private);
        
        // Validate public key matches
        let mut x25519_public_bytes = [0u8; 32];
        x25519_public_bytes.copy_from_slice(&self.x25519_public_key);
        if x25519_public_bytes != *x25519_public.as_bytes() {
            return Err(E2EEError::SerializationError(
                "X25519 public key mismatch".to_string()
            ));
        }
        
        // Reconstruct Ed25519 keys
        let mut ed25519_private_bytes = [0u8; 32];
        ed25519_private_bytes.copy_from_slice(&self.ed25519_private_key);
        let ed25519_secret_key: SecretKey = ed25519_private_bytes.into();
        let ed25519_signing_key = SigningKey::from_bytes(&ed25519_secret_key);
        let ed25519_verifying_key = ed25519_signing_key.verifying_key();
        
        // Validate public key matches
        let mut ed25519_public_bytes = [0u8; 32];
        ed25519_public_bytes.copy_from_slice(&self.ed25519_public_key);
        if ed25519_public_bytes != ed25519_verifying_key.to_bytes() {
            return Err(E2EEError::SerializationError(
                "Ed25519 public key mismatch".to_string()
            ));
        }
        
        // Reconstruct IdentityKeyPair using from_bytes helper
        IdentityKeyPair::from_bytes(
            x25519_private_bytes,
            x25519_public_bytes,
            ed25519_private_bytes,
            ed25519_public_bytes,
        )
    }
}

/// PreKeyBundle JSON representation for FFI
/// 
/// Contains the prekey bundle data in a JSON-serializable format.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreKeyBundleJSON {
    /// Identity public key (X25519) as hex string
    pub identity_public_hex: String,
    /// Identity Ed25519 verifying key as hex string (for signature verification)
    pub identity_ed25519_verifying_key_hex: String,
    /// Signed prekey data
    pub signed_prekey: SignedPreKeyJSON,
    /// One-time prekey data (optional)
    pub one_time_prekey: Option<OneTimePreKeyJSON>,
}

/// Signed prekey JSON representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedPreKeyJSON {
    /// Public key as hex string
    pub public_key_hex: String,
    /// Signature as hex string
    pub signature_hex: String,
    /// Key ID
    pub key_id: u32,
}

/// One-time prekey JSON representation
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OneTimePreKeyJSON {
    /// Public key as hex string
    pub public_key_hex: String,
    /// Key ID
    pub key_id: u32,
}

impl PreKeyBundleJSON {
    /// Create from PreKeyBundle
    pub fn from_prekey_bundle(bundle: &PreKeyBundle) -> Self {
        let signed_prekey = bundle.signed_prekey();
        let one_time_prekey = bundle.one_time_prekey().map(|otp| OneTimePreKeyJSON {
            public_key_hex: otp.public_key_hex(),
            key_id: otp.key_id(),
        });
        
        Self {
            identity_public_hex: bundle.identity_public_hex().to_string(),
            identity_ed25519_verifying_key_hex: hex::encode(bundle.identity_ed25519_verifying_key().to_bytes()),
            signed_prekey: SignedPreKeyJSON {
                public_key_hex: signed_prekey.public_key_hex(),
                signature_hex: hex::encode(signed_prekey.signature().to_bytes()),
                key_id: signed_prekey.key_id(),
            },
            one_time_prekey,
        }
    }

    /// Convert to PreKeyBundle
    /// 
    /// This is used when the responder receives the bundle and needs to convert it back.
    /// Note: The responder already has the keys, so this is mainly for validation.
    pub fn to_prekey_bundle(&self) -> Result<PreKeyBundle> {
        use x25519_dalek::PublicKey;
        use ed25519_dalek::{Signature, VerifyingKey};
        
        // Parse identity public key
        let identity_bytes = hex::decode(&self.identity_public_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode identity key: {}", e)))?;
        
        if identity_bytes.len() != 32 {
            return Err(E2EEError::SerializationError(
                "Invalid identity key length".to_string()
            ));
        }
        
        let mut identity_pub_bytes = [0u8; 32];
        identity_pub_bytes.copy_from_slice(&identity_bytes);
        let _identity_public = PublicKey::from(identity_pub_bytes);
        
        // Parse Ed25519 verifying key
        let ed25519_verifying_key_bytes = hex::decode(&self.identity_ed25519_verifying_key_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode Ed25519 verifying key: {}", e)))?;
        
        if ed25519_verifying_key_bytes.len() != 32 {
            return Err(E2EEError::SerializationError(
                "Invalid Ed25519 verifying key length".to_string()
            ));
        }
        
        let mut ed25519_verifying_key_bytes_array = [0u8; 32];
        ed25519_verifying_key_bytes_array.copy_from_slice(&ed25519_verifying_key_bytes);
        let ed25519_verifying_key = VerifyingKey::from_bytes(&ed25519_verifying_key_bytes_array)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to parse Ed25519 verifying key: {}", e)))?;
        
        // Parse signed prekey
        let signed_prekey_bytes = hex::decode(&self.signed_prekey.public_key_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode signed prekey: {}", e)))?;
        
        if signed_prekey_bytes.len() != 32 {
            return Err(E2EEError::SerializationError(
                "Invalid signed prekey length".to_string()
            ));
        }
        
        let mut signed_prekey_pub_bytes = [0u8; 32];
        signed_prekey_pub_bytes.copy_from_slice(&signed_prekey_bytes);
        let signed_prekey_public = PublicKey::from(signed_prekey_pub_bytes);
        
        // Parse signature
        let signature_bytes = hex::decode(&self.signed_prekey.signature_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode signature: {}", e)))?;
        
        if signature_bytes.len() != 64 {
            return Err(E2EEError::SerializationError(
                "Invalid signature length".to_string()
            ));
        }
        
        let mut sig_bytes = [0u8; 64];
        sig_bytes.copy_from_slice(&signature_bytes);
        let signature = Signature::from_bytes(&sig_bytes);
        
        // Create signed prekey using from_components
        let signed_prekey = SignedPreKey::from_components(
            signed_prekey_public,
            signature,
            self.signed_prekey.key_id,
        );
        
        // Parse one-time prekey if present
        let one_time_prekey = self.one_time_prekey.as_ref().map(|otp| {
            let otp_bytes = hex::decode(&otp.public_key_hex)
                .expect("Failed to decode one-time prekey");
            let mut otp_pub_bytes = [0u8; 32];
            otp_pub_bytes.copy_from_slice(&otp_bytes);
            let otp_public = PublicKey::from(otp_pub_bytes);
            
            OneTimePreKey::from_components(otp_public, otp.key_id)
        });
        
        // Create PreKeyBundle
        Ok(PreKeyBundle::new(
            self.identity_public_hex.clone(),
            ed25519_verifying_key,
            signed_prekey,
            one_time_prekey,
        ))
    }
}

// Helper functions for FFI

/// Get public key hex from IdentityKeyPairBytes
pub fn get_public_key_hex(identity_bytes: &IdentityKeyPairBytes) -> String {
    hex::encode(&identity_bytes.x25519_public_key)
}

