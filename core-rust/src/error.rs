//! Error types for E2EE core library

use thiserror::Error;

/// Errors that can occur in E2EE operations
#[derive(Error, Debug)]
pub enum E2EEError {
    #[error("Cryptographic error: {0}")]
    Crypto(String),

    #[error("Key error: {0}")]
    Key(String),

    #[error("Serialization error: {0}")]
    Serialization(String),

    #[error("Invalid input: {0}")]
    InvalidInput(String),

    #[error("Internal error: {0}")]
    Internal(String),
}

pub type Result<T> = std::result::Result<T, E2EEError>;

