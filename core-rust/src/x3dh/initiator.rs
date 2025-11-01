use crate::error::{E2EEError, Result};
use crate::keys::{IdentityKeyPair, PreKeyBundle};
use crate::x3dh::handshake::{calculate_shared_secret_from_dh, perform_dh};
use rand::rngs::OsRng;
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Result of X3DH initiation
pub struct X3DHResult {
    /// The shared secret derived from X3DH handshake
    pub shared_secret: [u8; 32],
    /// Ephemeral public key as hex string
    pub ephemeral_public_key_hex: String,
}

/// X3DH Initiator (Alice side)
/// 
/// Handles the initiator side of the X3DH key agreement protocol.
pub struct X3DHInitiator {
    identity_pair: IdentityKeyPair,
}

impl X3DHInitiator {
    /// Create a new X3DH initiator
    pub fn new(identity_pair: IdentityKeyPair) -> Self {
        Self { identity_pair }
    }

    /// Initiate X3DH handshake with a prekey bundle
    /// 
    /// # Arguments
    /// * `bundle` - Prekey bundle from Bob containing identity, signed prekey, and optional one-time prekey
    /// 
    /// # Returns
    /// X3DHResult containing the shared secret and ephemeral public key
    pub fn initiate(&self, bundle: &PreKeyBundle) -> Result<X3DHResult> {
        // Parse Bob's identity public key from hex
        let identity_b_hex = bundle.identity_public_hex();
        let identity_b_bytes = hex::decode(identity_b_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode identity public key: {}", e)))?;
        
        if identity_b_bytes.len() != 32 {
            return Err(E2EEError::ProtocolError(
                format!("Invalid identity public key length: expected 32, got {}", identity_b_bytes.len())
            ));
        }
        
        let mut identity_b_pub_bytes = [0u8; 32];
        identity_b_pub_bytes.copy_from_slice(&identity_b_bytes);
        let identity_b_public = PublicKey::from(identity_b_pub_bytes);
        
        // Parse signed prekey public key
        let signed_prekey = bundle.signed_prekey();
        let signed_prekey_public = signed_prekey.public_key();
        
        // Parse one-time prekey public key (if available)
        let one_time_prekey_public = bundle.one_time_prekey()
            .map(|otp| otp.public_key());
        
        // Generate ephemeral key (EK)
        let ephemeral_private = EphemeralSecret::random_from_rng(OsRng);
        let ephemeral_public = PublicKey::from(&ephemeral_private);
        let ephemeral_public_hex = hex::encode(ephemeral_public.as_bytes());
        
        // Calculate DH1 = ECDH(IKA, SPKB)
        // Get identity private key as EphemeralSecret (can be used multiple times)
        let identity_a_private = self.identity_pair.private_key_as_ephemeral();
        let dh1 = perform_dh(identity_a_private, &signed_prekey_public)?;
        
        // Calculate DH2 = ECDH(EK, IKB)
        // We need to clone ephemeral_private for multiple uses
        // Since EphemeralSecret doesn't implement Clone, we need to extract bytes first
        let ephemeral_private_bytes = unsafe {
            std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(&ephemeral_private)
        };
        
        // Create new EphemeralSecret for DH2
        let ephemeral_private_for_dh2 = unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(ephemeral_private_bytes)
        };
        let dh2 = perform_dh(ephemeral_private_for_dh2, &identity_b_public)?;
        
        // Calculate DH3 = ECDH(EK, SPKB)
        let ephemeral_private_for_dh3 = unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(ephemeral_private_bytes)
        };
        let dh3 = perform_dh(ephemeral_private_for_dh3, &signed_prekey_public)?;
        
        // Calculate DH4 = ECDH(EK, OPKB) if available
        let dh4 = if let Some(opkb) = one_time_prekey_public.as_ref() {
            let ephemeral_private_for_dh4 = unsafe {
                std::mem::transmute::<[u8; 32], EphemeralSecret>(ephemeral_private_bytes)
            };
            Some(perform_dh(ephemeral_private_for_dh4, opkb)?)
        } else {
            None
        };
        
        // Calculate shared secret from DH values
        let shared_secret = calculate_shared_secret_from_dh(
            &dh1,
            &dh2,
            &dh3,
            dh4.as_ref(),
        )?;
        
        Ok(X3DHResult {
            shared_secret,
            ephemeral_public_key_hex: ephemeral_public_hex,
        })
    }
}
