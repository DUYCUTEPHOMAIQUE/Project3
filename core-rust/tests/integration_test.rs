#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_key_generation() {
        let key_pair = IdentityKeyPair::generate();
        
        // Verify public key is valid
        let public_bytes = key_pair.public_key_bytes();
        assert_eq!(public_bytes.len(), 32);
        
        // Verify hex encoding works
        let hex = key_pair.public_key_hex();
        assert_eq!(hex.len(), 64); // 32 bytes * 2 hex chars
        
        // Verify uniqueness
        let key_pair2 = IdentityKeyPair::generate();
        assert_ne!(
            key_pair.public_key_bytes(),
            key_pair2.public_key_bytes()
        );
    }
}

