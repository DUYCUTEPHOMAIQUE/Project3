use crate::error::{E2EEError, Result};
use crate::ratchet::DoubleRatchet;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

/// Session ID type (UUID)
pub type SessionId = String;

/// Session containing DoubleRatchet state
/// 
/// Wraps DoubleRatchet and provides thread-safe access through Arc<Mutex<>>.
pub struct Session {
    /// Double Ratchet instance for encryption/decryption
    pub double_ratchet: Arc<Mutex<DoubleRatchet>>,
    /// Session ID
    pub id: SessionId,
}

impl Session {
    /// Create a new session from a shared secret
    /// 
    /// # Arguments
    /// * `shared_secret` - 32-byte shared secret from X3DH handshake
    /// * `is_initiator` - true if this is the X3DH initiator (Alice), false if responder (Bob)
    /// * `session_id` - Session ID (UUID string)
    /// 
    /// # Returns
    /// New Session instance
    pub fn from_shared_secret(
        shared_secret: [u8; 32],
        is_initiator: bool,
        session_id: SessionId,
    ) -> Result<Self> {
        let double_ratchet = DoubleRatchet::from_shared_secret(&shared_secret, is_initiator)?;
        
        Ok(Self {
            double_ratchet: Arc::new(Mutex::new(double_ratchet)),
            id: session_id,
        })
    }

    /// Get the session ID
    pub fn id(&self) -> &SessionId {
        &self.id
    }

    /// Encrypt a message using this session's Double Ratchet
    /// 
    /// # Arguments
    /// * `plaintext` - Plaintext message to encrypt
    /// 
    /// # Returns
    /// MessageEnvelope containing encrypted message and metadata
    pub fn encrypt(&self, plaintext: &[u8]) -> Result<crate::message::MessageEnvelope> {
        let mut dr = self.double_ratchet
            .lock()
            .map_err(|e| E2EEError::StateError(format!("Failed to lock DoubleRatchet: {}", e)))?;
        
        dr.encrypt_envelope(plaintext)
    }

    /// Decrypt a message using this session's Double Ratchet
    /// 
    /// # Arguments
    /// * `envelope` - MessageEnvelope containing encrypted message
    /// 
    /// # Returns
    /// Decrypted plaintext message
    pub fn decrypt(&self, envelope: &crate::message::MessageEnvelope) -> Result<Vec<u8>> {
        let mut dr = self.double_ratchet
            .lock()
            .map_err(|e| E2EEError::StateError(format!("Failed to lock DoubleRatchet: {}", e)))?;
        
        dr.decrypt_envelope(envelope)
    }
}

/// Thread-safe registry for managing multiple sessions
/// 
/// Uses Arc<Mutex<>> for thread-safe access to the session map.
pub struct SessionRegistry {
    sessions: Arc<Mutex<HashMap<SessionId, Arc<Session>>>>,
}

impl SessionRegistry {
    /// Create a new session registry
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Register a new session
    /// 
    /// # Arguments
    /// * `session_id` - Session ID
    /// * `session` - Session instance
    pub fn register(&self, session_id: SessionId, session: Arc<Session>) {
        let mut sessions = self.sessions
            .lock()
            .expect("Failed to lock session registry");
        sessions.insert(session_id, session);
    }

    /// Get a session by ID
    /// 
    /// # Arguments
    /// * `session_id` - Session ID
    /// 
    /// # Returns
    /// Some(Arc<Session>) if found, None otherwise
    pub fn get(&self, session_id: &SessionId) -> Option<Arc<Session>> {
        let sessions = self.sessions
            .lock()
            .expect("Failed to lock session registry");
        sessions.get(session_id).map(|s| Arc::clone(s))
    }

    /// Remove a session by ID
    /// 
    /// # Arguments
    /// * `session_id` - Session ID
    pub fn remove(&self, session_id: &SessionId) {
        let mut sessions = self.sessions
            .lock()
            .expect("Failed to lock session registry");
        sessions.remove(session_id);
    }

    /// Check if a session exists
    /// 
    /// # Arguments
    /// * `session_id` - Session ID
    /// 
    /// # Returns
    /// true if session exists, false otherwise
    pub fn contains(&self, session_id: &SessionId) -> bool {
        let sessions = self.sessions
            .lock()
            .expect("Failed to lock session registry");
        sessions.contains_key(session_id)
    }
}

impl Default for SessionRegistry {
    fn default() -> Self {
        Self::new()
    }
}

/// Generate a new session ID (UUID string)
pub fn generate_session_id() -> SessionId {
    Uuid::new_v4().to_string()
}

