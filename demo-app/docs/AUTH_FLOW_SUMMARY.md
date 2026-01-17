# Authentication Flow Summary

## Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────────┐
│                        Demo App (Flutter)                    │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ AuthService  │  │SessionManager│  │NakamaService │      │
│  │  (Orchestrator)│  │  (Storage)   │  │  (Client)    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │                │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────┐  ┌──────────────┐  ┌──────────────┐
│  Key Service    │  │  Local      │  │   Nakama     │
│  (Port 8099)    │  │  Storage    │  │  (Port 7350) │
│                 │  │             │  │              │
│  - Register     │  │  - JWT      │  │  - Custom    │
│  - Login        │  │  - Session │  │    Auth      │
│  - JWT Token    │  │  - User Info│  │  - Realtime  │
└─────────────────┘  └──────────────┘  └──────────────┘
```

## Luồng đăng ký chi tiết

```
1. User nhập thông tin → RegisterPage
   ↓
2. RegisterPage gọi AuthService.register()
   ↓
3. AuthService → KeyServiceClient.register()
   │  POST /api/v1/auth/register
   │  Body: {username, password, email}
   ↓
4. Key Service trả về:
   │  {user_id, username, access_token}
   ↓
5. AuthService lưu JWT token vào SessionManager
   ↓
6. AuthService → NakamaService.authenticateCustom(JWT)
   │  Custom auth với Nakama
   ↓
7. Nakama Hook verify JWT với Key Service
   │  (Server-side: before_authenticate_custom.lua)
   ↓
8. Nakama tạo/link user và trả về session
   │  {token, refresh_token, user_id, username}
   ↓
9. AuthService lưu Nakama session vào SessionManager
   ↓
10. ✅ User authenticated với cả Key Service & Nakama
```

## Luồng đăng nhập chi tiết

```
1. User nhập credentials → LoginPage
   ↓
2. LoginPage gọi AuthService.login()
   ↓
3. AuthService → KeyServiceClient.login()
   │  POST /api/v1/auth/login
   │  Body: {username, password}
   ↓
4. Key Service trả về:
   │  {access_token, user_id, username}
   ↓
5. AuthService lưu JWT token vào SessionManager
   ↓
6. AuthService → NakamaService.authenticateCustom(JWT)
   │  Custom auth với Nakama
   ↓
7. Nakama Hook verify JWT với Key Service
   ↓
8. Nakama trả về session (hoặc link với existing user)
   ↓
9. AuthService lưu Nakama session vào SessionManager
   ↓
10. ✅ User authenticated, navigate to main app
```

## Các thành phần chính

### AuthService
- **Trách nhiệm**: Orchestrate authentication flow
- **Methods**:
  - `register()` - Đăng ký user mới
  - `login()` - Đăng nhập user
  - `logout()` - Đăng xuất và clear sessions
  - `isAuthenticated()` - Check auth status

### KeyServiceClient
- **Trách nhiệm**: Gọi Key Service API
- **Methods**:
  - `register()` - Register với Key Service
  - `login()` - Login với Key Service
  - `refreshToken()` - Refresh JWT token
  - `verifyToken()` - Verify token (cho Nakama hook)

### NakamaService
- **Trách nhiệm**: Quản lý Nakama client connection
- **Methods**:
  - `authenticateCustom()` - Auth với custom token
  - `authenticateDevice()` - Device auth (optional)
  - `disconnect()` - Disconnect từ Nakama
  - `getCurrentSession()` - Get current session

### SessionManager
- **Trách nhiệm**: Quản lý storage cho tokens và sessions
- **Methods**:
  - `saveKeyServiceToken()` - Lưu JWT token
  - `saveNakamaSessionToken()` - Lưu Nakama session
  - `isAuthenticated()` - Check auth status
  - `clearSession()` - Clear all sessions

## Lợi ích của kiến trúc này

1. **Separation of Concerns**: Mỗi service có trách nhiệm rõ ràng
2. **Testability**: Dễ dàng mock và test từng component
3. **Maintainability**: Code dễ maintain và extend
4. **Flexibility**: Có thể thay đổi implementation mà không ảnh hưởng UI
5. **Reusability**: Services có thể reuse ở nhiều nơi

## Next Steps

1. Implement Nakama hook trên server
2. Complete NakamaService implementation
3. Update UI components
4. Add error handling và retry logic
5. Migrate to secure storage
6. Add token refresh mechanism
