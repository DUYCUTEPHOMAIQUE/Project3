# Cách chạy 2 instances của Flutter app trên Mac để test chat

Có 2 cách chính để chạy 2 instances cùng lúc trên Mac:

## Cách 1: macOS App + iOS Simulator (Khuyến nghị)

### Bước 1: Mở iOS Simulator
```bash
open -a Simulator
```

### Bước 2: Chạy app trên macOS
```bash
cd demo-app
flutter run -d macos
```

### Bước 3: Chạy app trên iOS Simulator (terminal mới)
```bash
cd demo-app
flutter run -d "iPhone 15 Pro"  # hoặc device name khác
```

**Lưu ý**: iOS Simulator sẽ dùng `10.0.2.2` để connect tới localhost (đã được handle trong code)

## Cách 2: Build 2 macOS apps với Bundle ID khác nhau

### Bước 1: Build app đầu tiên (bundle ID mặc định)
```bash
cd demo-app
flutter build macos
```

### Bước 2: Tạo copy của app với bundle ID khác
```bash
# Copy app đã build
cp -r build/macos/Build/Products/Debug/demo_app.app build/macos/Build/Products/Debug/demo_app_2.app

# Sửa Bundle ID trong Info.plist để isolate data
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.e2ee.demoApp2" \
  build/macos/Build/Products/Debug/demo_app_2.app/Contents/Info.plist
```

**Lưu ý quan trọng**: Phải sửa Bundle ID để mỗi instance có data riêng biệt. Nếu không, cả 2 instances sẽ dùng chung SharedPreferences và dữ liệu sẽ bị trộn lẫn khi reload.

### Bước 3: Chạy cả 2 apps
```bash
# Terminal 1
open build/macos/Build/Products/Debug/demo_app.app

# Terminal 2  
open build/macos/Build/Products/Debug/demo_app_2.app
```

## Cách 3: Dùng script tự động (Dễ nhất - Khuyến nghị)

### Chạy script:
```bash
cd demo-app
./run_two_instances.sh
```

Script sẽ:
1. Build app
2. Copy app thành 2 instances
3. **Tự động sửa Bundle ID cho instance thứ 2** (để isolate data)
4. Mở cả 2 apps cùng lúc

**Lưu ý**: Script tự động thay đổi Bundle ID của instance thứ 2 thành `com.e2ee.demoApp2` để mỗi instance có SharedPreferences riêng biệt.

### Hoặc chạy thủ công:
```bash
# Terminal 1
cd demo-app
flutter run -d macos

# Terminal 2 (sau khi instance 1 đã chạy)
cd demo-app
flutter run -d macos
```

**Lưu ý**: 
- Flutter có thể không cho phép chạy 2 instances cùng lúc với cùng device. Nếu gặp lỗi, dùng script ở trên.
- **Quan trọng**: Nếu chạy thủ công như trên, cả 2 instances sẽ dùng chung Bundle ID và sẽ share SharedPreferences. Để isolate data, phải dùng script hoặc build riêng với Bundle ID khác nhau.

## Cách 4: Dùng Xcode để chạy 2 instances

1. Mở project trong Xcode:
```bash
cd demo-app/macos
open Runner.xcworkspace
```

2. Trong Xcode:
   - Product → Scheme → Edit Scheme
   - Duplicate scheme với tên khác
   - Chạy cả 2 schemes cùng lúc

## Khuyến nghị

**Cách tốt nhất**: Dùng **Cách 1** (macOS + iOS Simulator) vì:
- ✅ Dễ setup nhất
- ✅ Không cần modify code
- ✅ Test được trên 2 platforms khác nhau
- ✅ iOS Simulator tự động map `127.0.0.1` → `10.0.2.2`

## Test Flow

1. **Instance 1** (macOS): Login với user `thuy`
2. **Instance 2** (iOS Simulator): Login với user `thuy1`
3. **Instance 1**: Send friend request tới `thuy1`
4. **Instance 2**: Accept friend request
5. **Instance 1**: Click vào friend → Chat
6. **Instance 2**: Click vào friend → Chat
7. ✅ Cả 2 có thể chat với nhau realtime!
