//! Basic usage example for E2EE Core library
//!
//! This example demonstrates:
//! 1. Key generation (Identity keys, Prekeys)
//! 2. X3DH handshake (Alice initiates, Bob responds)
//! 3. Double Ratchet encryption/decryption
//! 4. Message envelope serialization

use e2ee_core::keys::{IdentityKeyPair, PreKeyBundle};
use e2ee_core::keys::prekey::{OneTimePreKey, OneTimePreKeyPair, SignedPreKey, SignedPreKeyPair};
use e2ee_core::message::MessageEnvelope;
use e2ee_core::ratchet::DoubleRatchet;
use e2ee_core::x3dh::{X3DHInitiator, X3DHResult, X3DHResponder, X3DHResponseResult};
use x25519_dalek::{EphemeralSecret, PublicKey};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("=== E2EE Core Library Usage Example ===\n");

    // ============================================================
    // Step 1: Generate Identity Keys
    // ============================================================
    println!("Step 1: Generating identity keys...");
    let alice_identity = IdentityKeyPair::generate();
    let bob_identity = IdentityKeyPair::generate();
    
    println!("  Alice identity public key: {}", alice_identity.public_key_hex());
    println!("  Bob identity public key:   {}", bob_identity.public_key_hex());
    println!();

    // ============================================================
    // Step 2: Bob generates and publishes prekeys
    // ============================================================
    println!("Step 2: Bob generates prekeys...");
    let bob_signed_prekey = SignedPreKeyPair::generate(1, &bob_identity)?;
    let bob_one_time_prekey = OneTimePreKeyPair::generate(1);
    
    println!("  Signed prekey ID: {}", bob_signed_prekey.key_id());
    println!("  One-time prekey ID: {}", bob_one_time_prekey.key_id());
    println!();

    // ============================================================
    // Step 3: Create PreKey Bundle (what Alice will fetch)
    // ============================================================
    println!("Step 3: Creating prekey bundle...");
    let prekey_bundle = PreKeyBundle::new(
        bob_identity.public_key_hex(),
        SignedPreKey::from(&bob_signed_prekey),
        Some(OneTimePreKey::from(&bob_one_time_prekey)),
    );
    println!("  Prekey bundle created successfully");
    println!();

    // ============================================================
    // Step 4: X3DH Handshake - Alice initiates
    // ============================================================
    println!("Step 4: Alice initiates X3DH handshake...");
    let alice = X3DHInitiator::new(alice_identity.clone());
    let alice_result = alice.initiate(&prekey_bundle)?;
    
    println!("  Ephemeral public key: {}", alice_result.ephemeral_public_key_hex);
    println!("  Shared secret derived (32 bytes)");
    println!();

    // ============================================================
    // Step 5: X3DH Handshake - Bob responds
    // ============================================================
    println!("Step 5: Bob responds to X3DH handshake...");
    
    // Bob needs to provide the one-time prekey private key
    let bob_one_time_private_ref = bob_one_time_prekey.private_key();
    let bob_one_time_private_bytes = unsafe {
        std::mem::transmute_copy::<EphemeralSecret, [u8; 32]>(bob_one_time_private_ref)
    };
    let bob_one_time_private = unsafe {
        std::mem::transmute::<[u8; 32], EphemeralSecret>(bob_one_time_private_bytes)
    };
    let bob_one_time_public = PublicKey::from(&bob_one_time_private);
    
    let mut bob = X3DHResponder::new(bob_identity.clone(), bob_signed_prekey.clone());
    bob.set_one_time_prekey(1, bob_one_time_private, bob_one_time_public);
    
    let bob_result = bob.respond(
        &alice_identity.public_key_hex(),
        &alice_result.ephemeral_public_key_hex,
    )?;
    
    println!("  Bob derived shared secret (32 bytes)");
    
    // Verify both sides have the same shared secret
    if alice_result.shared_secret == bob_result.shared_secret {
        println!("  ✓ Shared secrets match!");
    } else {
        println!("  ✗ Shared secrets don't match!");
        return Err("Shared secrets don't match".into());
    }
    println!();

    // ============================================================
    // Step 6: Initialize Double Ratchet with shared secret
    // ============================================================
    println!("Step 6: Initializing Double Ratchet...");
    // Alice is the initiator, Bob is the responder
    let mut alice_dr = DoubleRatchet::from_shared_secret(&alice_result.shared_secret, true)?;
    let mut bob_dr = DoubleRatchet::from_shared_secret(&bob_result.shared_secret, false)?;
    
    println!("  Alice Double Ratchet initialized (initiator)");
    println!("  Bob Double Ratchet initialized (responder)");
    println!();

    // ============================================================
    // Step 7: Alice encrypts and sends a message
    // ============================================================
    println!("Step 7: Alice encrypts a message...");
    let plaintext = b"Hello, this is a secret message!";
    let envelope = alice_dr.encrypt_envelope(plaintext)?;
    
    println!("  Original message: {}", String::from_utf8_lossy(plaintext));
    println!("  Ciphertext length: {} bytes", envelope.ciphertext.len());
    println!("  Message number: {}", envelope.header.message_number);
    println!();

    // ============================================================
    // Step 8: Serialize and deserialize message envelope
    // ============================================================
    println!("Step 8: Serializing message envelope...");
    let b64 = envelope.to_base64()?;
    println!("  Base64 length: {} chars", b64.len());
    
    let deserialized = MessageEnvelope::from_base64(&b64)?;
    println!("  ✓ Deserialized successfully");
    println!();

    // ============================================================
    // Step 9: Bob decrypts the message
    // ============================================================
    println!("Step 9: Bob decrypts the message...");
    let decrypted = bob_dr.decrypt_envelope(&deserialized)?;
    let decrypted_text = String::from_utf8_lossy(&decrypted);
    
    println!("  Decrypted message: {}", decrypted_text);
    
    if decrypted == plaintext.to_vec() {
        println!("  ✓ Decryption successful! Messages match!");
    } else {
        println!("  ✗ Decryption failed! Messages don't match!");
        return Err("Decryption failed".into());
    }
    println!();

    // ============================================================
    // Step 10: Bidirectional communication
    // ============================================================
    println!("Step 10: Testing bidirectional communication...");
    
    // Bob sends a reply
    let bob_reply = b"Hi Alice! This is Bob's reply.";
    let bob_envelope = bob_dr.encrypt_envelope(bob_reply)?;
    println!("  Bob encrypted reply");
    
    // Alice decrypts Bob's reply
    let alice_decrypted = alice_dr.decrypt_envelope(&bob_envelope)?;
    let alice_decrypted_text = String::from_utf8_lossy(&alice_decrypted);
    println!("  Alice decrypted: {}", alice_decrypted_text);
    
    if alice_decrypted == bob_reply.to_vec() {
        println!("  ✓ Bidirectional communication works!");
    } else {
        println!("  ✗ Bidirectional communication failed!");
        return Err("Bidirectional communication failed".into());
    }
    println!();

    println!("=== All tests passed! ===");
    Ok(())
}

