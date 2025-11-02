mod frb_generated; /* AUTO INJECTED BY flutter_rust_bridge. This line may not be accurate, and you can change it according to your needs. */
pub mod error;
pub mod keys;
pub mod message;
pub mod ratchet;
pub mod x3dh;
pub mod ffi;

pub use error::{E2EEError, Result};
pub use keys::IdentityKeyPair;
pub use message::{MessageEnvelope, MessageHeader, MessageType};
pub use ratchet::DoubleRatchet;
pub use x3dh::{X3DHInitiator, X3DHResult, X3DHResponder, X3DHResponseResult};

// Flutter Rust Bridge entry point
#[cfg(target_os = "android")]
#[flutter_rust_bridge::frb]
pub fn init_frb() {
    // Initialize Flutter Rust Bridge for Android
}

#[cfg(target_os = "ios")]
#[flutter_rust_bridge::frb]
pub fn init_frb() {
    // Initialize Flutter Rust Bridge for iOS
}

#[cfg(any(target_os = "linux", target_os = "macos", target_os = "windows"))]
#[flutter_rust_bridge::frb]
pub fn init_frb() {
    // Initialize Flutter Rust Bridge for Desktop
}

