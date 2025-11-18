# Platform Requirements - Yêu Cầu Cho Từng Platform

Tài liệu này giải thích chi tiết những gì cần thiết để chạy Rust core library trên các platform khác nhau.

---

## 📱 **ANDROID**

### Yêu Cầu Môi Trường

#### 1. **Build Tools**
```bash
# Rust toolchain
rustup install stable

# Android NDK (Native Development Kit)
# Cài qua Android Studio hoặc standalone
# Cần NDK r21+ (API level 21+)

# cargo-ndk - Tool để build Rust cho Android
cargo install cargo-ndk

# flutter_rust_bridge codegen
cargo install flutter_rust_bridge_codegen --version ^2
```

#### 2. **Android SDK**
- Android SDK với API level 21+ (Android 5.0+)
- Android Studio hoặc command line tools
- Gradle build system

#### 3. **Flutter Setup**
- Flutter SDK
- Dart SDK
- Android device hoặc emulator

### Build Process

#### Bước 1: Generate Dart Bindings
```bash
flutter_rust_bridge_codegen generate \
  --rust-input crate::ffi::api \
  --rust-root core-rust \
  --dart-output demo-app/lib/bridge_generated \
  --dart-entrypoint-class-name E2EECore
```

**Kết quả**: Generate Dart code để gọi Rust functions

#### Bước 2: Build Rust Library cho Android ABIs
```bash
cargo ndk \
  -t arm64-v8a \      # 64-bit ARM (hầu hết devices hiện đại)
  -t armeabi-v7a \    # 32-bit ARM (devices cũ)
  -t x86_64 \         # 64-bit x86 (emulator)
  -P 21 \             # Minimum API level
  -o demo-app/android/app/src/main/jniLibs \
  --manifest-path core-rust/Cargo.toml \
  -- build --release
```

**Kết quả**: 
```
demo-app/android/app/src/main/jniLibs/
├─ arm64-v8a/libe2ee_core.so    (~500KB-1MB)
├─ armeabi-v7a/libe2ee_core.so
└─ x86_64/libe2ee_core.so
```

#### Bước 3: Configure Android App
**File**: `android/app/build.gradle.kts`
```kotlin
android {
    defaultConfig {
        minSdk = 21  // Phải >= 21
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }
}
```

#### Bước 4: Flutter Integration
**File**: `lib/main.dart`
```dart
import 'bridge_generated/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Android tự động load libe2ee_core.so từ jniLibs/
  await E2EECore.init();
  
  runApp(const MyApp());
}
```

### Đặc Điểm Android

#### ✅ **Ưu Điểm**
- **JNI (Java Native Interface)**: Android có built-in support cho native libraries
- **Multiple ABIs**: Hỗ trợ nhiều architectures cùng lúc
- **Dynamic Loading**: `.so` files được load tự động khi app start
- **Hardware Keystore**: Android Keystore API cho secure key storage

#### ⚠️ **Lưu Ý**
- **APK Size**: Mỗi `.so` file ~500KB-1MB, có thể làm tăng APK size
- **ABI Filtering**: Có thể chỉ build cho architectures cần thiết để giảm size
- **minSdkVersion**: Phải >= 21 (Android 5.0)
- **ProGuard**: Cần config ProGuard để không obfuscate native code

### Android Keystore Integration

```kotlin
// Sử dụng Android Keystore để store private keys
val keyStore = KeyStore.getInstance("AndroidKeyStore")
keyStore.load(null)

// Generate key trong hardware-backed keystore
val keyGenerator = KeyGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_AES, 
    "AndroidKeyStore"
)
```

---

## 🍎 **iOS**

### Yêu Cầu Môi Trường

#### 1. **Build Tools**
```bash
# Rust toolchain
rustup install stable

# Xcode Command Line Tools
xcode-select --install

# iOS targets cho Rust
rustup target add aarch64-apple-ios        # iPhone/iPad (ARM64)
rustup target add aarch64-apple-ios-sim    # Simulator (ARM64)
rustup target add x86_64-apple-ios          # Simulator (Intel)

# flutter_rust_bridge codegen
cargo install flutter_rust_bridge_codegen --version ^2
```

#### 2. **Xcode**
- Xcode 12+ (recommended: latest)
- iOS SDK
- CocoaPods (cho dependency management)

#### 3. **Flutter Setup**
- Flutter SDK
- Dart SDK
- iOS Simulator hoặc physical device
- Apple Developer account (cho physical device)

### Build Process

#### Bước 1: Generate Dart Bindings
```bash
flutter_rust_bridge_codegen generate \
  --rust-input crate::ffi::api \
  --rust-root core-rust \
  --dart-output demo-app/lib/bridge_generated \
  --dart-entrypoint-class-name E2EECore
```

#### Bước 2: Build Rust Library cho iOS

**Option A: Sử dụng CargoKit (Recommended - tự động)**

CargoKit tự động build khi Flutter build iOS app:
```bash
cd demo-app
flutter build ios
```

CargoKit sẽ:
1. Detect iOS architectures (arm64 cho device, x86_64/arm64 cho simulator)
2. Build Rust library cho mỗi architecture
3. Use `lipo` để combine thành universal binary
4. Link vào iOS app

**Option B: Manual Build**
```bash
# Build cho device (ARM64)
cargo build --release --target aarch64-apple-ios

# Build cho simulator (Intel)
cargo build --release --target x86_64-apple-ios

# Build cho simulator (ARM64 - M1/M2 Mac)
cargo build --release --target aarch64-apple-ios-sim

# Combine với lipo
lipo -create \
  target/aarch64-apple-ios/release/libe2ee_core.a \
  target/x86_64-apple-ios/release/libe2ee_core.a \
  -output libe2ee_core_universal.a
```

#### Bước 3: CocoaPods Integration

**File**: `ios/rust_lib_demo_app.podspec`
```ruby
s.script_phase = {
  :name => 'Build Rust library',
  :script => 'sh "$PODS_TARGET_SRCROOT/../cargokit/build_pod.sh" ../../../core-rust rust_lib_demo_app',
  :execution_position => :before_compile,
  :output_files => ["${BUILT_PRODUCTS_DIR}/librust_lib_demo_app.a"],
}
```

#### Bước 4: Flutter Integration
**File**: `lib/main.dart`
```dart
import 'bridge_generated/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // iOS tự động load từ framework
  await E2EECore.init();
  
  runApp(const MyApp());
}
```

### Đặc Điểm iOS

#### ✅ **Ưu Điểm**
- **Static Linking**: iOS sử dụng static libraries (`.a` files)
- **Universal Binaries**: Có thể combine nhiều architectures với `lipo`
- **Secure Enclave**: Hardware-backed key storage trên devices có Secure Enclave
- **Code Signing**: iOS enforce code signing cho security

#### ⚠️ **Lưu Ý**
- **Bitcode**: iOS không còn yêu cầu Bitcode (deprecated từ iOS 14)
- **App Store**: Cần Apple Developer account để publish
- **Architectures**: 
  - Device: `aarch64-apple-ios` (ARM64)
  - Simulator Intel: `x86_64-apple-ios`
  - Simulator ARM (M1/M2): `aarch64-apple-ios-sim`
- **Minimum iOS Version**: iOS 11+ (theo podspec)

### iOS Secure Enclave Integration

```swift
// Sử dụng Secure Enclave để store private keys
let access = SecAccessControlCreateWithFlags(
    kCFAllocatorDefault,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    .privateKeyUsage,
    nil
)

let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrAccessControl as String: access!
    ]
]
```

---

## 🔌 **IoT DEVICES**

### Yêu Cầu Môi Trường

#### 1. **Build Tools**
```bash
# Rust toolchain
rustup install stable

# Embedded Rust targets
rustup target add thumbv7em-none-eabihf    # ARM Cortex-M4/M7
rustup target add riscv32imac-unknown-none-elf  # RISC-V
rustup target add x86_64-unknown-linux-gnu     # Linux-based IoT

# Cargo tools
cargo install cargo-embed    # Cho embedded debugging
cargo install cargo-binutils # Binary utilities
```

#### 2. **Hardware Requirements**
- **ESP32**: 240MHz dual-core, 520KB RAM, 4MB Flash
- **Raspberry Pi**: ARM-based, Linux OS
- **Arduino**: AVR hoặc ARM-based
- **Other**: Bất kỳ device nào có Rust compiler support

### Build Process

#### Bước 1: Configure Cargo cho Embedded

**File**: `core-rust/Cargo.toml`
```toml
[target.'cfg(target_os = "none")']
# Embedded-specific config
[dependencies]
# Minimal dependencies cho embedded
# Loại bỏ: flutter_rust_bridge, serde_json (quá nặng)
# Giữ lại: ring (có no_std support), x25519-dalek, ed25519-dalek
```

#### Bước 2: Create Lightweight Variant

**File**: `core-rust/src/embedded/mod.rs`
```rust
// Minimal API cho embedded devices
// Chỉ essentials: key generation, X3DH, basic encryption
// Không có: session management, complex state

#![no_std]  // No standard library

pub fn generate_identity_key() -> [u8; 32] {
    // Minimal implementation
}
```

#### Bước 3: Build cho Target Platform

**ESP32 (RISC-V)**
```bash
cargo build --release --target riscv32imc-unknown-none-elf
# Output: target/riscv32imc-unknown-none-elf/release/libe2ee_core.a
```

**Raspberry Pi (ARM Linux)**
```bash
cargo build --release --target armv7-unknown-linux-gnueabihf
# Output: target/armv7-unknown-linux-gnueabihf/release/libe2ee_core.so
```

**Generic Embedded (ARM Cortex-M)**
```bash
cargo build --release --target thumbv7em-none-eabihf
# Output: target/thumbv7em-none-eabihf/release/libe2ee_core.a
```

#### Bước 4: MQTT Transport Adapter

**File**: `core-rust/src/transport/mqtt.rs`
```rust
// MQTT adapter cho IoT
// Lightweight protocol, low overhead
pub struct MQTTAdapter {
    client: mqtt::Client,
}

impl MQTTAdapter {
    pub fn publish_message(&self, topic: &str, payload: &[u8]) {
        // Publish encrypted message via MQTT
    }
    
    pub fn subscribe(&self, topic: &str) {
        // Subscribe để receive messages
    }
}
```

### Đặc Điểm IoT

#### ✅ **Ưu Điểm**
- **No Standard Library**: `#![no_std]` cho embedded devices
- **Small Binary Size**: Có thể optimize xuống <100KB
- **Low Memory**: Minimal heap usage
- **MQTT Support**: Standard protocol cho IoT

#### ⚠️ **Lưu Ý**
- **Resource Constraints**: 
  - RAM: 50KB-512KB
  - Flash: 256KB-4MB
  - CPU: 80MHz-240MHz
- **Limited Features**: 
  - Chỉ basic crypto operations
  - Không có full session management
  - Không có complex state machines
- **Dependencies**: Phải loại bỏ heavy dependencies
  - ❌ `serde_json` (quá nặng)
  - ❌ `flutter_rust_bridge` (không cần)
  - ✅ `ring` (có `no_std` support)
  - ✅ `x25519-dalek` (lightweight)

### IoT-Specific Optimizations

#### 1. **Feature Flags**
```toml
# Cargo.toml
[features]
default = ["full"]
full = ["session-management", "backup"]
embedded = []  # Minimal features
```

#### 2. **Conditional Compilation**
```rust
#[cfg(feature = "embedded")]
pub mod embedded_api;

#[cfg(not(feature = "embedded"))]
pub mod full_api;
```

#### 3. **Memory Optimization**
```rust
// Use stack allocation thay vì heap
// Avoid dynamic allocations
// Use fixed-size arrays
```

### Example: ESP32 Integration

```rust
// ESP32-specific code
#[cfg(target_arch = "riscv32")]
pub mod esp32 {
    use core::alloc::Layout;
    
    pub fn init() {
        // Initialize ESP32-specific hardware
    }
    
    pub fn get_random_bytes(buffer: &mut [u8]) {
        // Use ESP32 hardware RNG
    }
}
```

---

## 📊 **So Sánh Platform Requirements**

| Requirement | Android | iOS | IoT |
|------------|---------|-----|-----|
| **Build Tool** | cargo-ndk | CargoKit/Xcode | cargo (standard) |
| **Output Format** | `.so` (dynamic) | `.a` (static) | `.a` hoặc `.so` |
| **ABIs/Architectures** | arm64-v8a, armeabi-v7a, x86_64 | aarch64-apple-ios, x86_64-apple-ios | Tùy device |
| **Min SDK/OS** | API 21+ (Android 5.0) | iOS 11+ | N/A |
| **Binary Size** | ~500KB-1MB per ABI | ~500KB-1MB (universal) | <100KB (optimized) |
| **Memory Usage** | ~10-50MB | ~10-50MB | <512KB |
| **Keystore** | Android Keystore | Secure Enclave | Software (hoặc TPM) |
| **Transport** | HTTP/gRPC | HTTP/gRPC | MQTT |
| **Dependencies** | Full (serde_json, etc.) | Full | Minimal (no_std) |

---

## 🛠️ **Build Commands Summary**

### Android
```bash
# 1. Generate bindings
flutter_rust_bridge_codegen generate \
  --rust-input crate::ffi::api \
  --rust-root core-rust \
  --dart-output demo-app/lib/bridge_generated \
  --dart-entrypoint-class-name E2EECore

# 2. Build .so files
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -P 21 \
  -o demo-app/android/app/src/main/jniLibs \
  --manifest-path core-rust/Cargo.toml -- build --release

# 3. Run Flutter app
cd demo-app && flutter run -d android
```

### iOS
```bash
# 1. Generate bindings
flutter_rust_bridge_codegen generate \
  --rust-input crate::ffi::api \
  --rust-root core-rust \
  --dart-output demo-app/lib/bridge_generated \
  --dart-entrypoint-class-name E2EECore

# 2. Build iOS (CargoKit tự động)
cd demo-app && flutter build ios

# 3. Run Flutter app
flutter run -d ios
```

### IoT (ESP32 Example)
```bash
# 1. Add target
rustup target add riscv32imc-unknown-none-elf

# 2. Build embedded variant
cargo build --release --target riscv32imc-unknown-none-elf \
  --no-default-features --features embedded

# 3. Flash to device
cargo embed --target riscv32imc-unknown-none-elf
```

---

## 🎯 **Kết Luận**

### **Android**
- ✅ Cần: NDK, cargo-ndk, Android SDK
- ✅ Output: `.so` files cho multiple ABIs
- ✅ Integration: JNI, tự động load libraries

### **iOS**
- ✅ Cần: Xcode, CocoaPods, iOS SDK
- ✅ Output: `.a` static library (universal binary)
- ✅ Integration: CargoKit tự động build và link

### **IoT**
- ✅ Cần: Embedded Rust targets, minimal dependencies
- ✅ Output: `.a` hoặc `.so` (tùy platform)
- ✅ Integration: Custom transport adapter (MQTT)
- ⚠️ **Lưu ý**: Cần lightweight variant với `no_std`

---

**Tất cả platforms đều share cùng một Rust codebase**, chỉ khác nhau ở:
1. **Build targets** (architecture)
2. **Output format** (.so vs .a)
3. **Integration method** (JNI vs CargoKit vs custom)
4. **Feature set** (full vs embedded)

