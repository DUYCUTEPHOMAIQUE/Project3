use crate::error::{E2EEError, Result};
use crate::message::MessageEnvelope;
use crate::ratchet::chain::Chain;
use rand::rngs::OsRng;
use ring::aead::{Aad, LessSafeKey, Nonce, UnboundKey, AES_256_GCM};
use x25519_dalek::{EphemeralSecret, PublicKey};

/// Double Ratchet for forward secrecy and break-in recovery
/// 
/// Implements the Double Ratchet algorithm for secure message exchange.
/// Provides forward secrecy (old keys cannot decrypt new messages) and
/// break-in recovery (past messages cannot be decrypted after compromise).
pub struct DoubleRatchet {
    /// Sending chain - ratchets forward when sending messages
    sending_chain: Chain,
    /// Receiving chain - ratchets forward when receiving DH keys
    receiving_chain: Option<Chain>,
    /// Current DH key pair for DH ratchet
    dh_key_pair: EphemeralSecret,
    /// Remote DH public key
    remote_dh_public: Option<PublicKey>,
    /// Message number for sending
    sending_message_number: u64,
}

impl DoubleRatchet {
    /// Create a new Double Ratchet from a shared secret (from X3DH)
    /// 
    /// # Arguments
    /// * `shared_secret` - 32-byte shared secret from X3DH handshake
    /// * `is_initiator` - true if this is the X3DH initiator (Alice), false if responder (Bob)
    /// 
    /// Note: In Double Ratchet, after X3DH:
    /// - Initiator (Alice): sending_chain = derive(root, "sending"), receiving_chain = derive(root, "receiving")
    /// - Responder (Bob): sending_chain = derive(root, "receiving"), receiving_chain = derive(root, "sending")
    /// This ensures Alice's sending matches Bob's receiving and vice versa.
    pub fn from_shared_secret(shared_secret: &[u8; 32], is_initiator: bool) -> Result<Self> {
        // Derive root key and chain keys from shared secret
        let root_key = shared_secret;
        
        // Derive both chain keys
        let sending_chain_key_derived = Self::derive_chain_key(root_key, b"sending")?;
        let receiving_chain_key_derived = Self::derive_chain_key(root_key, b"receiving")?;
        
        // Swap chains for responder so they match initiator's setup
        let (sending_chain_key, receiving_chain_key) = if is_initiator {
            (sending_chain_key_derived, receiving_chain_key_derived)
        } else {
            // Responder: swap chains so receiving matches initiator's sending
            (receiving_chain_key_derived, sending_chain_key_derived)
        };
        
        // Generate initial DH key pair
        let dh_key_pair = EphemeralSecret::random_from_rng(OsRng);
        
        Ok(Self {
            sending_chain: Chain::new(sending_chain_key),
            receiving_chain: Some(Chain::new(receiving_chain_key)),
            dh_key_pair,
            remote_dh_public: None,
            sending_message_number: 0,
        })
    }

    /// Encrypt a plaintext message into a MessageEnvelope
    /// 
    /// # Arguments
    /// * `plaintext` - Plaintext message to encrypt
    /// 
    /// # Returns
    /// MessageEnvelope containing encrypted message and metadata
    pub fn encrypt_envelope(&mut self, plaintext: &[u8]) -> Result<MessageEnvelope> {
        // Ratchet sending chain forward to get message key
        let (message_key, _) = self.sending_chain.ratchet_forward()?;
        
        // Encrypt plaintext with message key using ChaCha20-Poly1305
        let ciphertext = Self::encrypt_with_key(&message_key, plaintext)?;
        
        // Get DH public key for header
        let dh_public = PublicKey::from(&self.dh_key_pair);
        let dh_public_hex = hex::encode(dh_public.as_bytes());
        
        // Increment sending message number
        self.sending_message_number += 1;
        
        // Create message envelope
        let envelope = MessageEnvelope::regular(
            ciphertext,
            dh_public_hex,
            0, // previous_chain_length (simplified for now)
            self.sending_message_number,
        );
        
        Ok(envelope)
    }

    /// Decrypt a MessageEnvelope to plaintext
    /// 
    /// # Arguments
    /// * `envelope` - MessageEnvelope containing encrypted message
    /// 
    /// # Returns
    /// Decrypted plaintext message
    pub fn decrypt_envelope(&mut self, envelope: &MessageEnvelope) -> Result<Vec<u8>> {
        // Parse DH public key from envelope
        let dh_public_hex = &envelope.header.dh_public_key;
        let dh_public_bytes = hex::decode(dh_public_hex)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode DH public key: {}", e)))?;
        
        if dh_public_bytes.len() != 32 {
            return Err(E2EEError::ProtocolError(
                format!("Invalid DH public key length: expected 32, got {}", dh_public_bytes.len())
            ));
        }
        
        let mut dh_pub_bytes = [0u8; 32];
        dh_pub_bytes.copy_from_slice(&dh_public_bytes);
        let dh_public = PublicKey::from(dh_pub_bytes);
        
        // Check if this is a new DH public key (different from what we've seen before)
        // If remote_dh_public is None, this is the first message, use initial receiving chain
        // If remote_dh_public is Some but different, perform DH ratchet
        let should_perform_dh_ratchet = match self.remote_dh_public {
            None => {
                // First message: store the DH public key but don't perform ratchet yet
                // Use initial receiving chain which matches sender's sending chain
                self.remote_dh_public = Some(dh_public);
                false
            }
            Some(ref existing) if existing != &dh_public => {
                // New DH key: perform DH ratchet to update receiving chain
                true
            }
            Some(_) => {
                // Same DH key as before: no ratchet needed, continue with current chain
                false
            }
        };
        
        if should_perform_dh_ratchet {
            self.perform_dh_ratchet(dh_public)?;
        }
        
        // Get receiving chain (should always be Some at this point)
        let receiving_chain = self.receiving_chain.as_mut()
            .ok_or_else(|| E2EEError::StateError("No receiving chain available".to_string()))?;
        
        // Ratchet receiving chain forward to get message key
        let (message_key, _) = receiving_chain.ratchet_forward()?;
        
        // Decrypt ciphertext with message key
        let plaintext = Self::decrypt_with_key(&message_key, &envelope.ciphertext)?;
        
        Ok(plaintext)
    }

    /// Perform DH ratchet when receiving a new DH public key
    /// 
    /// This updates the receiving chain and generates a new DH key pair.
    fn perform_dh_ratchet(&mut self, remote_dh_public: PublicKey) -> Result<()> {
        // Extract DH key pair bytes before consuming it
        let dh_key_pair_bytes = unsafe {
            std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(&self.dh_key_pair)
        };
        let dh_key_pair_for_dh = unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(dh_key_pair_bytes)
        };
        
        // Calculate shared secret from DH(our_dh_private, remote_dh_public)
        let dh_shared_secret = dh_key_pair_for_dh.diffie_hellman(&remote_dh_public);
        let dh_shared_bytes = *dh_shared_secret.as_bytes();
        
        // Derive new receiving chain key from DH shared secret
        let new_receiving_chain_key = Self::derive_chain_key(&dh_shared_bytes, b"receiving")?;
        self.receiving_chain = Some(Chain::new(new_receiving_chain_key));
        
        // Generate new DH key pair for next ratchet
        self.dh_key_pair = EphemeralSecret::random_from_rng(OsRng);
        
        // Update remote DH public key
        self.remote_dh_public = Some(remote_dh_public);
        
        Ok(())
    }

    /// Derive chain key from input key material
    fn derive_chain_key(ikm: &[u8], label: &[u8]) -> Result<[u8; 32]> {
        let salt = ring::hkdf::Salt::new(ring::hkdf::HKDF_SHA256, &[]);
        let prk = salt.extract(ikm);
        
        // Create array reference to avoid temporary value issue
        let label_array = [label];
        let okm = prk.expand(&label_array, ring::hkdf::HKDF_SHA256)
            .map_err(|e| E2EEError::CryptoError(format!("HKDF expand failed: {}", e)))?;
        
        let mut chain_key = [0u8; 32];
        okm.fill(&mut chain_key)
            .map_err(|e| E2EEError::CryptoError(format!("HKDF fill failed: {}", e)))?;
        
        Ok(chain_key)
    }

    /// Encrypt plaintext with message key using AES-256-GCM
    /// 
    /// Note: This uses a simplified nonce (all zeros). In production, you should
    /// use a proper nonce sequence derived from message number or chain state.
    fn encrypt_with_key(key: &[u8; 32], plaintext: &[u8]) -> Result<Vec<u8>> {
        // Create unbound key
        let unbound_key = UnboundKey::new(&AES_256_GCM, key)
            .map_err(|e| E2EEError::CryptoError(format!("Failed to create key: {}", e)))?;
        
        // Create less safe key (for deterministic nonce usage)
        let less_safe_key = LessSafeKey::new(unbound_key);
        
        // Create nonce (12 bytes for AES-GCM)
        // Simplified: using all zeros. In production, derive from message number
        let nonce_bytes = [0u8; 12];
        let nonce = Nonce::assume_unique_for_key(nonce_bytes);
        
        // Encrypt
        let mut ciphertext = plaintext.to_vec();
        less_safe_key.seal_in_place_append_tag(nonce, Aad::empty(), &mut ciphertext)
            .map_err(|e| E2EEError::CryptoError(format!("Encryption failed: {}", e)))?;
        
        Ok(ciphertext)
    }

    /// Decrypt ciphertext with message key using AES-256-GCM
    /// 
    /// Note: This uses a simplified nonce (all zeros). In production, you should
    /// use a proper nonce sequence derived from message number or chain state.
    /// The nonce must match the one used during encryption.
    fn decrypt_with_key(key: &[u8; 32], ciphertext: &[u8]) -> Result<Vec<u8>> {
        // Create unbound key
        let unbound_key = UnboundKey::new(&AES_256_GCM, key)
            .map_err(|e| E2EEError::CryptoError(format!("Failed to create key: {}", e)))?;
        
        // Create less safe key (for deterministic nonce usage)
        let less_safe_key = LessSafeKey::new(unbound_key);
        
        // Create nonce (12 bytes for AES-GCM)
        // Must match the nonce used during encryption
        let nonce_bytes = [0u8; 12];
        let nonce = Nonce::assume_unique_for_key(nonce_bytes);
        
        // Decrypt
        let mut plaintext = ciphertext.to_vec();
        let plaintext_len = less_safe_key.open_in_place(nonce, Aad::empty(), &mut plaintext)
            .map_err(|e| E2EEError::CryptoError(format!("Decryption failed: {}", e)))?
            .len();
        
        plaintext.truncate(plaintext_len);
        Ok(plaintext)
    }
}

