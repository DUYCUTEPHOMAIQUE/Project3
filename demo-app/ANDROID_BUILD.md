 # Hướng dẫn build Android (Flutter + Rust via flutter_rust_bridge)

 Tài liệu này gom các bước chuẩn để build phần Rust và chạy app Flutter trên Android cho dự án này.

 ## 1) Yêu cầu môi trường
 - Flutter SDK + Android SDK/Android Studio (đã cấu hình thiết bị/AVD)
 - NDK (Android Studio sẽ cài, hoặc theo hướng dẫn của cargo-ndk)
 - Rust toolchain (stable)
 - cargo-ndk (trợ giúp build `.so` cho Android):

 ```bash
 cargo install cargo-ndk
 ```

 - flutter_rust_bridge codegen (v2):

 ```bash
 cargo install flutter_rust_bridge_codegen --version ^2
 ```

 ## 2) Tạo mã bind (FRB codegen)
 Chạy từ thư mục gốc repo:

 ```bash
 flutter_rust_bridge_codegen generate \
   --rust-input crate::ffi::api \
   --rust-root core-rust \
   --dart-output demo-app/lib/bridge_generated \
   --dart-entrypoint-class-name E2EECore
 ```

 Sau khi chạy xong, thư mục `demo-app/lib/bridge_generated/` sẽ có các file Dart sinh ra (ví dụ: `frb_generated.dart`, `ffi/api.dart`, ...).

 ## 3) Build thư viện Rust cho các ABI Android
 Build `.so` cho các ABI phổ biến và copy sang `jniLibs/` của app:

 ```bash
 cargo ndk \
   -t arm64-v8a -t armeabi-v7a -t x86_64 \
   -P 21 \
   -o demo-app/android/app/src/main/jniLibs \
   --manifest-path core-rust/Cargo.toml -- build --release
 ```

 Sau lệnh này, bạn sẽ thấy:

 ```
  demo-app/android/app/src/main/jniLibs/
   ├─ arm64-v8a/libe2ee_core.so
   ├─ armeabi-v7a/libe2ee_core.so
   └─ x86_64/libe2ee_core.so
 ```

 Lưu ý: tên file `.so` phải khớp với tên crate Rust (`e2ee_core`).

 ## 4) Cập nhật/import trong Flutter
 Trong `demo-app/lib/main.dart` đảm bảo bạn import các file sinh ra và khởi tạo API. Trên Android, không cần chỉ định đường dẫn DLL thủ công (FRB loader sẽ tự tìm `libe2ee_core.so`). Ví dụ tối thiểu:

 ```dart
 import 'package:flutter/material.dart';
 import 'bridge_generated/frb_generated.dart';

 void main() async {
   WidgetsFlutterBinding.ensureInitialized();
   await E2EECore.init();
   runApp(const MyApp());
 }
 ```

 Nếu trước đó có đoạn riêng cho Windows như `ExternalLibrary.open(...)`, hãy giữ nguyên nhánh Windows, nhưng trên Android chỉ cần `await E2EECore.init();`.

 ## 5) Cài dependency và chạy app trên Android

 ```bash
 cd demo-app
 flutter pub get
 # Cắm thiết bị thật hoặc mở Android Emulator
 flutter run -d android
 ```

 Hoặc build APK/AAB:

 ```bash
 # APK
 flutter build apk --release

 # App Bundle (Play Store)
 flutter build appbundle --release
 ```

 ## 6) Ghi chú/Troubleshooting nhanh
 - minSdkVersion: Lệnh ở trên dùng API level 21 (`-P 21`). Đảm bảo `android/app/build.gradle` có `minSdkVersion >= 21`.
 - ABI mismatch: Nếu thiết bị không hỗ trợ ABI bạn build, hãy thêm ABI tương ứng trong lệnh `cargo ndk -t ...`.
 - Regenerate bindings: Mỗi khi thay đổi API Rust (file `core-rust/src/ffi/api.rs`), chạy lại bước 2 (codegen) trước khi build.
 - Clean: Khi gặp lỗi lạ, thử `flutter clean` trong `demo-app` và build lại.

 ---
 Tóm tắt nhanh: Codegen (bước 2) → Build `.so` với cargo-ndk (bước 3) → `flutter run -d android` (bước 5).

