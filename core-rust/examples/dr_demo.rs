use e2ee_core::ratchet::DoubleRatchet;
use e2ee_core::message::MessageEnvelope;

fn main() {
    // Mock shared secret from X3DH (32 bytes). Replace with real SK in integration.
    let sk = [42u8; 32];

    let mut alice = DoubleRatchet::from_shared_secret(&sk).expect("dr init");
    let mut bob = DoubleRatchet::from_shared_secret(&sk).expect("dr init");

    // Alice encrypts a message and wraps to envelope
    let env = alice.encrypt_envelope(b"Hello DR from example").expect("enc env");
    let env_b64 = env.to_base64().expect("b64");
    println!("Envelope (base64): {}", env_b64);

    // Bob receives and decodes
    let env2 = MessageEnvelope::from_base64(&env_b64).expect("decode");
    let plain = bob.decrypt_envelope(&env2).expect("dec env");
    println!("Decrypted: {}", String::from_utf8_lossy(&plain));
}
