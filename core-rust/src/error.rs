use thiserror::Error;

/// Error types for E2EE operations
#[derive(Debug, Error)]
pub enum E2EEError {
    /// Crypto operations failed
    #[error("Crypto error: {0}")]
    CryptoError(String),

    /// Key generation failed
    #[error("Key generation error: {0}")]
    KeyGenerationError(String),

    /// Serialization/deserialization failed
    #[error("Serialization error: {0}")]
    SerializationError(String),

    /// Protocol violation
    #[error("Protocol error: {0}")]
    ProtocolError(String),

    /// Invalid state
    #[error("State error: {0}")]
    StateError(String),
}

/// Result type alias for E2EE operations
pub type Result<T> = std::result::Result<T, E2EEError>;

