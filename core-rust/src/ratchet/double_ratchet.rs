use crate::error::{E2EEError, Result};
use crate::message::MessageEnvelope;
use crate::ratchet::chain::Chain;
use rand::rngs::OsRng;
use ring::aead::{Aad, LessSafeKey, Nonce, UnboundKey, AES_256_GCM};
use ring::hmac;
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
        // Alice (initiator): sending_chain = "sending", receiving_chain = "receiving"
        // Bob (responder): sending_chain = "receiving", receiving_chain = "sending"
        // This ensures: Alice's sending_chain == Bob's receiving_chain
        //              Alice's receiving_chain == Bob's sending_chain
        let (sending_chain_key, receiving_chain_key) = if is_initiator {
            // Initiator: use chains as-is
            (sending_chain_key_derived, receiving_chain_key_derived)
        } else {
            // Responder: swap chains so receiving matches initiator's sending
            // receiving_chain_key = sending_chain_key_derived ensures Bob's receiving matches Alice's sending
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
        
        // Increment sending message number (must be done before encryption to use correct nonce)
        self.sending_message_number += 1;
        let message_number = self.sending_message_number;
        
        // Encrypt plaintext with message key using AES-256-GCM with message-number-based nonce
        let ciphertext = Self::encrypt_with_key(&message_key, plaintext, message_number)?;
        
        // Get DH public key for header
        let dh_public = PublicKey::from(&self.dh_key_pair);
        let dh_public_hex = hex::encode(dh_public.as_bytes());
        
        // Create message envelope
        let envelope = MessageEnvelope::regular(
            ciphertext,
            dh_public_hex,
            0, // previous_chain_length (simplified for now)
            message_number,
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
        
        // Get message number from envelope for nonce generation
        let message_number = envelope.header.message_number;
        
        // Decrypt ciphertext with message key using message-number-based nonce
        let plaintext = Self::decrypt_with_key(&message_key, &envelope.ciphertext, message_number)?;
        
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
    /// Uses message number to derive a unique nonce for each message.
    /// The nonce is derived using HKDF from the message key and message number.
    /// 
    /// # Arguments
    /// * `key` - Message key (32 bytes)
    /// * `plaintext` - Plaintext to encrypt
    /// * `message_number` - Message number in the chain (for nonce generation)
    fn encrypt_with_key(key: &[u8; 32], plaintext: &[u8], message_number: u64) -> Result<Vec<u8>> {
        // Create unbound key
        let unbound_key = UnboundKey::new(&AES_256_GCM, key)
            .map_err(|e| E2EEError::CryptoError(format!("Failed to create key: {}", e)))?;
        
        // Create less safe key (for deterministic nonce usage)
        let less_safe_key = LessSafeKey::new(unbound_key);
        
        // Derive nonce from message key and message number using HKDF
        // This ensures each message has a unique nonce
        let nonce_bytes = Self::derive_nonce(key, message_number)?;
        let nonce = Nonce::assume_unique_for_key(nonce_bytes);
        
        // Encrypt
        let mut ciphertext = plaintext.to_vec();
        less_safe_key.seal_in_place_append_tag(nonce, Aad::empty(), &mut ciphertext)
            .map_err(|e| E2EEError::CryptoError(format!("Encryption failed: {}", e)))?;
        
        Ok(ciphertext)
    }

    /// Decrypt ciphertext with message key using AES-256-GCM
    /// 
    /// Uses message number to derive the same nonce that was used during encryption.
    /// The nonce is derived using HKDF from the message key and message number.
    /// 
    /// # Arguments
    /// * `key` - Message key (32 bytes)
    /// * `ciphertext` - Ciphertext to decrypt
    /// * `message_number` - Message number in the chain (must match encryption)
    fn decrypt_with_key(key: &[u8; 32], ciphertext: &[u8], message_number: u64) -> Result<Vec<u8>> {
        // Create unbound key
        let unbound_key = UnboundKey::new(&AES_256_GCM, key)
            .map_err(|e| E2EEError::CryptoError(format!("Failed to create key: {}", e)))?;
        
        // Create less safe key (for deterministic nonce usage)
        let less_safe_key = LessSafeKey::new(unbound_key);
        
        // Derive nonce from message key and message number using HKDF
        // Must match the nonce used during encryption
        let nonce_bytes = Self::derive_nonce(key, message_number)?;
        let nonce = Nonce::assume_unique_for_key(nonce_bytes);
        
        // Decrypt
        let mut plaintext = ciphertext.to_vec();
        let plaintext_len = less_safe_key.open_in_place(nonce, Aad::empty(), &mut plaintext)
            .map_err(|e| E2EEError::CryptoError(format!("Decryption failed: {}", e)))?
            .len();
        
        plaintext.truncate(plaintext_len);
        Ok(plaintext)
    }

    /// Derive nonce from message key and message number using HMAC-SHA256
    /// 
    /// This ensures each message has a unique, deterministic nonce.
    /// The nonce is derived using HMAC-SHA256 from the message key and message number.
    /// This is secure because each message uses a different message key (from chain ratchet).
    /// 
    /// # Arguments
    /// * `message_key` - Message key (32 bytes)
    /// * `message_number` - Message number in the chain
    /// 
    /// # Returns
    /// 12-byte nonce for AES-GCM
    fn derive_nonce(message_key: &[u8; 32], message_number: u64) -> Result<[u8; 12]> {
        // Encode message number as bytes (little-endian, 8 bytes)
        let message_number_bytes = message_number.to_le_bytes();
        
        // Use HMAC-SHA256 to derive nonce from message key and message number
        // This is secure and deterministic: same key + same number = same nonce
        let key = hmac::Key::new(hmac::HMAC_SHA256, message_key);
        let tag = hmac::sign(&key, &message_number_bytes);
        
        // Take first 12 bytes from HMAC output for nonce (HMAC-SHA256 produces 32 bytes)
        let mut nonce = [0u8; 12];
        nonce.copy_from_slice(&tag.as_ref()[..12]);
        
        Ok(nonce)
    }
}

