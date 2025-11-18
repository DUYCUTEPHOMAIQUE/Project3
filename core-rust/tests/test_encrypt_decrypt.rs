//! Test file cho quy trình tạo khóa, gửi tin nhắn, và nhận tin nhắn
//!
//! Test này kiểm tra:
//! 1. Tạo identity keys cho Alice và Bob
//! 2. X3DH handshake để tạo shared secret
//! 3. Khởi tạo Double Ratchet cho cả hai bên
//! 4. Alice encrypt và gửi tin nhắn
//! 5. Bob decrypt tin nhắn từ Alice
//! 6. Bob encrypt và gửi tin nhắn
//! 7. Alice decrypt tin nhắn từ Bob

use e2ee_core::keys::{IdentityKeyPair, PreKeyBundle};
use e2ee_core::keys::prekey::{OneTimePreKey, OneTimePreKeyPair, SignedPreKey, SignedPreKeyPair};
use e2ee_core::message::MessageEnvelope;
use e2ee_core::ratchet::DoubleRatchet;
use e2ee_core::x3dh::{X3DHInitiator, X3DHResponder};
use x25519_dalek::{EphemeralSecret, PublicKey};

#[test]
fn test_full_encrypt_decrypt_flow() {
    println!("\n=== Test: Full Encrypt/Decrypt Flow ===\n");

    // ============================================================
    // Step 1: Generate Identity Keys
    // ============================================================
    println!("Step 1: Generating identity keys...");
    let alice_identity = IdentityKeyPair::generate();
    let bob_identity = IdentityKeyPair::generate();
    
    println!("  Alice identity public key: {}", alice_identity.public_key_hex());
    println!("  Bob identity public key:   {}", bob_identity.public_key_hex());
    
    assert_ne!(
        alice_identity.public_key_hex(),
        bob_identity.public_key_hex(),
        "Identity keys should be different"
    );

    // ============================================================
    // Step 2: Bob generates and publishes prekeys
    // ============================================================
    println!("\nStep 2: Bob generates prekeys...");
    let bob_signed_prekey = SignedPreKeyPair::generate(1, &bob_identity)
        .expect("Failed to generate signed prekey");
    let bob_one_time_prekey = OneTimePreKeyPair::generate(1);
    
    println!("  Signed prekey ID: {}", bob_signed_prekey.key_id());
    println!("  One-time prekey ID: {}", bob_one_time_prekey.key_id());

    // ============================================================
    // Step 3: Create PreKey Bundle
    // ============================================================
    println!("\nStep 3: Creating prekey bundle...");
    let prekey_bundle = PreKeyBundle::new(
        bob_identity.public_key_hex(),
        bob_identity.verifying_key(),
        SignedPreKey::from(&bob_signed_prekey),
        Some(OneTimePreKey::from(&bob_one_time_prekey)),
    );
    
    assert!(
        prekey_bundle.verify_signature().expect("Failed to verify signature"),
        "Prekey bundle signature should be valid"
    );
    println!("  ✓ Prekey bundle signature verified");

    // ============================================================
    // Step 4: X3DH Handshake - Alice initiates
    // ============================================================
    println!("\nStep 4: Alice initiates X3DH handshake...");
    let alice = X3DHInitiator::new(alice_identity.clone());
    let alice_result = alice.initiate(&prekey_bundle)
        .expect("Failed to initiate X3DH");
    
    println!("  Ephemeral public key: {}", alice_result.ephemeral_public_key_hex);
    println!("  Shared secret derived (32 bytes)");

    // ============================================================
    // Step 5: X3DH Handshake - Bob responds
    // ============================================================
    println!("\nStep 5: Bob responds to X3DH handshake...");
    
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
    ).expect("Failed to respond to X3DH");
    
    println!("  Bob derived shared secret (32 bytes)");
    
    // Verify both sides have the same shared secret
    assert_eq!(
        alice_result.shared_secret,
        bob_result.shared_secret,
        "Shared secrets should match"
    );
    println!("  ✓ Shared secrets match!");

    // ============================================================
    // Step 6: Initialize Double Ratchet with shared secret
    // ============================================================
    println!("\nStep 6: Initializing Double Ratchet...");
    // Alice is the initiator, Bob is the responder
    let mut alice_dr = DoubleRatchet::from_shared_secret(&alice_result.shared_secret, true)
        .expect("Failed to create Alice's Double Ratchet");
    let mut bob_dr = DoubleRatchet::from_shared_secret(&bob_result.shared_secret, false)
        .expect("Failed to create Bob's Double Ratchet");
    
    println!("  Alice Double Ratchet initialized (initiator)");
    println!("  Bob Double Ratchet initialized (responder)");

    // ============================================================
    // Step 7: Alice encrypts and sends message 1
    // ============================================================
    println!("\nStep 7: Alice encrypts message 1...");
    let plaintext1 = b"Hello Bob! This is Alice's first message.";
    let envelope1 = alice_dr.encrypt_envelope(plaintext1)
        .expect("Failed to encrypt message 1");
    
    println!("  Original message: {}", String::from_utf8_lossy(plaintext1));
    println!("  Ciphertext length: {} bytes", envelope1.ciphertext.len());
    println!("  Message number: {}", envelope1.header.message_number);
    println!("  DH public key: {}", envelope1.header.dh_public_key);
    
    assert_eq!(envelope1.header.message_number, 1, "First message should have message_number = 1");

    // ============================================================
    // Step 8: Bob decrypts message 1 from Alice
    // ============================================================
    println!("\nStep 8: Bob decrypts message 1 from Alice...");
    let decrypted1 = bob_dr.decrypt_envelope(&envelope1)
        .expect("Failed to decrypt message 1");
    let decrypted_text1 = String::from_utf8_lossy(&decrypted1);
    
    println!("  Decrypted message: {}", decrypted_text1);
    
    assert_eq!(
        decrypted1,
        plaintext1.to_vec(),
        "Decrypted message should match original"
    );
    println!("  ✓ Message 1 decrypted successfully!");

    // ============================================================
    // Step 9: Alice encrypts and sends message 2
    // ============================================================
    println!("\nStep 9: Alice encrypts message 2...");
    let plaintext2 = b"Hello Bob! This is Alice's second message.";
    let envelope2 = alice_dr.encrypt_envelope(plaintext2)
        .expect("Failed to encrypt message 2");
    
    println!("  Original message: {}", String::from_utf8_lossy(plaintext2));
    println!("  Message number: {}", envelope2.header.message_number);
    
    assert_eq!(envelope2.header.message_number, 2, "Second message should have message_number = 2");

    // ============================================================
    // Step 10: Bob decrypts message 2 from Alice
    // ============================================================
    println!("\nStep 10: Bob decrypts message 2 from Alice...");
    let decrypted2 = bob_dr.decrypt_envelope(&envelope2)
        .expect("Failed to decrypt message 2");
    let decrypted_text2 = String::from_utf8_lossy(&decrypted2);
    
    println!("  Decrypted message: {}", decrypted_text2);
    
    assert_eq!(
        decrypted2,
        plaintext2.to_vec(),
        "Decrypted message should match original"
    );
    println!("  ✓ Message 2 decrypted successfully!");

    // ============================================================
    // Step 11: Bob encrypts and sends reply
    // ============================================================
    println!("\nStep 11: Bob encrypts reply...");
    let bob_reply = b"Hi Alice! This is Bob's reply.";
    let bob_envelope = bob_dr.encrypt_envelope(bob_reply)
        .expect("Failed to encrypt Bob's reply");
    
    println!("  Original message: {}", String::from_utf8_lossy(bob_reply));
    println!("  Message number: {}", bob_envelope.header.message_number);
    
    assert_eq!(bob_envelope.header.message_number, 1, "Bob's first message should have message_number = 1");

    // ============================================================
    // Step 12: Alice decrypts Bob's reply
    // ============================================================
    println!("\nStep 12: Alice decrypts Bob's reply...");
    let alice_decrypted = alice_dr.decrypt_envelope(&bob_envelope)
        .expect("Failed to decrypt Bob's reply");
    let alice_decrypted_text = String::from_utf8_lossy(&alice_decrypted);
    
    println!("  Decrypted message: {}", alice_decrypted_text);
    
    assert_eq!(
        alice_decrypted,
        bob_reply.to_vec(),
        "Decrypted message should match original"
    );
    println!("  ✓ Bob's reply decrypted successfully!");

    // ============================================================
    // Step 13: Test multiple messages back and forth
    // ============================================================
    println!("\nStep 13: Testing multiple messages back and forth...");
    
    // Alice sends message 3
    let alice_msg3 = b"Message 3 from Alice";
    let alice_env3 = alice_dr.encrypt_envelope(alice_msg3)
        .expect("Failed to encrypt Alice's message 3");
    assert_eq!(alice_env3.header.message_number, 3);
    
    // Bob decrypts Alice's message 3
    let bob_dec3 = bob_dr.decrypt_envelope(&alice_env3)
        .expect("Failed to decrypt Alice's message 3");
    assert_eq!(bob_dec3, alice_msg3.to_vec());
    println!("  ✓ Alice message 3 decrypted");
    
    // Bob sends message 2
    let bob_msg2 = b"Message 2 from Bob";
    let bob_env2 = bob_dr.encrypt_envelope(bob_msg2)
        .expect("Failed to encrypt Bob's message 2");
    assert_eq!(bob_env2.header.message_number, 2);
    
    // Alice decrypts Bob's message 2
    let alice_dec2 = alice_dr.decrypt_envelope(&bob_env2)
        .expect("Failed to decrypt Bob's message 2");
    assert_eq!(alice_dec2, bob_msg2.to_vec());
    println!("  ✓ Bob message 2 decrypted");
    
    // Alice sends message 4
    let alice_msg4 = b"Message 4 from Alice";
    let alice_env4 = alice_dr.encrypt_envelope(alice_msg4)
        .expect("Failed to encrypt Alice's message 4");
    assert_eq!(alice_env4.header.message_number, 4);
    
    // Bob decrypts Alice's message 4
    let bob_dec4 = bob_dr.decrypt_envelope(&alice_env4)
        .expect("Failed to decrypt Alice's message 4");
    assert_eq!(bob_dec4, alice_msg4.to_vec());
    println!("  ✓ Alice message 4 decrypted");

    println!("\n=== All tests passed! ===");
}

#[test]
fn test_message_number_synchronization() {
    println!("\n=== Test: Message Number Synchronization ===\n");

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
    
    let mut alice_dr = DoubleRatchet::from_shared_secret(&alice_result.shared_secret, true)
        .expect("Failed to create Alice's Double Ratchet");
    let mut bob_dr = DoubleRatchet::from_shared_secret(&bob_result.shared_secret, false)
        .expect("Failed to create Bob's Double Ratchet");

    // Test: Verify message numbers increment correctly
    println!("Testing message number increment...");
    
    let msg1 = b"Message 1";
    let env1 = alice_dr.encrypt_envelope(msg1).expect("Failed to encrypt");
    assert_eq!(env1.header.message_number, 1, "First message should be number 1");
    println!("  ✓ Message 1 has number 1");
    
    let msg2 = b"Message 2";
    let env2 = alice_dr.encrypt_envelope(msg2).expect("Failed to encrypt");
    assert_eq!(env2.header.message_number, 2, "Second message should be number 2");
    println!("  ✓ Message 2 has number 2");
    
    let msg3 = b"Message 3";
    let env3 = alice_dr.encrypt_envelope(msg3).expect("Failed to encrypt");
    assert_eq!(env3.header.message_number, 3, "Third message should be number 3");
    println!("  ✓ Message 3 has number 3");

    // Test: Decrypt in order
    println!("\nDecrypting messages in order...");
    let dec1 = bob_dr.decrypt_envelope(&env1).expect("Failed to decrypt");
    assert_eq!(dec1, msg1.to_vec());
    println!("  ✓ Message 1 decrypted");
    
    let dec2 = bob_dr.decrypt_envelope(&env2).expect("Failed to decrypt");
    assert_eq!(dec2, msg2.to_vec());
    println!("  ✓ Message 2 decrypted");
    
    let dec3 = bob_dr.decrypt_envelope(&env3).expect("Failed to decrypt");
    assert_eq!(dec3, msg3.to_vec());
    println!("  ✓ Message 3 decrypted");

    println!("\n=== Message number synchronization test passed! ===");
}

#[test]
fn test_dh_ratchet_after_multiple_messages() {
    println!("\n=== Test: DH Ratchet After Multiple Messages ===\n");

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
    
    let mut alice_dr = DoubleRatchet::from_shared_secret(&alice_result.shared_secret, true)
        .expect("Failed to create Alice's Double Ratchet");
    let mut bob_dr = DoubleRatchet::from_shared_secret(&bob_result.shared_secret, false)
        .expect("Failed to create Bob's Double Ratchet");

    // Test: Send multiple messages, then trigger DH ratchet by Bob sending back
    println!("Alice sends 3 messages...");
    let alice_msg1 = b"Alice message 1";
    let alice_env1 = alice_dr.encrypt_envelope(alice_msg1).expect("Failed to encrypt");
    
    let alice_msg2 = b"Alice message 2";
    let alice_env2 = alice_dr.encrypt_envelope(alice_msg2).expect("Failed to encrypt");
    
    let alice_msg3 = b"Alice message 3";
    let alice_env3 = alice_dr.encrypt_envelope(alice_msg3).expect("Failed to encrypt");
    
    println!("Bob decrypts all 3 messages...");
    let bob_dec1 = bob_dr.decrypt_envelope(&alice_env1).expect("Failed to decrypt");
    assert_eq!(bob_dec1, alice_msg1.to_vec());
    
    let bob_dec2 = bob_dr.decrypt_envelope(&alice_env2).expect("Failed to decrypt");
    assert_eq!(bob_dec2, alice_msg2.to_vec());
    
    let bob_dec3 = bob_dr.decrypt_envelope(&alice_env3).expect("Failed to decrypt");
    assert_eq!(bob_dec3, alice_msg3.to_vec());
    println!("  ✓ All 3 messages decrypted successfully");
    
    // Bob sends reply (this will trigger DH ratchet on Alice's side)
    println!("\nBob sends reply (triggers DH ratchet)...");
    let bob_reply = b"Bob's reply";
    let bob_env = bob_dr.encrypt_envelope(bob_reply).expect("Failed to encrypt");
    
    // Alice decrypts Bob's reply (should trigger DH ratchet)
    println!("Alice decrypts Bob's reply...");
    let alice_dec = alice_dr.decrypt_envelope(&bob_env).expect("Failed to decrypt");
    assert_eq!(alice_dec, bob_reply.to_vec());
    println!("  ✓ Bob's reply decrypted successfully (DH ratchet occurred)");
    
    // Alice sends another message after DH ratchet
    println!("\nAlice sends message after DH ratchet...");
    let alice_msg4 = b"Alice message 4 (after ratchet)";
    let alice_env4 = alice_dr.encrypt_envelope(alice_msg4).expect("Failed to encrypt");
    
    // Bob decrypts (should use new receiving chain from DH ratchet)
    println!("Bob decrypts message after DH ratchet...");
    let bob_dec4 = bob_dr.decrypt_envelope(&alice_env4).expect("Failed to decrypt");
    assert_eq!(bob_dec4, alice_msg4.to_vec());
    println!("  ✓ Message after DH ratchet decrypted successfully");

    println!("\n=== DH ratchet test passed! ===");
}

#[test]
fn test_serialization_roundtrip() {
    println!("\n=== Test: Serialization Roundtrip ===\n");

    // Setup: Create keys and establish session
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
    
    let mut alice_dr = DoubleRatchet::from_shared_secret(&alice_result.shared_secret, true)
        .expect("Failed to create Alice's Double Ratchet");
    let mut bob_dr = DoubleRatchet::from_shared_secret(&bob_result.shared_secret, false)
        .expect("Failed to create Bob's Double Ratchet");

    // Test: Encrypt, serialize, deserialize, decrypt
    println!("Encrypting message...");
    let plaintext = b"Test message for serialization";
    let envelope = alice_dr.encrypt_envelope(plaintext)
        .expect("Failed to encrypt");
    
    println!("Serializing envelope...");
    let b64 = envelope.to_base64()
        .expect("Failed to serialize");
    println!("  Base64 length: {} chars", b64.len());
    
    println!("Deserializing envelope...");
    let deserialized = MessageEnvelope::from_base64(&b64)
        .expect("Failed to deserialize");
    
    assert_eq!(envelope.version, deserialized.version);
    assert_eq!(envelope.message_type, deserialized.message_type);
    assert_eq!(envelope.header.message_number, deserialized.header.message_number);
    assert_eq!(envelope.header.dh_public_key, deserialized.header.dh_public_key);
    assert_eq!(envelope.ciphertext, deserialized.ciphertext);
    
    println!("Decrypting deserialized envelope...");
    let decrypted = bob_dr.decrypt_envelope(&deserialized)
        .expect("Failed to decrypt");
    
    assert_eq!(decrypted, plaintext.to_vec());
    println!("  ✓ Serialization roundtrip successful!");
}

