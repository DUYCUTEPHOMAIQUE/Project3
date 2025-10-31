use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum MessageType {
    Initial,
    Regular,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MessageEnvelope {
    pub version: u32,
    pub message_type: MessageType,
    /// Nonce counter for AEAD (maps to ratchet counter)
    pub nonce_counter: u64,
    /// Optional DH public key for ratchet step (not used in MVP)
    pub ratchet_dh_pub: Option<[u8; 32]>,
    /// Ciphertext bytes
    pub ciphertext: Vec<u8>,
}

impl MessageEnvelope {
    pub fn initial(nonce_counter: u64, ciphertext: Vec<u8>) -> Self {
        Self {
            version: 1,
            message_type: MessageType::Initial,
            nonce_counter,
            ratchet_dh_pub: None,
            ciphertext,
        }
    }

    pub fn regular(nonce_counter: u64, ciphertext: Vec<u8>) -> Self {
        Self {
            version: 1,
            message_type: MessageType::Regular,
            nonce_counter,
            ratchet_dh_pub: None,
            ciphertext,
        }
    }

    /// Encode envelope as base64(JSON)
    pub fn to_base64(&self) -> Result<String, serde_json::Error> {
        let json = serde_json::to_vec(self)?;
        Ok(base64::encode(json))
    }

    /// Decode envelope from base64(JSON)
    pub fn from_base64(s: &str) -> Result<Self, serde_json::Error> {
        let bytes = base64::decode(s).map_err(|e| serde_json::Error::custom(e.to_string()))?;
        serde_json::from_slice(&bytes)
    }
}
