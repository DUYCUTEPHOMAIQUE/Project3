//! Test để kiểm tra chain synchronization giữa Alice và Bob

use e2ee_core::keys::{IdentityKeyPair, PreKeyBundle};
use e2ee_core::keys::prekey::{OneTimePreKey, OneTimePreKeyPair, SignedPreKey, SignedPreKeyPair};
use e2ee_core::ratchet::DoubleRatchet;
use e2ee_core::x3dh::{X3DHInitiator, X3DHResponder};
use x25519_dalek::{EphemeralSecret, PublicKey};

#[test]
fn test_chain_key_synchronization() {
    println!("\n=== Test: Chain Key Synchronization ===\n");

    // Setup
    let alice_identity = IdentityKeyPair::generate();
    let bob_identity = IdentityKeyPair::generate();
    
    let bob_signed_prekey = SignedPreKeyPair::generate(1, &bob_identity)
        .expect("Failed to generate signed prekey");
    let bob_one_time_prekey = OneTimePreKeyPair::generate(1);
    
    let prekey_bundle = PreKeyBundle::new(
        bob_identity.public_key_hex(),
        bob_identity.verifying_key(),
        SignedPreKey::from(&bob_signed_prekey),
        Some(OneTimePreKey::from(&bob_one_time_prekey)),
    );
    
    let alice = X3DHInitiator::new(alice_identity.clone());
    let alice_result = alice.initiate(&prekey_bundle)
        .expect("Failed to initiate X3DH");
    
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
    ).expect("Failed to respond to X3DH");
    
    // Verify shared secrets match
    assert_eq!(
        alice_result.shared_secret,
        bob_result.shared_secret,
        "Shared secrets must match"
    );
    println!("✓ Shared secrets match");

    // Create Double Ratchet instances
    let mut alice_dr = DoubleRatchet::from_shared_secret(&alice_result.shared_secret, true)
        .expect("Failed to create Alice's Double Ratchet");
    let mut bob_dr = DoubleRatchet::from_shared_secret(&bob_result.shared_secret, false)
        .expect("Failed to create Bob's Double Ratchet");

    // Test: Encrypt and decrypt first message
    println!("\nTesting first message encryption/decryption...");
    let plaintext = b"Test message";
    let envelope = alice_dr.encrypt_envelope(plaintext)
        .expect("Failed to encrypt");
    
    println!("  Alice encrypted message, message_number: {}", envelope.header.message_number);
    
    // Bob decrypts
    let decrypted = bob_dr.decrypt_envelope(&envelope)
        .expect("Failed to decrypt");
    
    assert_eq!(decrypted, plaintext.to_vec(), "Decrypted message must match original");
    println!("  ✓ First message decrypted successfully");
    
    // Test: Multiple messages
    println!("\nTesting multiple messages...");
    for i in 1..=5 {
        let msg = format!("Message {}", i).into_bytes();
        let env = alice_dr.encrypt_envelope(&msg)
            .expect("Failed to encrypt");
        
        let dec = bob_dr.decrypt_envelope(&env)
            .expect("Failed to decrypt");
        
        assert_eq!(dec, msg, "Message {} must decrypt correctly", i);
    }
    println!("  ✓ All 5 messages decrypted successfully");

    println!("\n=== Chain synchronization test passed! ===");
}

