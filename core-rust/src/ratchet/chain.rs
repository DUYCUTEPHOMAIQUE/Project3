use crate::error::{E2EEError, Result};

/// Chain key for Double Ratchet
/// 
/// A chain key is used to derive message keys for encryption/decryption.
/// Each time a message key is derived, the chain key is "ratcheted" forward
/// using HKDF, ensuring forward secrecy.
pub struct Chain {
    /// Current chain key (32 bytes)
    chain_key: [u8; 32],
    /// Message number in this chain
    message_number: u32,
}

impl Chain {
    /// Create a new chain from an initial chain key
    /// 
    /// # Arguments
    /// * `chain_key` - Initial 32-byte chain key
    pub fn new(chain_key: [u8; 32]) -> Self {
        Self {
            chain_key,
            message_number: 0,
        }
    }

    /// Ratchet forward to derive the next chain key and message key
    /// 
    /// This method:
    /// 1. Derives a message key from the current chain key
    /// 2. Ratchets the chain key forward using HKDF
    /// 3. Increments the message number
    /// 
    /// # Returns
    /// A tuple containing (message_key, new_chain_key)
    pub fn ratchet_forward(&mut self) -> Result<([u8; 32], [u8; 32])> {
        // Derive message key from current chain key using HKDF
        let message_key = self.derive_message_key()?;
        
        // Ratchet chain key forward using HKDF
        let new_chain_key = self.derive_next_chain_key()?;
        self.chain_key = new_chain_key;
        self.message_number += 1;
        
        Ok((message_key, self.chain_key))
    }

    /// Derive message key from current chain key
    /// 
    /// Uses HKDF-SHA256 with label "message_key" to derive 32-byte message key
    fn derive_message_key(&self) -> Result<[u8; 32]> {
        self.hkdf_derive(&self.chain_key, b"message_key")
    }

    /// Derive next chain key from current chain key
    /// 
    /// Uses HKDF-SHA256 with label "chain_key" to derive next 32-byte chain key
    fn derive_next_chain_key(&self) -> Result<[u8; 32]> {
        self.hkdf_derive(&self.chain_key, b"chain_key")
    }

    /// HKDF derivation helper
    /// 
    /// Derives 32-byte key using HKDF-SHA256
    fn hkdf_derive(&self, ikm: &[u8], info: &[u8]) -> Result<[u8; 32]> {
        let salt = ring::hkdf::Salt::new(ring::hkdf::HKDF_SHA256, &[]);
        
        // Extract PRK
        let prk = salt.extract(ikm);
        
        // Expand to 32 bytes with info
        // Create array reference to avoid temporary value issue
        let info_array = [info];
        let okm = prk.expand(&info_array, ring::hkdf::HKDF_SHA256)
            .map_err(|e| E2EEError::CryptoError(format!("HKDF expand failed: {}", e)))?;
        
        let mut output = [0u8; 32];
        okm.fill(&mut output)
            .map_err(|e| E2EEError::CryptoError(format!("HKDF fill failed: {}", e)))?;
        
        Ok(output)
    }

    /// Get current message number
    pub fn message_number(&self) -> u32 {
        self.message_number
    }

    /// Get current chain key (for testing/debugging)
    #[allow(dead_code)]
    pub(crate) fn chain_key(&self) -> &[u8; 32] {
        &self.chain_key
    }
}

