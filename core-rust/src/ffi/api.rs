//! FFI API for Flutter
//! 
//! This module exports high-level functions for Flutter/Dart to use the E2EE core.

use crate::ffi::keys::{IdentityKeyPairBytes, PreKeyBundleJSON, get_public_key_hex};
use crate::ffi::session::{Session, SessionRegistry, generate_session_id};
use crate::keys::{IdentityKeyPair, PreKeyBundle};
use crate::keys::prekey::{SignedPreKeyPair, OneTimePreKeyPair};
use crate::message::MessageEnvelope;
use crate::x3dh::{X3DHInitiator, X3DHResponder};
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use serde_json;

// Global session registry
static SESSION_REGISTRY: once_cell::sync::Lazy<SessionRegistry> = 
    once_cell::sync::Lazy::new(|| SessionRegistry::new());

// Persist generated prekeys so responder can reuse the exact same keys
static SIGNED_PREKEY_STORE: once_cell::sync::Lazy<Mutex<HashMap<u32, SignedPreKeyPair>>> =
    once_cell::sync::Lazy::new(|| Mutex::new(HashMap::new()));
// Store only private key bytes of one-time prekeys; reconstruct when needed
static ONE_TIME_PREKEY_STORE: once_cell::sync::Lazy<Mutex<HashMap<u32, [u8; 32]>>> =
    once_cell::sync::Lazy::new(|| Mutex::new(HashMap::new()));

/// Generate a new identity key pair
/// 
/// # Returns
/// IdentityKeyPairBytes serialized as JSON string
#[frb(sync)]
pub fn generate_identity_key_pair() -> String {
    let identity = IdentityKeyPair::generate();
    let bytes = IdentityKeyPairBytes::from_identity_key_pair(&identity);
    
    serde_json::to_string(&bytes)
        .unwrap_or_else(|e| format!("{{\"error\": \"Failed to serialize identity: {}\"}}", e))
}

/// Get public key hex from IdentityKeyPairBytes JSON
/// 
/// # Arguments
/// * `identity_bytes_json` - JSON string of IdentityKeyPairBytes
/// 
/// # Returns
/// Public key as hex string, or error message if invalid
#[frb(sync)]
pub fn get_public_key_hex_from_json(identity_bytes_json: String) -> String {
    match serde_json::from_str::<IdentityKeyPairBytes>(&identity_bytes_json) {
        Ok(bytes) => get_public_key_hex(&bytes),
        Err(e) => format!("Error: {}", e),
    }
}

/// Generate prekey bundle for a user
/// 
/// # Arguments
/// * `identity_bytes_json` - JSON string of IdentityKeyPairBytes
/// * `signed_prekey_id` - ID for the signed prekey
/// * `one_time_prekey_id` - ID for the one-time prekey (optional, use None if not needed)
/// 
/// # Returns
/// PreKeyBundleJSON serialized as JSON string
#[frb(sync)]
pub fn generate_prekey_bundle(
    identity_bytes_json: String,
    signed_prekey_id: u32,
    one_time_prekey_id: Option<u32>,
) -> String {
    // Parse identity from JSON
    let identity_bytes = match serde_json::from_str::<IdentityKeyPairBytes>(&identity_bytes_json) {
        Ok(bytes) => bytes,
        Err(e) => return format!("{{\"error\": \"Failed to parse identity: {}\"}}", e),
    };
    
    let identity = match identity_bytes.to_identity_key_pair() {
        Ok(id) => id,
        Err(e) => return format!("{{\"error\": \"Failed to create identity: {}\"}}", e),
    };
    
    // Generate signed prekey (persist for responder)
    let signed_prekey = match SignedPreKeyPair::generate(signed_prekey_id, &identity) {
        Ok(sp) => sp,
        Err(e) => return format!("{{\"error\": \"Failed to generate signed prekey: {}\"}}", e),
    };
    {
        if let Ok(mut store) = SIGNED_PREKEY_STORE.lock() {
            store.insert(signed_prekey_id, signed_prekey.clone());
        }
    }
    
    // Generate one-time prekey if requested (persist private key bytes for responder)
    let one_time_prekey = one_time_prekey_id.map(|id| {
        let otp = OneTimePreKeyPair::generate(id);
        use x25519_dalek::EphemeralSecret;
        let otp_priv = otp.private_key();
        let otp_priv_bytes = unsafe {
            std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(otp_priv)
        };
        if let Ok(mut store) = ONE_TIME_PREKEY_STORE.lock() {
            store.insert(id, otp_priv_bytes);
        }
        otp
    });
    
    // Create prekey bundle
    use crate::keys::prekey::{SignedPreKey, OneTimePreKey};
    let prekey_bundle = PreKeyBundle::new(
        identity.public_key_hex(),
        identity.verifying_key(),
        SignedPreKey::from(&signed_prekey),
        one_time_prekey.as_ref().map(|otp| OneTimePreKey::from(otp)),
    );
    
    // Convert to JSON
    let bundle_json = PreKeyBundleJSON::from_prekey_bundle(&prekey_bundle);
    
    serde_json::to_string(&bundle_json)
        .unwrap_or_else(|e| format!("{{\"error\": \"Failed to serialize bundle: {}\"}}", e))
}

/// Create a session as initiator (Alice)
/// 
/// Initiates X3DH handshake and creates DoubleRatchet session.
/// 
/// # Arguments
/// * `identity_bytes_json` - JSON string of Alice's IdentityKeyPairBytes
/// * `prekey_bundle_json` - JSON string of Bob's PreKeyBundleJSON
/// 
/// # Returns
/// Session ID (UUID string) if successful, or error message
#[frb(sync)]
pub fn create_session_initiator(
    identity_bytes_json: String,
    prekey_bundle_json: String,
) -> String {
    // Parse identity from JSON
    let identity_bytes = match serde_json::from_str::<IdentityKeyPairBytes>(&identity_bytes_json) {
        Ok(bytes) => bytes,
        Err(e) => return format!("Error: Failed to parse identity: {}", e),
    };
    
    let identity = match identity_bytes.to_identity_key_pair() {
        Ok(id) => id,
        Err(e) => return format!("Error: Failed to create identity: {}", e),
    };
    
    // Parse prekey bundle from JSON
    let bundle_json = match serde_json::from_str::<PreKeyBundleJSON>(&prekey_bundle_json) {
        Ok(b) => b,
        Err(e) => return format!("Error: Failed to parse prekey bundle: {}", e),
    };
    
    let prekey_bundle = match bundle_json.to_prekey_bundle() {
        Ok(b) => b,
        Err(e) => return format!("Error: Failed to create prekey bundle: {}", e),
    };
    
    // Verify bundle signature
    if let Err(e) = prekey_bundle.verify_signature() {
        return format!("Error: Prekey bundle signature verification failed: {}", e);
    }
    
    // Initiate X3DH handshake
    let initiator = X3DHInitiator::new(identity);
    let x3dh_result = match initiator.initiate(&prekey_bundle) {
        Ok(r) => r,
        Err(e) => return format!("Error: X3DH handshake failed: {}", e),
    };
    
    // Create session with shared secret
    let session_id = generate_session_id();
    let session = match Session::from_shared_secret(
        x3dh_result.shared_secret,
        true, // is_initiator
        session_id.clone(),
    ) {
        Ok(s) => Arc::new(s),
        Err(e) => return format!("Error: Failed to create session: {}", e),
    };
    
    // Register session
    SESSION_REGISTRY.register(session_id.clone(), session);
    
    session_id
}

/// Create a session as initiator (Alice) and return ephemeral info
/// 
/// Same as `create_session_initiator` but returns a JSON object including
/// Alice's identity public key and the ephemeral public key used in X3DH.
/// 
/// # Arguments
/// * `identity_bytes_json` - JSON string of Alice's IdentityKeyPairBytes
/// * `prekey_bundle_json` - JSON string of Bob's PreKeyBundleJSON
/// 
/// # Returns
/// JSON string: {
///   "session_id": String,
///   "alice_identity_hex": String,
///   "alice_ephemeral_public_key_hex": String
/// }
#[frb(sync)]
pub fn create_session_initiator_with_ephemeral(
    identity_bytes_json: String,
    prekey_bundle_json: String,
) -> String {
    // Parse identity from JSON
    let identity_bytes = match serde_json::from_str::<IdentityKeyPairBytes>(&identity_bytes_json) {
        Ok(bytes) => bytes,
        Err(e) => return format!("Error: Failed to parse identity: {}", e),
    };
    
    let identity = match identity_bytes.to_identity_key_pair() {
        Ok(id) => id,
        Err(e) => return format!("Error: Failed to create identity: {}", e),
    };
    
    // Parse prekey bundle from JSON
    let bundle_json = match serde_json::from_str::<PreKeyBundleJSON>(&prekey_bundle_json) {
        Ok(b) => b,
        Err(e) => return format!("Error: Failed to parse prekey bundle: {}", e),
    };
    
    let prekey_bundle = match bundle_json.to_prekey_bundle() {
        Ok(b) => b,
        Err(e) => return format!("Error: Failed to create prekey bundle: {}", e),
    };
    
    // Verify bundle signature
    if let Err(e) = prekey_bundle.verify_signature() {
        return format!("Error: Prekey bundle signature verification failed: {}", e);
    }
    
    // Initiate X3DH handshake
    let initiator = X3DHInitiator::new(identity.clone());
    let x3dh_result = match initiator.initiate(&prekey_bundle) {
        Ok(r) => r,
        Err(e) => return format!("Error: X3DH handshake failed: {}", e),
    };
    
    // Create session with shared secret
    let session_id = generate_session_id();
    let session = match Session::from_shared_secret(
        x3dh_result.shared_secret,
        true, // is_initiator
        session_id.clone(),
    ) {
        Ok(s) => Arc::new(s),
        Err(e) => return format!("Error: Failed to create session: {}", e),
    };
    
    // Register session
    SESSION_REGISTRY.register(session_id.clone(), session);
    
    // Return JSON with session and hex keys
    let resp = serde_json::json!({
        "session_id": session_id,
        "alice_identity_hex": identity.public_key_hex(),
        "alice_ephemeral_public_key_hex": x3dh_result.ephemeral_public_key_hex,
    });
    resp.to_string()
}

/// Create a session as responder (Bob)
/// 
/// Responds to X3DH handshake and creates DoubleRatchet session.
/// 
/// # Arguments
/// * `identity_bytes_json` - JSON string of Bob's IdentityKeyPairBytes
/// * `signed_prekey_id` - ID of the signed prekey Bob used
/// * `one_time_prekey_id` - ID of the one-time prekey Bob used (optional)
/// * `alice_identity_hex` - Alice's identity public key (hex)
/// * `alice_ephemeral_public_key_hex` - Alice's ephemeral public key from X3DH (hex)
/// 
/// # Returns
/// Session ID (UUID string) if successful, or error message
#[frb(sync)]
pub fn create_session_responder(
    identity_bytes_json: String,
    signed_prekey_id: u32,
    one_time_prekey_id: Option<u32>,
    alice_identity_hex: String,
    alice_ephemeral_public_key_hex: String,
) -> String {
    // Parse identity from JSON
    let identity_bytes = match serde_json::from_str::<IdentityKeyPairBytes>(&identity_bytes_json) {
        Ok(bytes) => bytes,
        Err(e) => return format!("Error: Failed to parse identity: {}", e),
    };
    
    let identity = match identity_bytes.to_identity_key_pair() {
        Ok(id) => id,
        Err(e) => return format!("Error: Failed to create identity: {}", e),
    };
    
    // Load the exact prekeys Bob generated earlier
    let signed_prekey = match SIGNED_PREKEY_STORE.lock().ok().and_then(|m| m.get(&signed_prekey_id).cloned()) {
        Some(sp) => sp,
        None => return format!("Error: Missing signed prekey id {} in store", signed_prekey_id),
    };
    
    let mut responder = X3DHResponder::new(identity.clone(), signed_prekey.clone());
    
    // Set one-time prekey if provided
    if let Some(otp_id) = one_time_prekey_id {
        use x25519_dalek::{EphemeralSecret, PublicKey};
        let otp_private_bytes = match ONE_TIME_PREKEY_STORE.lock().ok().and_then(|m| m.get(&otp_id).cloned()) {
            Some(bytes) => bytes,
            None => return format!("Error: Missing one-time prekey id {} in store", otp_id),
        };
        let otp_private_reconstructed = unsafe {
            std::mem::transmute::<[u8; 32], EphemeralSecret>(otp_private_bytes)
        };
        let otp_public = PublicKey::from(&otp_private_reconstructed);
        responder.set_one_time_prekey(otp_id, otp_private_reconstructed, otp_public);
    }
    
    // Respond to X3DH handshake
    let x3dh_result = match responder.respond(&alice_identity_hex, &alice_ephemeral_public_key_hex) {
        Ok(r) => r,
        Err(e) => return format!("Error: X3DH handshake failed: {}", e),
    };
    
    // Create session with shared secret
    let session_id = generate_session_id();
    let session = match Session::from_shared_secret(
        x3dh_result.shared_secret,
        false, // is_initiator
        session_id.clone(),
    ) {
        Ok(s) => Arc::new(s),
        Err(e) => return format!("Error: Failed to create session: {}", e),
    };
    
    // Register session
    SESSION_REGISTRY.register(session_id.clone(), session);
    
    session_id
}

/// Encrypt a message using a session
/// 
/// # Arguments
/// * `session_id` - Session ID
/// * `plaintext` - Plaintext message bytes
/// 
/// # Returns
/// Base64-encoded MessageEnvelope if successful, or error message
#[frb(sync)]
pub fn encrypt_message(session_id: String, plaintext: Vec<u8>) -> String {
    let session = match SESSION_REGISTRY.get(&session_id) {
        Some(s) => s,
        None => return format!("Error: Session not found: {}", session_id),
    };
    
    let envelope = match session.encrypt(&plaintext) {
        Ok(e) => e,
        Err(e) => return format!("Error: Encryption failed: {}", e),
    };
    
    match envelope.to_base64() {
        Ok(b64) => b64,
        Err(e) => format!("Error: Failed to serialize envelope: {}", e),
    }
}

/// Decrypt a message using a session
/// 
/// # Arguments
/// * `session_id` - Session ID
/// * `envelope_base64` - Base64-encoded MessageEnvelope
/// 
/// # Returns
/// Decrypted plaintext bytes if successful, or error message
#[frb(sync)]
pub fn decrypt_message(session_id: String, envelope_base64: String) -> Vec<u8> {
    let session = match SESSION_REGISTRY.get(&session_id) {
        Some(s) => s,
        None => return b"Error: Session not found".to_vec(),
    };
    
    let envelope = match MessageEnvelope::from_base64(&envelope_base64) {
        Ok(e) => e,
        Err(e) => return format!("Error: Failed to parse envelope: {}", e).into_bytes(),
    };
    
    match session.decrypt(&envelope) {
        Ok(plaintext) => plaintext,
        Err(e) => format!("Error: Decryption failed: {}", e).into_bytes(),
    }
}

/// Close a session
/// 
/// # Arguments
/// * `session_id` - Session ID
#[frb(sync)]
pub fn close_session(session_id: String) {
    SESSION_REGISTRY.remove(&session_id);
}

