# Updated Authentication Flow

## Thay đổi chính

Key Service giờ đây **tự động tạo Nakama user** khi user đăng ký hoặc đăng nhập. Client không cần gọi Nakama API trực tiếp nữa.

## Luồng mới (Simplified)

### Register Flow

```
User → Demo App
  ↓
Demo App → Key Service POST /api/v1/auth/register
  ↓ (username, password, email)
Key Service → Validate & Create User
  ↓
Key Service → Tự động gọi Nakama API để tạo user
  ↓ (Nakama user được tạo)
Key Service → Lưu Nakama user ID và session vào database
  ↓ (return: user_id, username, nakama_user_id, nakama_session)
Demo App → Save tokens từ response
  ↓
✅ User authenticated với cả Key Service & Nakama
```

### Login Flow

```
User → Demo App
  ↓
Demo App → Key Service POST /api/v1/auth/login
  ↓ (username, password)
Key Service → Validate credentials
  ↓
Key Service → Check nếu user có Nakama account
  ↓
  ├─ Nếu có: Refresh Nakama session
  └─ Nếu chưa: Tự động tạo Nakama user
  ↓ (return: access_token, nakama_user_id, nakama_session)
Demo App → Save tokens từ response
  ↓
✅ User authenticated với cả Key Service & Nakama
```

## Cập nhật trong Code

### AuthService Changes

**Trước:**
- Client gọi Key Service register/login
- Client tự gọi Nakama authenticateCustom
- Client quản lý cả hai tokens

**Sau:**
- Client chỉ gọi Key Service register/login
- Key Service tự động handle Nakama integration
- Client chỉ cần lưu tokens từ response

### KeyServiceClient

Không thay đổi - vẫn gọi Key Service API như cũ.

### AuthService.register()

```dart
// Đơn giản hơn - không cần gọi Nakama nữa
final result = await _keyServiceClient.register(...);

// Key Service đã tự động tạo Nakama user
final nakamaSession = result['nakama_session'];
final nakamaUserID = result['nakama_user_id'];

// Chỉ cần lưu tokens
await _sessionManager.saveNakamaSessionToken(nakamaSession);
```

### AuthService.login()

```dart
// Đơn giản hơn - không cần gọi Nakama nữa
final result = await _keyServiceClient.login(...);

// Key Service đã tự động authenticate với Nakama
final nakamaSession = result['nakama_session'];
final nakamaUserID = result['nakama_user_id'];

// Chỉ cần lưu tokens
await _sessionManager.saveKeyServiceToken(result['access_token']);
await _sessionManager.saveNakamaSessionToken(nakamaSession);
```

## Lợi ích

1. **Đơn giản hơn**: Client không cần quản lý Nakama integration
2. **Reliable hơn**: Key Service đảm bảo Nakama user luôn được tạo
3. **Consistent**: Tất cả Nakama users đều được tạo qua Key Service
4. **Easier to maintain**: Logic tập trung ở backend

## Response Format

### Register Response

```json
{
  "user_id": "uuid",
  "username": "alice",
  "email": "alice@example.com",
  "nakama_user_id": "nakama-uuid",
  "nakama_session": "nakama-session-token",
  "created_at": 1730340000
}
```

### Login Response

```json
{
  "access_token": "jwt-token",
  "refresh_token": "refresh-token",
  "token_type": "Bearer",
  "expires_in": 86400,
  "user": {
    "user_id": "uuid",
    "username": "alice",
    "email": "alice@example.com"
  },
  "nakama_user_id": "nakama-uuid",
  "nakama_session": "nakama-session-token"
}
```

## Migration Notes

Nếu bạn đã có code cũ sử dụng NakamaService trực tiếp:

1. Remove calls to `NakamaService.authenticateCustom()` trong AuthService
2. Update code để lấy Nakama info từ Key Service response
3. NakamaService vẫn có thể dùng cho các features khác (realtime, channels, etc.)

## Next Steps

1. Test register flow với Key Service
2. Test login flow với Key Service
3. Verify Nakama users được tạo đúng
4. Test Nakama features với session token từ Key Service
