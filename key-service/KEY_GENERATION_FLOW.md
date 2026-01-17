# Key Generation Flow Analysis

## Hiện trạng

### Khi Register User
- ✅ Tạo user account trong Key Service
- ✅ Tự động tạo Nakama user
- ❌ **KHÔNG tự động tạo keys/device**

### Flow hiện tại để có keys

1. **Register** → Tạo user account
2. **Login** → Lấy access token
3. **Client generate keys** (Rust core):
   - Generate identity key pair
   - Generate prekey bundle (signed prekey + one-time prekeys)
4. **Register device** → Gửi public keys lên server

## Tại sao không tự động tạo keys ở server?

### 1. Security Best Practice
- **Private keys KHÔNG BAO GIỜ** được gửi lên server
- Private keys chỉ tồn tại ở client (Flutter app)
- Server chỉ lưu **public keys**

### 2. Technical Constraints
- Keys được generate bằng **Rust core** (X25519, Ed25519)
- Key Service là **Go**, không có Rust FFI
- Không thể gọi Rust code từ Go service

### 3. Architecture Design
- Key generation logic nằm trong `core-rust/` (Rust crate)
- Key Service chỉ là **key distribution service**
- Client tự quản lý private keys

## Flow đúng theo thiết kế

```
User Register
  ↓
Key Service: Tạo user account + Nakama user
  ↓
User Login
  ↓
Client: Generate keys (Rust core)
  ├─ Identity key pair (private + public)
  ├─ Signed prekey (signed by identity key)
  └─ One-time prekeys (pool)
  ↓
Client: Register device với public keys
  ↓
Key Service: Lưu public keys
  ↓
✅ User có keys để chat
```

## Vấn đề hiện tại

Sau khi register/login, user **chưa có device/keys** để chat. User phải:
1. Login thành công
2. Tự động hoặc manually generate keys
3. Register device với keys

## Giải pháp đề xuất

### Option 1: Auto-register device sau login (Client-side)
- Sau khi login thành công, Flutter app tự động:
  1. Check xem đã có device chưa
  2. Nếu chưa có → Generate keys → Register device

### Option 2: Thêm endpoint check device
- `GET /api/v1/devices/check` → Check user đã có device chưa
- Client gọi endpoint này sau login để quyết định có cần register device không

### Option 3: Lazy device registration
- Khi user muốn chat với friend lần đầu:
  1. Check có device chưa
  2. Nếu chưa → Generate keys → Register device
  3. Sau đó mới fetch friend's prekey bundle

## Recommendation

**Option 1** là tốt nhất:
- User experience tốt (tự động setup)
- Không cần thêm API call
- Keys được tạo ở client (đúng security model)

### Implementation trong Flutter

```dart
// Sau khi login thành công
Future<void> ensureDeviceRegistered() async {
  // Check xem đã có device chưa (có thể check local storage)
  final hasDevice = await _checkDeviceExists();
  
  if (!hasDevice) {
    // Generate keys
    final identityJson = api.generateIdentityKeyPair();
    final bundleJson = api.generatePrekeyBundle(...);
    
    // Register device với Key Service
    await _registerDevice(identityJson, bundleJson);
  }
}
```

## Kết luận

- ✅ Flow hiện tại là **đúng** theo security best practices
- ✅ Keys **KHÔNG THỂ** tự động tạo ở server
- ✅ Cần implement **auto device registration** ở client sau login
- ✅ Đây là design đúng, không phải bug
