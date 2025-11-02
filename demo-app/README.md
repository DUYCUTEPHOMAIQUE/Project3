# E2EE Demo App

Demo Flutter app demonstrating End-to-End Encryption functionality using the Rust core library.

## Features

- **Generate Keys**: Generate identity key pairs for Alice and Bob
- **Create Sessions**: Create encrypted sessions using X3DH handshake
- **Encrypt/Decrypt**: Encrypt messages from Alice and decrypt them as Bob

## Prerequisites

- Flutter SDK (>=3.4.0)
- Rust toolchain
- flutter_rust_bridge_codegen CLI tool

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Generate Rust bindings (if not already generated):
```bash
cd ../core-rust
flutter_rust_bridge_codegen generate \
  --rust-input crate::ffi::api \
  --dart-output ../demo-app/lib/bridge_generated \
  --rust-root . \
  --dart-entrypoint-class-name E2EECore
```

3. Build Rust core library:
```bash
cd ../core-rust
cargo build --release
```

## Running the App

### Desktop (macOS/Linux/Windows)
```bash
flutter run -d macos
flutter run -d linux
flutter run -d windows
```

### Mobile (iOS/Android)
```bash
flutter run -d ios
flutter run -d android
```

## Usage Flow

1. **Generate Keys**: Click "Generate Alice Keys" and "Generate Bob Keys" buttons
2. **Create Sessions**: Click "Create Alice Session" and "Create Bob Session" buttons
3. **Encrypt/Decrypt**: 
   - Enter a message in the text field
   - Click "Encrypt (Alice)" to encrypt the message
   - Click "Decrypt (Bob)" to decrypt the message

## Architecture

- **Flutter UI**: Material Design UI for user interaction
- **Dart API**: Generated bindings from Rust API (`bridge_generated/ffi/api.dart`)
- **Rust Core**: E2EE core library with X3DH and Double Ratchet implementation

## Note

This is a simplified demo. In a production app:
- Identity keys should be persisted securely (e.g., secure storage)
- Ephemeral public key from X3DH should be exchanged via server
- Session state should be persisted for app restarts
- Error handling should be more robust
