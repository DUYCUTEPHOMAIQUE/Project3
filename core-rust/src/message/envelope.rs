use crate::error::{E2EEError, Result};
use base64::{engine::general_purpose, Engine as _};
use serde::{Deserialize, Serialize};

/// Message type enumeration
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum MessageType {
    /// Regular message
    Regular,
    /// Prekey message (initial message)
    PreKey,
    /// Key exchange message
    KeyExchange,
}

/// Message header containing ratchet metadata
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MessageHeader {
    /// DH public key for DH ratchet (as hex string)
    pub dh_public_key: String,
    /// Previous chain length
    pub previous_chain_length: u32,
    /// Message number in current chain
    pub message_number: u64,
}

/// Message envelope containing encrypted message and metadata
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MessageEnvelope {
    /// Protocol version
    pub version: u32,
    /// Message type
    pub message_type: MessageType,
    /// Encrypted ciphertext
    pub ciphertext: Vec<u8>,
    /// Message header with ratchet metadata
    pub header: MessageHeader,
}

impl MessageEnvelope {
    /// Create a regular message envelope
    /// 
    /// # Arguments
    /// * `ciphertext` - Encrypted message
    /// * `dh_public_key` - DH public key (as hex string)
    /// * `previous_chain_length` - Previous chain length
    /// * `message_number` - Message number
    pub fn regular(
        ciphertext: Vec<u8>,
        dh_public_key: String,
        previous_chain_length: u32,
        message_number: u64,
    ) -> Self {
        Self {
            version: 1,
            message_type: MessageType::Regular,
            ciphertext,
            header: MessageHeader {
                dh_public_key,
                previous_chain_length,
                message_number,
            },
        }
    }

    /// Serialize envelope to base64 string
    /// 
    /// # Returns
    /// Base64-encoded JSON string
    pub fn to_base64(&self) -> Result<String> {
        let json = serde_json::to_string(self)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to serialize envelope: {}", e)))?;
        
        let b64 = general_purpose::STANDARD.encode(json.as_bytes());
        Ok(b64)
    }

    /// Deserialize envelope from base64 string
    /// 
    /// # Arguments
    /// * `b64` - Base64-encoded JSON string
    /// 
    /// # Returns
    /// Deserialized MessageEnvelope
    pub fn from_base64(b64: &str) -> Result<Self> {
        let json_bytes = general_purpose::STANDARD.decode(b64)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode base64: {}", e)))?;
        
        let json_str = std::str::from_utf8(&json_bytes)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to decode UTF-8: {}", e)))?;
        
        let envelope: MessageEnvelope = serde_json::from_str(json_str)
            .map_err(|e| E2EEError::SerializationError(format!("Failed to deserialize envelope: {}", e)))?;
        
        Ok(envelope)
    }
}

