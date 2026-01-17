# Authentication Integration Guide

## Tổng quan

Tài liệu này mô tả cách tích hợp Nakama client vào demo-app và luồng đăng nhập/đăng ký để liên kết với cả Key Service và Nakama.

## Kiến trúc đề xuất

### Authentication Flow

```
User → Demo App → AuthService → [Key Service + Nakama]
```

**AuthService** là service chính orchestrate cả hai:
- **Key Service**: Quản lý user credentials và cấp JWT token
- **Nakama**: Cung cấp realtime features, multiplayer, social features

### Luồng hoạt động

1. **Register/Login** với Key Service → Nhận JWT token
2. **Authenticate** với Nakama bằng JWT token (Custom Auth)
3. **Lưu** cả hai tokens vào SessionManager
4. **Sử dụng** tokens cho các API calls sau này

## Files đã được tạo

### Services
- `lib/services/auth_service.dart` - Unified authentication service
- `lib/services/key_service_client.dart` - Key Service API client
- `lib/services/nakama_service.dart` - Nakama client wrapper
- `lib/services/session_manager.dart` - Session và token management

### Models
- `lib/models/auth/auth_result.dart` - Auth result model
- `lib/models/auth/user.dart` - User model

### Documentation
- `docs/NAKAMA_INTEGRATION.md` - Chi tiết kiến trúc và implementation
- `docs/AUTH_FLOW_SUMMARY.md` - Tóm tắt luồng authentication
- `docs/IMPLEMENTATION_STEPS.md` - Step-by-step implementation guide

### Examples
- `lib/views/login_page_example.dart` - Example cách sử dụng AuthService

## Cách sử dụng

### 1. Initialize AuthService

```dart
final authService = AuthService();
await authService.initialize();
```

### 2. Register User

```dart
final result = await authService.register(
  username: 'alice',
  password: 'SecurePass123',
  email: 'alice@example.com', // optional
);

if (result.success) {
  // Registration successful
  // Tokens đã được tự động lưu
  print('User ID: ${result.userId}');
  print('Username: ${result.username}');
} else {
  // Handle error
  print('Error: ${result.error}');
}
```

### 3. Login User

```dart
final result = await authService.login(
  username: 'alice',
  password: 'SecurePass123',
);

if (result.success) {
  // Login successful
  // Navigate to main app
} else {
  // Handle error
  print('Error: ${result.error}');
}
```

### 4. Check Authentication Status

```dart
final isAuthenticated = await authService.isAuthenticated();
if (isAuthenticated) {
  // User is authenticated
}
```

### 5. Logout

```dart
await authService.logout();
// All sessions cleared
```

## Implementation Checklist

### Phase 1: Setup (Hiện tại)
- [x] Tạo AuthService architecture
- [x] Tạo KeyServiceClient
- [x] Tạo NakamaService template
- [x] Tạo SessionManager
- [x] Tạo models (AuthResult, User)
- [x] Tạo documentation

### Phase 2: Nakama Integration
- [ ] Install Nakama Flutter package
- [ ] Implement NakamaService đầy đủ
- [ ] Implement Nakama hook trên server
- [ ] Test Nakama authentication

### Phase 3: UI Integration
- [ ] Update LoginPage để dùng AuthService
- [ ] Update RegisterPage để dùng AuthService
- [ ] Update AuthWrapper để check cả Key Service và Nakama
- [ ] Handle error cases trong UI

### Phase 4: Security & Polish
- [ ] Migrate to flutter_secure_storage
- [ ] Implement token refresh logic
- [ ] Add retry logic cho network errors
- [ ] Add logging và monitoring

## Server-side Requirements

### Nakama Hook

Cần implement Nakama hook để verify custom token:

**File**: `nakama-server/data/modules/before_authenticate_custom.lua`

```lua
local function before_authenticate_custom(context, payload)
  local token = payload.token or payload.id
  
  -- Verify token với Key Service
  -- Extract user_id và username
  
  return {
    user_id = user_id,
    username = username,
  }
end
```

### Key Service Endpoint

Cần thêm endpoint để verify token (cho Nakama hook):

**Endpoint**: `GET /api/v1/auth/verify`
**Headers**: `Authorization: Bearer <token>`
**Response**: `{user_id, username, ...}`

## Configuration

### Key Service
- Port: **8099** (đã được config trong KeyServiceClient)
- Base URL: `http://127.0.0.1:8099/api/v1` (local)
- Base URL: `http://10.0.2.2:8099/api/v1` (Android emulator)

### Nakama
- Port: **7350** (default)
- Host: `127.0.0.1` (local)
- Host: `10.0.2.2` (Android emulator)
- Server Key: `defaultkey` (default, change trong production)

## Testing

### Test Register Flow
1. Register user mới
2. Verify Key Service token được lưu
3. Verify Nakama session được tạo
4. Verify có thể sử dụng Nakama features

### Test Login Flow
1. Login với user đã có
2. Verify tokens được restore
3. Verify Nakama session được restore
4. Verify có thể sử dụng Nakama features

### Test Error Cases
1. Key Service unavailable
2. Nakama unavailable
3. Invalid credentials
4. Network errors
5. Token expiry

## Troubleshooting

### Nakama authentication fails
- Check Nakama hook đã được implement chưa
- Check Key Service verify endpoint có hoạt động không
- Check network connectivity giữa Nakama và Key Service

### Tokens không được lưu
- Check SessionManager permissions
- Check SharedPreferences hoạt động không
- Consider migrate to flutter_secure_storage

### UI không update sau login
- Check AuthWrapper có listen auth state changes không
- Check navigation logic
- Check error handling

## Next Steps

1. **Immediate**: Install Nakama package và implement NakamaService
2. **Short-term**: Implement Nakama hook trên server
3. **Short-term**: Update UI components
4. **Medium-term**: Add token refresh và error handling
5. **Long-term**: Migrate to secure storage và add monitoring

## Resources

- [Nakama Documentation](https://heroiclabs.com/docs/nakama/)
- [Nakama Flutter Client](https://pub.dev/packages/nakama)
- [Key Service API Documentation](../key-service/api.md)
- [Implementation Plan](../../IMPLEMENTATION_PLAN.md)
