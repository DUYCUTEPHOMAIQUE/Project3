use e2ee_core::ratchet::DoubleRatchet;
use e2ee_core::message::MessageEnvelope;
use std::env;
use std::io::{self, Read, Write};

fn hex_to_32(bytes_hex: &str) -> Result<[u8; 32], String> {
    let bytes = hex::decode(bytes_hex).map_err(|e| e.to_string())?;
    if bytes.len() != 32 {
        return Err(format!("SK must be 32 bytes (64 hex chars), got {}", bytes.len()));
    }
    let mut sk = [0u8; 32];
    sk.copy_from_slice(&bytes);
    Ok(sk)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage:\n  dr_cli encrypt <hex32_sk>\n  dr_cli decrypt <hex32_sk>");
        std::process::exit(1);
    }
    let cmd = &args[1];
    let sk_hex = &args[2];
    let sk = match hex_to_32(sk_hex) {
        Ok(v) => v,
        Err(e) => {
            eprintln!("Invalid SK: {}", e);
            std::process::exit(2);
        }
    };

    // Read stdin to buffer
    let mut buf = Vec::new();
    io::stdin().read_to_end(&mut buf).expect("read stdin");

    match cmd.as_str() {
        "encrypt" => {
            // stdin is plaintext
            let mut dr = DoubleRatchet::from_shared_secret(&sk).expect("dr init");
            let env = dr.encrypt_envelope(&buf).expect("encrypt");
            let b64 = env.to_base64().expect("b64");
            println!("{}", b64);
        }
        "decrypt" => {
            // stdin is base64(JSON envelope)
            let env = match MessageEnvelope::from_base64(std::str::from_utf8(&buf).unwrap().trim()) {
                Ok(v) => v,
                Err(e) => {
                    eprintln!("Invalid envelope: {}", e);
                    std::process::exit(3);
                }
            };
            let mut dr = DoubleRatchet::from_shared_secret(&sk).expect("dr init");
            let pt = dr.decrypt_envelope(&env).expect("decrypt");
            io::stdout().write_all(&pt).expect("write out");
        }
        _ => {
            eprintln!("Unknown command: {}", cmd);
            std::process::exit(1);
        }
    }
}
