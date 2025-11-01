use crate::error::{E2EEError, Result};
use crate::keys::{IdentityKeyPair, SignedPreKeyPair};
use crate::x3dh::handshake::{calculate_shared_secret_from_dh, perform_dh};
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Result of X3DH response
pub struct X3DHResponseResult {
    /// The shared secret derived from X3DH handshake
    pub shared_secret: [u8; 32],
}

/// X3DH Responder (Bob side)
/// 
/// Handles the responder side of the X3DH key agreement protocol.
pub struct X3DHResponder {
    identity_pair: IdentityKeyPair,
    signed_prekey_pair: SignedPreKeyPair,
    one_time_prekey_private: Option<EphemeralSecret>,
    one_time_prekey_public: Option<PublicKey>,
    one_time_prekey_id: Option<u32>,
}

impl X3DHResponder {
    /// Create a new X3DH responder
    /// 
    /// # Arguments
    /// * `identity_pair` - Bob's identity key pair
    /// * `signed_prekey_pair` - Bob's signed prekey pair
    pub fn new(identity_pair: IdentityKeyPair, signed_prekey_pair: SignedPreKeyPair) -> Self {
        Self {
            identity_pair,
            signed_prekey_pair,
            one_time_prekey_private: None,
            one_time_prekey_public: None,
            one_time_prekey_id: None,
        }
    }

    /// Set the one-time prekey for this responder
    /// 
    /// # Arguments
    /// * `key_id` - One-time prekey ID
    /// * `private_key` - One-time prekey private key
    /// * `public_key` - One-time prekey public key
    pub fn set_one_time_prekey(&mut self, key_id: u32, private_key: EphemeralSecret, public_key: PublicKey) {
        self.one_time_prekey_private = Some(private_key);
        self.one_time_prekey_public = Some(public_key);
        self.one_time_prekey_id = Some(key_id);
    }

    /// Respond to X3DH handshake initiation
    /// 
    /// # Arguments
    /// * `identity_a_hex` - Alice's identity public key as hex string
    /// * `ephemeral_public_key_hex` - Alice's ephemeral public key as hex string
    /// 
    /// # Returns
    /// X3DHResponseResult containing the shared secret
    pub fn respond(&self, identity_a_hex: &str, ephemeral_public_key_hex: &str) -> Result<X3DHResponseResult> {
        // Parse Alice's identity public key from hex
        let identity_a_bytes = hex::decode(identity_a_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode identity public key: {}", e)))?;
        
        if identity_a_bytes.len() != 32 {
            return Err(E2EEError::ProtocolError(
                format!("Invalid identity public key length: expected 32, got {}", identity_a_bytes.len())
            ));
        }
        
        let mut identity_a_pub_bytes = [0u8; 32];
        identity_a_pub_bytes.copy_from_slice(&identity_a_bytes);
        let identity_a_public = PublicKey::from(identity_a_pub_bytes);
        
        // Parse Alice's ephemeral public key from hex
        let ephemeral_bytes = hex::decode(ephemeral_public_key_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode ephemeral public key: {}", e)))?;
        
        if ephemeral_bytes.len() != 32 {
            return Err(E2EEError::ProtocolError(
                format!("Invalid ephemeral public key length: expected 32, got {}", ephemeral_bytes.len())
            ));
        }
        
        let mut ephemeral_pub_bytes = [0u8; 32];
        ephemeral_pub_bytes.copy_from_slice(&ephemeral_bytes);
        let ephemeral_public = PublicKey::from(ephemeral_pub_bytes);
        
        // Calculate DH1 = ECDH(IKA, SPKB)
        // From initiator: DH1 = ECDH(IKA_private, SPKB_public)
        // From responder: DH1 = ECDH(SPKB_private, IKA_public)
        // These are equal due to ECDH commutativity
        let signed_prekey_b_private = self.signed_prekey_pair.private_key();
        let dh1 = perform_dh(signed_prekey_b_private, &identity_a_public)?;
        
        // Calculate DH2 = ECDH(EK, IKB)
        // From responder perspective: ECDH(IKB_private, EK_public)
        let identity_b_private_for_dh2 = self.identity_pair.private_key_as_ephemeral();
        let dh2 = perform_dh(identity_b_private_for_dh2, &ephemeral_public)?;
        
        // Calculate DH3 = ECDH(EK, SPKB)
        // From responder perspective: ECDH(SPKB_private, EK_public)
        let signed_prekey_b_private_for_dh3 = self.signed_prekey_pair.private_key();
        let dh3 = perform_dh(signed_prekey_b_private_for_dh3, &ephemeral_public)?;
        
        // Calculate DH4 = ECDH(EK, OPKB) if available
        let dh4 = if let Some(ref opk_private) = self.one_time_prekey_private {
            // From responder perspective: ECDH(OPKB_private, EK_public)
            // Note: opk_private is owned, so we need to clone it for reuse
            // But EphemeralSecret doesn't implement Clone, so we extract bytes
            let opk_private_bytes = unsafe {
                std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(opk_private)
            };
            let opk_private_for_dh4 = unsafe {
                std::mem::transmute::<[u8; 32], EphemeralSecret>(opk_private_bytes)
            };
            Some(perform_dh(opk_private_for_dh4, &ephemeral_public)?)
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
        
        Ok(X3DHResponseResult {
            shared_secret,
        })
    }
}

